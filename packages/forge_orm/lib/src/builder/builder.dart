import '../../forge_orm.dart';
import 'package:meta/meta.dart';

import '../dialect/sql_dialect.dart';

class Expression {
  final String value;
  final bool isRaw;

  const Expression(this.value, {this.isRaw = false});

  factory Expression.column(String column) => Expression(column);

  factory Expression.raw(String sql) => Expression(sql, isRaw: true);

  @override
  String toString() => value;
}

Expression raw(String sql) => Expression.raw(sql);

Expression col(String column) => Expression.column(column);

abstract class Builder<T extends Builder<T>> {
  @internal
  final Database database;

  @internal
  Connection get connection => database.connection;

  @internal
  SqlDialect get dialect => database.dialect;

  @internal
  final List<String> selectedColumns = [];

  @internal
  String? fromTable;

  @internal
  String? tableAlias;

  @internal
  final List<String> joins = [];

  @internal
  final List<String> wheres = [];

  @internal
  final List<String> groupByColumns = [];

  @internal
  final List<String> orderByColumns = [];

  @internal
  final List<dynamic> bindings = [];

  @internal
  int? limitValue;

  @internal
  int? offsetValue;

  @internal
  bool isDistinct = false;

  @internal
  final Map<String, String> tableAliases = {};

  Builder(this.database);

  T get self => this as T;

  T createNew();

  @internal
  String resolveColumn(dynamic column, {bool useTablePrefix = false}) {
    if (column is Expression) {
      if (column.isRaw) return column.value;
      column = column.value;
    }

    final columnStr = column.toString();
    if (columnStr.contains('.')) {
      final parts = columnStr.split('.');
      if (parts.length == 2) {
        final tablePart = parts[0];
        if (tableAliases.containsKey(tablePart)) return columnStr;
        if (tableAlias != null && !tableAliases.containsValue(tablePart)) {
          return columnStr;
        }
      }
      return columnStr;
    }

    if (tableAlias != null) return '$tableAlias.$columnStr';
    if (fromTable != null && useTablePrefix) {
      return '$fromTable.$columnStr';
    }
    return columnStr;
  }

  @internal
  String resolveTable(String table) => tableAliases[table] ?? table;

  T select([List<dynamic> columns = const ['*']]) {
    selectedColumns.clear();
    for (final column in columns) {
      _addSelectColumn(column);
    }
    return self;
  }

  T addSelect(List<dynamic> columns) {
    for (final column in columns) {
      _addSelectColumn(column);
    }
    return self;
  }

  void _addSelectColumn(dynamic column) {
    if (_isWildcardColumn(column)) {
      selectedColumns.add('*');
      return;
    }

    if (column is Expression && column.isRaw) {
      selectedColumns.add(column.value);
      return;
    }

    selectedColumns.add(resolveColumn(column));
  }

  bool _isWildcardColumn(dynamic column) {
    return column == '*' || (column is Expression && column.value == '*');
  }

  T distinct([bool value = true]) {
    isDistinct = value;
    return self;
  }

  T from(String table, [String? alias]) {
    fromTable = table;
    tableAlias = alias;
    if (alias != null) {
      tableAliases[alias] = table;
      fromTable = '$table AS $alias';
    }
    return self;
  }

  T join(
    String table,
    dynamic first,
    String operator,
    dynamic second, [
    String? alias,
  ]) {
    _addJoin('INNER JOIN', table, first, operator, second, alias);
    return self;
  }

  T leftJoin(
    String table,
    dynamic first,
    String operator,
    dynamic second, [
    String? alias,
  ]) {
    _addJoin('LEFT JOIN', table, first, operator, second, alias);
    return self;
  }

  T rightJoin(
    String table,
    dynamic first,
    String operator,
    dynamic second, [
    String? alias,
  ]) {
    _addJoin('RIGHT JOIN', table, first, operator, second, alias);
    return self;
  }

  T crossJoin(String table, [String? alias]) {
    final tableWithAlias = alias != null ? '$table AS $alias' : table;
    if (alias != null) tableAliases[alias] = table;
    joins.add('CROSS JOIN $tableWithAlias');
    return self;
  }

  void _addJoin(
    String type,
    String table,
    dynamic first,
    String operator,
    dynamic second, [
    String? alias,
  ]) {
    final tableWithAlias = alias != null ? '$table AS $alias' : table;
    if (alias != null) tableAliases[alias] = table;

    final resolvedFirst = resolveColumn(first);
    final String joinCondition;

    if (second is Expression) {
      final secondStr = second.isRaw ? second.value : resolveColumn(second);
      joinCondition = '$resolvedFirst $operator $secondStr';
    } else if (second is String) {
      String secondStr = second;
      if (secondStr.contains('.')) {
        final parts = secondStr.split('.');
        if (parts.length == 2) {
          final tablePart = parts[0];
          final columnPart = parts[1];
          // Check if this table has an alias defined
          final aliasForTable = tableAliases.entries
              .firstWhere(
                (entry) => entry.value == tablePart,
                orElse: () => MapEntry(tablePart, tablePart),
              )
              .key;
          secondStr = '$aliasForTable.$columnPart';
        }
      }
      joinCondition = '$resolvedFirst $operator $secondStr';
    } else {
      bindings.add(second);
      joinCondition = '$resolvedFirst $operator ?';
    }

    joins.add('$type $tableWithAlias ON $joinCondition');
  }

  T withFilter(QueryFilter filter) {
    filter.apply(self);
    return self;
  }

  T where(
    dynamic column, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqual,
    Object? isLessThan,
    Object? isLessThanOrEqual,
    Object? contains,
    Object? startsWith,
    Object? endsWith,
  }) {
    _addWhereOperator(
      column,
      'AND',
      isEqualTo,
      isNotEqualTo,
      isGreaterThan,
      isGreaterThanOrEqual,
      isLessThan,
      isLessThanOrEqual,
      contains,
      startsWith,
      endsWith,
    );
    return self;
  }

  T orWhere(
    dynamic column, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqual,
    Object? isLessThan,
    Object? isLessThanOrEqual,
    Object? contains,
    Object? startsWith,
    Object? endsWith,
  }) {
    _addWhereOperator(
      column,
      'OR',
      isEqualTo,
      isNotEqualTo,
      isGreaterThan,
      isGreaterThanOrEqual,
      isLessThan,
      isLessThanOrEqual,
      contains,
      startsWith,
      endsWith,
    );
    return self;
  }

  T whereIn(dynamic column, List<Object?> values) =>
      _addWhereIn(column, values, true, 'AND');

  T orWhereIn(dynamic column, List<Object?> values) =>
      _addWhereIn(column, values, true, 'OR');

  T whereNotIn(dynamic column, List<Object?> values) =>
      _addWhereIn(column, values, false, 'AND');

  T orWhereNotIn(dynamic column, List<Object?> values) =>
      _addWhereIn(column, values, false, 'OR');

  T _addWhereIn(
    dynamic column,
    List<Object?> values,
    bool isIn,
    String boolean,
  ) {
    if (values.isEmpty) {
      _addCondition(isIn ? '1 = 0' : '1 = 1', boolean);
      return self;
    }

    final resolvedColumn = resolveColumn(column);
    bindings.addAll(values);
    final placeholders = List.filled(values.length, '?').join(', ');
    final operator = isIn ? 'IN' : 'NOT IN';
    _addCondition('$resolvedColumn $operator ($placeholders)', boolean);
    return self;
  }

  T whereNull(dynamic column, [String boolean = 'AND']) =>
      _addWhereNull(column, true, boolean);

  T orWhereNull(dynamic column) => _addWhereNull(column, true, 'OR');

  T whereNotNull(dynamic column, [String boolean = 'AND']) =>
      _addWhereNull(column, false, boolean);

  T orWhereNotNull(dynamic column) => _addWhereNull(column, false, 'OR');

  T _addWhereNull(dynamic column, bool isNull, String boolean) {
    final resolvedColumn = resolveColumn(column);
    final condition = isNull
        ? '$resolvedColumn IS NULL'
        : '$resolvedColumn IS NOT NULL';
    _addCondition(condition, boolean);
    return self;
  }

  T whereBetween(dynamic column, dynamic start, dynamic end) =>
      _addBetweenCondition(column, start, end, true, 'AND');

  T orWhereBetween(dynamic column, dynamic start, dynamic end) =>
      _addBetweenCondition(column, start, end, true, 'OR');

  T whereNotBetween(dynamic column, dynamic start, dynamic end) =>
      _addBetweenCondition(column, start, end, false, 'AND');

  T orWhereNotBetween(dynamic column, dynamic start, dynamic end) =>
      _addBetweenCondition(column, start, end, false, 'OR');

  T _addBetweenCondition(
    dynamic column,
    dynamic start,
    dynamic end,
    bool isBetween,
    String boolean,
  ) {
    final resolvedColumn = resolveColumn(column);
    bindings.add(start);
    bindings.add(end);
    final operator = isBetween ? 'BETWEEN' : 'NOT BETWEEN';
    _addCondition('$resolvedColumn $operator ? AND ?', boolean);
    return self;
  }

  T whereExists(void Function(T subQuery) callback) =>
      _addExistsCondition(callback, true, 'AND');

  T orWhereExists(void Function(T subQuery) callback) =>
      _addExistsCondition(callback, true, 'OR');

  T whereNotExists(void Function(T subQuery) callback) =>
      _addExistsCondition(callback, false, 'AND');

  T orWhereNotExists(void Function(T subQuery) callback) =>
      _addExistsCondition(callback, false, 'OR');

  T _addExistsCondition(
    void Function(T subQuery) callback,
    bool exists,
    String boolean,
  ) {
    final subQuery = createNew();
    callback(subQuery);
    bindings.addAll(subQuery.bindings);
    final operator = exists ? 'EXISTS' : 'NOT EXISTS';
    _addCondition('$operator (${subQuery.toSql()})', boolean);
    return self;
  }

  T whereRaw(String sql, [List<dynamic>? bindingValues]) {
    if (bindingValues != null) bindings.addAll(bindingValues);
    _addCondition(sql, 'AND');
    return self;
  }

  T orWhereRaw(String sql, [List<dynamic>? bindingValues]) {
    if (bindingValues != null) bindings.addAll(bindingValues);
    _addCondition(sql, 'OR');
    return self;
  }

  T groupBy(List<dynamic> columns) {
    for (final column in columns) {
      if (column is Expression && column.isRaw) {
        groupByColumns.add(column.value);
      } else {
        groupByColumns.add(resolveColumn(column));
      }
    }
    return self;
  }

  T orderBy(dynamic column, [String direction = 'ASC']) {
    final String columnStr;
    if (column is Expression && column.isRaw) {
      columnStr = column.value;
    } else {
      columnStr = resolveColumn(column);
    }
    orderByColumns.add('$columnStr ${direction.toUpperCase()}');
    return self;
  }

  T orderByDesc(dynamic column) => orderBy(column, 'DESC');

  T limit(int value) {
    limitValue = value;
    return self;
  }

  T offset(int value) {
    offsetValue = value;
    return self;
  }

  T take(int value) => limit(value);

  T skip(int value) => offset(value);

  String toSql() {
    final parts = <String>[];

    parts.add('SELECT');

    if (isDistinct) {
      parts.add('DISTINCT');
    }

    if (selectedColumns.isEmpty) {
      parts.add('*');
    } else {
      parts.add(selectedColumns.join(', '));
    }

    if (fromTable != null) parts.add('FROM $fromTable');
    if (joins.isNotEmpty) parts.addAll(joins);
    if (wheres.isNotEmpty) parts.add('WHERE ${wheres.join(' ')}');
    if (groupByColumns.isNotEmpty) {
      parts.add('GROUP BY ${groupByColumns.join(', ')}');
    }

    if (orderByColumns.isNotEmpty) {
      parts.add('ORDER BY ${orderByColumns.join(', ')}');
    }

    final limitOffsetClause = dialect.getLimitOffsetClause(
      limitValue,
      offsetValue,
    );
    if (limitOffsetClause.isNotEmpty) {
      parts.add(limitOffsetClause);
    }

    return parts.join(' ');
  }

  void _addWhereOperator(
    dynamic column,
    String boolean,
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqual,
    Object? isLessThan,
    Object? isLessThanOrEqual,
    Object? contains,
    Object? startsWith,
    Object? endsWith,
  ) {
    final conditions = <(String, Object?)>[
      ('=', isEqualTo),
      ('!=', isNotEqualTo),
      ('>', isGreaterThan),
      ('>=', isGreaterThanOrEqual),
      ('<', isLessThan),
      ('<=', isLessThanOrEqual),
      ('LIKE', contains != null ? '%$contains%' : null),
      ('LIKE', startsWith != null ? '$startsWith%' : null),
      ('LIKE', endsWith != null ? '%$endsWith' : null),
    ];

    final condition = conditions.firstWhere(
      (c) => c.$2 != null,
      orElse: () => throw ArgumentError('No valid condition provided'),
    );

    final operator = condition.$1;
    final value = condition.$2!;
    final resolvedColumn = resolveColumn(column);

    if (value is Expression) {
      final valueStr = value.isRaw ? value.value : resolveColumn(value);
      _addCondition('$resolvedColumn $operator $valueStr', boolean);
      return;
    }

    bindings.add(value);
    _addCondition('$resolvedColumn $operator ?', boolean);
  }

  void _addCondition(String condition, String boolean) {
    if (wheres.isEmpty) {
      wheres.add(condition);
      return;
    }

    wheres.add('$boolean $condition');
  }

  Future<List<Map<String, Object?>>> get() async {
    final sql = toSql();
    final result = await connection.execute(sql, bindings);
    return result.rows;
  }

  Future<int?> insert(Map<String, Object?> values) async {
    final columns = values.keys.map(resolveColumn).join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    final sql = 'INSERT INTO $fromTable ($columns) VALUES ($placeholders)';
    final params = values.values.toList();
    final result = await connection.execute(sql, params);
    return result.insertId;
  }

  Future<int?> insertIgnore(Map<String, Object?> values) async {
    final columns = values.keys.map(resolveColumn).join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    final insertClause = dialect.getInsertIgnoreSyntax(fromTable!);
    final sql = '$insertClause ($columns) VALUES ($placeholders)';
    final params = values.values.toList();
    final result = await connection.execute(sql, params);
    return result.insertId;
  }

  Future<int> update(Map<String, Object?> values) async {
    final sets = values.keys.map((k) => '${resolveColumn(k)} = ?').join(', ');
    final sql =
        'UPDATE ${resolveTable(fromTable!)} SET $sets ${_buildWhereClause()}';
    final params = [...values.values, ...bindings];
    final result = await connection.execute(sql, params);
    return result.affectedRows;
  }

  Future<int> delete() async {
    final sql =
        'DELETE FROM ${resolveTable(fromTable!)} ${_buildWhereClause()}';
    final result = await connection.execute(sql, bindings);
    return result.affectedRows;
  }

  String _buildWhereClause() {
    if (wheres.isEmpty) return '';
    return 'WHERE ${wheres.join(' ')}';
  }
}

abstract class QueryFilter<T extends Builder<T>> {
  void apply(T builder);
}
