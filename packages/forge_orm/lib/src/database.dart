import 'package:forge_core/forge_core.dart';
import 'dialect/sql_dialect.dart';

abstract class Connection {
  bool get isConnected;
  set withEventBus(EventBus eventBus);
  SqlDialect get dialect;
  Future<void> connect();
  Future<void> disconnect();
  Future<QueryResult> execute(String query, [List<dynamic>? parameters]);
  Future<T> transaction<T>(Future<T> Function(Connection connection) callback);
}

abstract class QueryResult {
  List<Map<String, Object?>> get rows;

  int get affectedRows;

  int? get insertId;

  bool get hasResults;
}

abstract class Database {
  Future<void> connect();

  Future<void> closeAllConnections();

  Connection get connection;

  SqlDialect get dialect;
}

class CompiledQuery {
  final String sql;
  final List<dynamic> bindings;

  const CompiledQuery({required this.sql, required this.bindings});

  @override
  String toString() => sql;
}

class QueryExecutedEvent {
  final String query;
  final List<dynamic> parameters;
  final Duration duration;

  QueryExecutedEvent({
    required this.query,
    required this.parameters,
    required this.duration,
  });
}
