import '../forge_orm.dart';
import 'dialect/sql_dialect.dart';

class SchemaCreator {
  final Database database;
  final MetadataSchemaResolver schemaResolver;

  SqlDialect get dialect => database.dialect;

  SchemaCreator(this.database, this.schemaResolver);

  Future<void> createTables(List<Type> entities) async {
    for (final entityType in entities) {
      final schema = schemaResolver.resolveByType(entityType);
      final sql = _generateCreateTableSql(schema);

      try {
        await database.connection.execute(sql);
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
            await database.connection.execute(sql);
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
        await database.connection.execute(
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
    final result = await database.connection.execute(
      dialect.getTableExistsQuery(tableName),
      [tableName],
    );
    return result.hasResults;
  }

  Future<void> createTableIfNotExists(Type entityType) async {
    final schema = schemaResolver.resolveByType(entityType);

    if (!await tableExists(schema.tableName)) {
      final sql = _generateCreateTableSql(schema);
      await database.connection.execute(sql);
    }
  }
}
