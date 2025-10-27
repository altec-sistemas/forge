import 'sql_dialect.dart';
import '../annotations.dart';

class MySqlDialect implements SqlDialect {
  @override
  String get name => 'mysql';

  @override
  String quoteIdentifier(String identifier) {
    return '`$identifier`';
  }

  @override
  String getColumnType(
    ColumnType type, {
    int? length,
    int? precision,
    int? scale,
    bool unsigned = false,
  }) {
    final typeStr = switch (type) {
      ColumnType.integer => 'INT',
      ColumnType.mediumInteger => 'MEDIUMINT',
      ColumnType.smallInteger => 'SMALLINT',
      ColumnType.tinyInteger => 'TINYINT',
      ColumnType.bigInteger => 'BIGINT',
      ColumnType.varchar => 'VARCHAR(${length ?? 255})',
      ColumnType.char => 'CHAR(${length ?? 1})',
      ColumnType.text => 'TEXT',
      ColumnType.longText => 'LONGTEXT',
      ColumnType.mediumText => 'MEDIUMTEXT',
      ColumnType.boolean => 'TINYINT(1)',
      ColumnType.dateTime => 'DATETIME',
      ColumnType.date => 'DATE',
      ColumnType.time => 'TIME',
      ColumnType.decimal =>
        precision != null && scale != null
            ? 'DECIMAL($precision, $scale)'
            : 'DECIMAL(10, 2)',
      ColumnType.float => 'FLOAT',
      ColumnType.double => 'DOUBLE',
      ColumnType.binary => 'BLOB',
      ColumnType.json => 'JSON',
    };

    return unsigned && _supportsUnsignedForType(type)
        ? '$typeStr UNSIGNED'
        : typeStr;
  }

  bool _supportsUnsignedForType(ColumnType type) {
    return [
      ColumnType.integer,
      ColumnType.mediumInteger,
      ColumnType.smallInteger,
      ColumnType.tinyInteger,
      ColumnType.bigInteger,
    ].contains(type);
  }

  @override
  String getAutoIncrementKeyword() => 'AUTO_INCREMENT';

  @override
  String getInsertIgnoreSyntax(String tableName) {
    return 'INSERT IGNORE INTO $tableName';
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
  bool supportsUnsigned() => true;

  @override
  String getLimitOffsetClause(int? limit, int? offset) {
    final parts = <String>[];

    if (limit != null) {
      parts.add('LIMIT $limit');
    }

    if (offset != null) {
      parts.add('OFFSET $offset');
    }

    return parts.join(' ');
  }

  @override
  String getTableExistsQuery(String tableName) {
    return "SELECT TABLE_NAME FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?";
  }

  @override
  String wrapBindingPlaceholder(int index) => '?';

  @override
  String getTransactionBegin() => 'START TRANSACTION';

  @override
  String getTransactionCommit() => 'COMMIT';

  @override
  String getTransactionRollback() => 'ROLLBACK';

  @override
  bool supportsForeignKeyConstraints() => true;

  @override
  String? getCreateIndexSyntax(
    String tableName,
    String columnName,
    String indexName, {
    bool unique = false,
  }) {
    final uniqueKeyword = unique ? 'UNIQUE' : '';
    return 'CREATE $uniqueKeyword INDEX $indexName ON $tableName ($columnName)';
  }
}
