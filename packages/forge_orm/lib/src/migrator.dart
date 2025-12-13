import 'package:forge_core/forge_core.dart';
import 'package:forge_orm/forge_orm.dart';

import 'dialect/sql_dialect.dart';

const _logger = Logger('Migrator');

class Migrator {
  final Database database;
  final MetadataSchemaResolver schemaResolver;

  SqlDialect get dialect => database.dialect;

  Migrator(this.database, this.schemaResolver);

  Future<void> createTables(List<Type> entities) async {
    for (final entityType in entities) {
      final schema = schemaResolver.resolveByType(entityType);
      final sql = _generateCreateTableSql(schema);

      try {
        await database.execute(sql);
      } catch (e) {
        throw Exception(
          'Error creating table ${schema.tableName}: $e',
        );
      }
    }
  }

  String _generateCreateTableSql(ResolvedEntitySchema schema) {
    final columns = <String>[];
    final primaryKeys = <String>[];

    for (final columnInfo in schema.columns.values) {
      final parts = <String>[];
      final column = columnInfo.columnAnnotation;

      parts.add(dialect.quoteIdentifier(columnInfo.columnName));

      parts.add(
        dialect.getColumnType(
          column.type,
          length: column.length,
          precision: column.precision,
          scale: column.scale,
          unsigned: column.unsigned,
        ),
      );

      if (!column.nullable) {
        parts.add('NOT NULL');
      }

      // For auto-increment columns, add PRIMARY KEY inline (required by SQLite)
      if (column.autoIncrement && column.primaryKey) {
        parts.add('PRIMARY KEY');
        parts.add(dialect.getAutoIncrementKeyword());
      }

      if (column.defaultValue != null) {
        parts.add(
          'DEFAULT ${dialect.formatDefaultValue(column.defaultValue, column.type)}',
        );
      }

      if (column.unique && !column.primaryKey) {
        parts.add('UNIQUE');
      }

      if (column.comment != null && column.comment!.isNotEmpty) {
        final commentStr = dialect.formatComment(column.comment!);
        if (commentStr.isNotEmpty) {
          parts.add(commentStr);
        }
      }

      columns.add(parts.join(' '));

      // Track primary keys that aren't auto-increment
      if (column.primaryKey && !column.autoIncrement) {
        primaryKeys.add(dialect.quoteIdentifier(columnInfo.columnName));
      }
    }

    // Only add PRIMARY KEY constraint if we have non-auto-increment primary keys
    if (primaryKeys.isNotEmpty) {
      columns.add('PRIMARY KEY (${primaryKeys.join(', ')})');
    }

    return '''
CREATE TABLE IF NOT EXISTS ${dialect.quoteIdentifier(schema.tableName)} (
  ${columns.join(',\n  ')}
)''';
  }

  Future<void> createIndexes(ResolvedEntitySchema schema) async {
    for (final columnInfo in schema.columns.values) {
      final column = columnInfo.columnAnnotation;

      if (column.unique && !column.primaryKey) {
        final indexName = 'idx_${schema.tableName}_${columnInfo.columnName}';
        final sql = dialect.getCreateIndexSyntax(
          schema.tableName,
          columnInfo.columnName,
          indexName,
          unique: true,
        );

        if (sql != null) {
          try {
            await database.execute(sql);
          } catch (e) {
            throw Exception(
              'Error creating index $indexName on table ${schema.tableName}: $e',
            );
          }
        }
      }
    }
  }

  Future<void> createForeignKeys(ResolvedEntitySchema schema) async {
    if (!dialect.supportsForeignKeyConstraints()) {
      return;
    }
  }

  Future<void> createTablesComplete(List<Type> entities) async {
    await createTables(entities);

    for (final entityType in entities) {
      final schema = schemaResolver.resolveByType(entityType);
      await createIndexes(schema);
    }
  }

  Future<void> dropTables(List<Type> entities) async {
    for (final entityType in entities.reversed) {
      final schema = schemaResolver.resolveByType(entityType);

      try {
        await database.execute(
          'DROP TABLE IF EXISTS ${dialect.quoteIdentifier(schema.tableName)}',
        );
      } catch (e) {
        throw Exception(
          'Error dropping table ${schema.tableName}: $e',
        );
      }
    }
  }

  Future<bool> tableExists(String tableName) async {
    final result = await database.execute(
      dialect.getTableExistsQuery(tableName),
      [tableName],
    );
    return result.hasResults;
  }

  Future<void> createTableIfNotExists(Type entityType) async {
    final schema = schemaResolver.resolveByType(entityType);

    if (!await tableExists(schema.tableName)) {
      final sql = _generateCreateTableSql(schema);
      await database.execute(sql);
    }
  }

  /// Converts a database value to String, handling bytes
  String? _valueToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List<int>) {
      // Convert bytes to UTF-8 string
      return String.fromCharCodes(value);
    }
    return value.toString();
  }

  /// Gets the current schema of a table from the database
  Future<Map<String, DatabaseColumnSchema>> _getDatabaseSchema(
    String tableName,
  ) async {
    final columns = <String, DatabaseColumnSchema>{};

    if (dialect.name == 'sqlite') {
      final result = await database.execute(
        'PRAGMA table_info(${dialect.quoteIdentifier(tableName)})',
      );

      for (final row in result.rows) {
        final name = _valueToString(row['name']) ?? '';
        final type = _valueToString(row['type']) ?? '';
        final notNull =
            (row['notnull'] is int ? row['notnull'] as int : 0) == 1;
        final defaultValue = _valueToString(row['dflt_value']);
        final pk = (row['pk'] is int ? row['pk'] as int : 0) == 1;

        columns[name] = DatabaseColumnSchema(
          name: name,
          type: type.toUpperCase(),
          nullable: !notNull,
          defaultValue: defaultValue,
          primaryKey: pk,
          autoIncrement: pk && type.toUpperCase() == 'INTEGER',
        );
      }
    } else if (dialect.name == 'mysql') {
      final result = await database.execute(
        'SHOW COLUMNS FROM ${dialect.quoteIdentifier(tableName)}',
      );

      for (final row in result.rows) {
        final name = _valueToString(row['Field']) ?? '';
        final type = _valueToString(row['Type']) ?? '';
        final nullValue = _valueToString(row['Null']);
        final nullable = nullValue?.toUpperCase() == 'YES';
        final key = _valueToString(row['Key']) ?? '';
        final extra = _valueToString(row['Extra']) ?? '';
        final defaultValue = _valueToString(row['Default']);

        columns[name] = DatabaseColumnSchema(
          name: name,
          type: type.toUpperCase(),
          nullable: nullable,
          defaultValue: defaultValue,
          primaryKey: key == 'PRI',
          autoIncrement: extra.toUpperCase().contains('AUTO_INCREMENT'),
          unique: key == 'UNI',
        );
      }
    }

    return columns;
  }

  /// Compares the database schema with the model schema
  Future<SchemaDiff> _compareSchemas(
    ResolvedEntitySchema schema,
    Map<String, DatabaseColumnSchema> databaseColumns,
  ) async {
    final columnsToAdd = <ColumnInfo>[];
    final columnsToModify = <ColumnModification>[];

    for (final columnInfo in schema.columns.values) {
      final columnName = columnInfo.columnName;
      final databaseColumn = databaseColumns[columnName];

      if (databaseColumn == null) {
        // Column doesn't exist in database, needs to be added
        columnsToAdd.add(columnInfo);
      } else {
        // Column exists, check for differences
        final differences = _findColumnDifferences(columnInfo, databaseColumn);
        if (differences.isNotEmpty) {
          columnsToModify.add(
            ColumnModification(
              modelColumn: columnInfo,
              databaseColumn: databaseColumn,
              differences: differences,
            ),
          );
        }
      }
    }

    return SchemaDiff(
      columnsToAdd: columnsToAdd,
      columnsToModify: columnsToModify,
    );
  }

  /// Finds differences between a model column and database column
  List<String> _findColumnDifferences(
    ColumnInfo modelColumn,
    DatabaseColumnSchema databaseColumn,
  ) {
    final differences = <String>[];
    final column = modelColumn.columnAnnotation;

    // Compare type
    final expectedType = _normalizeType(
      dialect.getColumnType(
        column.type,
        length: column.length,
        precision: column.precision,
        scale: column.scale,
        unsigned: column.unsigned,
      ),
    );
    final actualType = _normalizeType(databaseColumn.type);

    if (expectedType != actualType) {
      differences.add('type');
    }

    // Compare nullable
    if (column.nullable != databaseColumn.nullable) {
      differences.add('nullable');
    }

    // Compare default value (more robust comparison)
    if (!_defaultValuesMatch(
      column.defaultValue,
      column.type,
      databaseColumn.defaultValue,
    )) {
      differences.add('default');
    }

    return differences;
  }

  /// Checks if two default values are equivalent
  bool _defaultValuesMatch(
    dynamic modelDefault,
    ColumnType columnType,
    dynamic databaseDefault,
  ) {
    // Both null = match
    if (modelDefault == null && databaseDefault == null) {
      return true;
    }

    // One is null and other isn't = no match
    if (modelDefault == null || databaseDefault == null) {
      return false;
    }

    // Format expected value
    final expectedDefault = dialect.formatDefaultValue(
      modelDefault,
      columnType,
    );
    var actualDefault = databaseDefault.toString().trim();

    actualDefault = actualDefault.replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');
    var expected = expectedDefault.replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');

    if (columnType == ColumnType.boolean) {
      final boolMap = {'1': true, '0': false, 'true': true, 'false': false};
      final expectedBool = boolMap[expected.toLowerCase()];
      final actualBool = boolMap[actualDefault.toLowerCase()];
      if (expectedBool != null && actualBool != null) {
        return expectedBool == actualBool;
      }
    }

    if (columnType == ColumnType.integer ||
        columnType == ColumnType.smallInteger ||
        columnType == ColumnType.mediumInteger ||
        columnType == ColumnType.bigInteger ||
        columnType == ColumnType.tinyInteger) {
      final expectedInt = int.tryParse(expected);
      final actualInt = int.tryParse(actualDefault);
      if (expectedInt != null && actualInt != null) {
        return expectedInt == actualInt;
      }
    }

    if (columnType == ColumnType.float ||
        columnType == ColumnType.double ||
        columnType == ColumnType.decimal) {
      final expectedDouble = double.tryParse(expected);
      final actualDouble = double.tryParse(actualDefault);
      if (expectedDouble != null && actualDouble != null) {
        return expectedDouble == actualDouble;
      }
    }

    return expected == actualDefault;
  }

  /// Normalizes a column type for comparison
  String _normalizeType(String type) {
    // Remove spaces and convert to uppercase
    var normalized = type.trim().toUpperCase();

    // Remove unsigned and other keywords for base comparison
    normalized = normalized.replaceAll(RegExp(r'\s+UNSIGNED'), '');

    // Remove extra spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // For SQLite, normalize types to base types
    if (dialect.name == 'sqlite') {
      if (normalized.contains('INT')) return 'INTEGER';
      if (normalized.contains('CHAR') ||
          normalized.contains('CLOB') ||
          normalized.contains('TEXT')) {
        return 'TEXT';
      }
      if (normalized.contains('BLOB')) return 'BLOB';
      if (normalized.contains('REAL') ||
          normalized.contains('FLOA') ||
          normalized.contains('DOUB')) {
        return 'REAL';
      }
    }

    // For MySQL, normalize parentheses and spaces
    if (dialect.name == 'mysql') {
      // Remove spaces before parentheses
      normalized = normalized.replaceAll(RegExp(r'\s*\(\s*'), '(');
      normalized = normalized.replaceAll(RegExp(r'\s*,\s*'), ',');
      normalized = normalized.replaceAll(RegExp(r'\s*\)'), ')');
    }

    return normalized;
  }

  /// Generates ALTER TABLE statements to add columns
  List<String> _generateAddColumnStatements(
    String tableName,
    List<ColumnInfo> columnsToAdd,
  ) {
    final statements = <String>[];

    for (final columnInfo in columnsToAdd) {
      final column = columnInfo.columnAnnotation;
      final parts = <String>[];

      parts.add('ALTER TABLE ${dialect.quoteIdentifier(tableName)}');
      parts.add('ADD COLUMN ${dialect.quoteIdentifier(columnInfo.columnName)}');

      parts.add(
        dialect.getColumnType(
          column.type,
          length: column.length,
          precision: column.precision,
          scale: column.scale,
          unsigned: column.unsigned,
        ),
      );

      if (!column.nullable) {
        parts.add('NOT NULL');
      }

      if (column.defaultValue != null) {
        parts.add(
          'DEFAULT ${dialect.formatDefaultValue(column.defaultValue, column.type)}',
        );
      }

      if (column.unique && !column.primaryKey) {
        parts.add('UNIQUE');
      }

      if (column.comment != null && column.comment!.isNotEmpty) {
        final commentStr = dialect.formatComment(column.comment!);
        if (commentStr.isNotEmpty) {
          parts.add(commentStr);
        }
      }

      statements.add(parts.join(' '));
    }

    return statements;
  }

  /// Generates ALTER TABLE statements to modify columns
  List<String> _generateModifyColumnStatements(
    String tableName,
    List<ColumnModification> columnsToModify,
  ) {
    final statements = <String>[];

    for (final modification in columnsToModify) {
      final columnInfo = modification.modelColumn;
      final column = columnInfo.columnAnnotation;

      if (dialect.name == 'mysql') {
        final parts = <String>[];

        parts.add('ALTER TABLE ${dialect.quoteIdentifier(tableName)}');
        parts.add(
          'MODIFY COLUMN ${dialect.quoteIdentifier(columnInfo.columnName)}',
        );

        parts.add(
          dialect.getColumnType(
            column.type,
            length: column.length,
            precision: column.precision,
            scale: column.scale,
            unsigned: column.unsigned,
          ),
        );

        if (!column.nullable) {
          parts.add('NOT NULL');
        }

        if (column.defaultValue != null) {
          parts.add(
            'DEFAULT ${dialect.formatDefaultValue(column.defaultValue, column.type)}',
          );
        }

        if (column.comment != null && column.comment!.isNotEmpty) {
          final commentStr = dialect.formatComment(column.comment!);
          if (commentStr.isNotEmpty) {
            parts.add(commentStr);
          }
        }

        statements.add(parts.join(' '));
      } else if (dialect.name == 'sqlite') {
        // SQLite does not support ALTER COLUMN directly
        // Would need to create new table, copy data, drop old, rename
        // For now, log a detailed warning
        _logger.warning(
          'SQLite does not support ALTER COLUMN. Manual migration required or table recreation needed.',
          extra: {
            'table': tableName,
            'column': columnInfo.columnName,
            'changes': modification.differences.join(', '),
          },
        );
      }
    }

    return statements;
  }

  /// Executes database migration to update table structure according to models.
  /// Adds new columns and modifies existing columns.
  /// Columns that exist in the database but not in the model are ignored (not removed).
  Future<void> migrateTable(Type entityType, {bool verbose = true}) async {
    final schema = schemaResolver.resolveByType(entityType);

    if (verbose) {
      _logger.debug('Checking table: ${schema.tableName}');
    }

    // Check if table exists
    if (!await tableExists(schema.tableName)) {
      // If it doesn't exist, create the table
      if (verbose) {
        _logger.debug('Table ${schema.tableName} does not exist. Creating...');
      }
      await createTableIfNotExists(entityType);
      await createIndexes(schema);
      if (verbose) {
        _logger.debug('Table ${schema.tableName} created successfully');
      }
      return;
    }

    // Get current database schema
    final databaseColumns = await _getDatabaseSchema(schema.tableName);

    // Compare schemas
    final diff = await _compareSchemas(schema, databaseColumns);

    if (!diff.hasChanges) {
      if (verbose) {
        _logger.info('Table ${schema.tableName} is up to date.');
      }
      return;
    }

    // Generate and execute statements to add columns
    if (diff.columnsToAdd.isNotEmpty) {
      if (verbose) {
        _logger.debug(
          'Adding ${diff.columnsToAdd.length} column(s) to ${schema.tableName}',
          extra: {
            'columns': diff.columnsToAdd
                .map(
                  (col) => '${col.columnName} (${col.columnAnnotation.type})',
                )
                .toList(),
          },
        );
      }

      final addStatements = _generateAddColumnStatements(
        schema.tableName,
        diff.columnsToAdd,
      );

      for (var i = 0; i < addStatements.length; i++) {
        final statement = addStatements[i];
        try {
          await database.execute(statement);
        } catch (e) {
          throw Exception(
            'Error adding column ${diff.columnsToAdd[i].columnName} to table ${schema.tableName}: $e\nSQL: $statement',
          );
        }
      }
    }

    // Generate and execute statements to modify columns
    if (diff.columnsToModify.isNotEmpty) {
      if (verbose) {
        _logger.debug(
          'Modifying ${diff.columnsToModify.length} column(s) in ${schema.tableName}',
          extra: {
            'modifications': diff.columnsToModify
                .map(
                  (mod) =>
                      '${mod.modelColumn.columnName}: ${mod.differences.join(", ")}',
                )
                .toList(),
          },
        );
      }

      final modifyStatements = _generateModifyColumnStatements(
        schema.tableName,
        diff.columnsToModify,
      );

      for (var i = 0; i < modifyStatements.length; i++) {
        final statement = modifyStatements[i];
        if (statement.isEmpty) continue; // Skip empty statements (SQLite)

        try {
          await database.execute(statement);
        } catch (e) {
          throw Exception(
            'Error modifying column ${diff.columnsToModify[i].modelColumn.columnName} in table ${schema.tableName}: $e\nSQL: $statement',
          );
        }
      }
    }

    // Create missing indexes
    await createIndexes(schema);

    if (verbose) {
      _logger.success('Migration completed for table ${schema.tableName}');
    }
  }

  /// Executes migration for all tables
  Future<void> migrateAllTables(
    List<Type> entities, {
    bool verbose = true,
  }) async {
    if (verbose) {
      _logger.debug('Starting database migration...');
    }

    for (final entityType in entities) {
      await migrateTable(entityType, verbose: verbose);
    }

    _logger.success('All migrations completed successfully!');
  }
}

/// Class representing the structure of a column in the database
class DatabaseColumnSchema {
  final String name;
  final String type;
  final bool nullable;
  final dynamic defaultValue;
  final bool primaryKey;
  final bool autoIncrement;
  final bool unique;

  DatabaseColumnSchema({
    required this.name,
    required this.type,
    required this.nullable,
    this.defaultValue,
    this.primaryKey = false,
    this.autoIncrement = false,
    this.unique = false,
  });
}

/// Class representing the differences between database schema and model
class SchemaDiff {
  final List<ColumnInfo> columnsToAdd;
  final List<ColumnModification> columnsToModify;
  // We don't include columnsToRemove as we'll ignore columns that don't exist in model

  SchemaDiff({
    required this.columnsToAdd,
    required this.columnsToModify,
  });

  bool get hasChanges => columnsToAdd.isNotEmpty || columnsToModify.isNotEmpty;
}

/// Class representing a column modification
class ColumnModification {
  final ColumnInfo modelColumn;
  final DatabaseColumnSchema databaseColumn;
  final List<String> differences;

  ColumnModification({
    required this.modelColumn,
    required this.databaseColumn,
    required this.differences,
  });
}
