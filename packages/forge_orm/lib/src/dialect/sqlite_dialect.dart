import 'sql_dialect.dart';
import '../annotations.dart';

class SqliteDialect implements SqlDialect {
  @override
  String get name => 'sqlite';

  @override
  String quoteIdentifier(String identifier) {
    return '"$identifier"';
  }

  @override
  String getColumnType(
    ColumnType type, {
    int? length,
    int? precision,
    int? scale,
    bool unsigned = false,
  }) {
    return switch (type) {
      ColumnType.integer => 'INTEGER',
      ColumnType.mediumInteger => 'INTEGER',
      ColumnType.smallInteger => 'INTEGER',
      ColumnType.tinyInteger => 'INTEGER',
      ColumnType.bigInteger => 'INTEGER',
      ColumnType.varchar => 'TEXT',
      ColumnType.char => 'TEXT',
      ColumnType.text => 'TEXT',
      ColumnType.longText => 'TEXT',
      ColumnType.mediumText => 'TEXT',
      ColumnType.boolean => 'INTEGER',
      ColumnType.dateTime => 'TEXT',
      ColumnType.date => 'TEXT',
      ColumnType.time => 'TEXT',
      ColumnType.decimal => 'REAL',
      ColumnType.float => 'REAL',
      ColumnType.double => 'REAL',
      ColumnType.binary => 'BLOB',
      ColumnType.json => 'TEXT',
    };
  }

  @override
  String getAutoIncrementKeyword() => 'AUTOINCREMENT';

  @override
  String getInsertIgnoreSyntax(String tableName) {
    return 'INSERT OR IGNORE INTO $tableName';
  }

  @override
  String formatDefaultValue(dynamic value, ColumnType type) {
    if (value == null) return 'NULL';

    if (value is String) {
      if (value.toUpperCase().contains('CURRENT_') ||
          value.toUpperCase() == 'NOW()' ||
          value.toUpperCase() == 'NULL') {
        return value;
      }
      return "'$value'";
    }

    if (value is bool) {
      return value ? '1' : '0';
    }

    if (value is DateTime) {
      return "'${value.toIso8601String()}'";
    }

    return value.toString();
  }

  @override
  bool supportsUnsigned() => false;

  @override
  String getLimitOffsetClause(int? limit, int? offset) {
    final parts = <String>[];

    if (limit != null) {
      parts.add('LIMIT $limit');
    }

    if (offset != null) {
      if (limit == null) {
        parts.add('LIMIT -1');
      }

      parts.add('OFFSET $offset');
    }

    return parts.join(' ');
  }

  @override
  String getTableExistsQuery(String tableName) {
    return "SELECT name FROM sqlite_master WHERE type='table' AND name=?";
  }

  @override
  String wrapBindingPlaceholder(int index) => '?';

  @override
  String getTransactionBegin() => 'BEGIN TRANSACTION';

  @override
  String getTransactionCommit() => 'COMMIT';

  @override
  String getTransactionRollback() => 'ROLLBACK';

  @override
  bool supportsForeignKeyConstraints() => false;

  @override
  String? getCreateIndexSyntax(
    String tableName,
    String columnName,
    String indexName, {
    bool unique = false,
  }) {
    final uniqueKeyword = unique ? 'UNIQUE' : '';
    return 'CREATE $uniqueKeyword INDEX IF NOT EXISTS $indexName ON $tableName ($columnName)';
  }
}
