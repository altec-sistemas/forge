import '../annotations.dart';

abstract class SqlDialect {
  String get name;

  String quoteIdentifier(String identifier);

  String getColumnType(
    ColumnType type, {
    int? length,
    int? precision,
    int? scale,
    bool unsigned = false,
  });

  String getAutoIncrementKeyword();

  String getInsertIgnoreSyntax(String tableName);

  String formatDefaultValue(dynamic value, ColumnType type);

  bool supportsUnsigned();

  String getLimitOffsetClause(int? limit, int? offset);

  String getTableExistsQuery(String tableName);

  String wrapBindingPlaceholder(int index);

  String getTransactionBegin();

  String getTransactionCommit();

  String getTransactionRollback();

  bool supportsForeignKeyConstraints();

  String? getCreateIndexSyntax(
    String tableName,
    String columnName,
    String indexName, {
    bool unique = false,
  });
}
