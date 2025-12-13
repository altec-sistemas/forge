// file: database.dart
import 'package:forge_core/forge_core.dart';
import 'dialect/sql_dialect.dart';

/// Represents an active execution context (session) capable of running queries.
///
/// This interface focuses purely on execution and transaction handling.
/// It assumes the physical connection is already open and managed by a [Database] instance.
abstract class Connection {
  /// Unique ID for this connection (useful for debugging/logging)
  String get id;

  /// Sets the [EventBus] to be used for logging query execution events.
  set withEventBus(EventBus eventBus);

  /// The dialect of the underlying database (e.g., MySQL, SQLite).
  SqlDialect get dialect;

  /// Executes a query and returns the result.
  ///
  /// Parameters are optional and will be bound to placeholders (usually `?`) in the query.
  Future<QueryResult> execute(String query, [List<dynamic>? parameters]);

  /// Executes a callback within a transaction.
  ///
  /// The connection used in the callback is bound to the transaction.
  Future<T> transaction<T>(Future<T> Function(Connection connection) callback);

  /// Releases this connection, returning it to the pool or closing its resources.
  ///
  /// Must be called after usage to prevent connection leaks.
  Future<void> close();
}

/// Represents the result of a database query execution.
abstract class QueryResult {
  /// The list of rows returned by the query, where each row is a map of column names to values.
  List<Map<String, Object?>> get rows;

  /// The number of rows affected by an INSERT, UPDATE, or DELETE operation.
  int get affectedRows;

  /// The ID of the last inserted row (if applicable).
  int? get insertId;

  /// True if the query returned any rows (e.g., SELECT statement).
  bool get hasResults;
}

/// Represents the physical database driver/pool manager.
///
/// This is responsible for the overall lifecycle (connecting to the DB server,
/// maintaining the connection pool, and acquiring active execution contexts).
abstract class Database {
  /// Opens the physical connection (or pool) to the database server.
  Future<void> open();

  /// Closes all physical connections (application shutdown).
  Future<void> close();

  /// Acquires an active connection for execution.
  ///
  /// The returned [Connection] is ready to execute queries and must be released
  /// via [Connection.close()] when finished.
  Future<Connection> acquireConnection();

  /// Executes a query and returns the result.
  ///
  /// Parameters are optional and will be bound to placeholders (usually `?`) in the query.
  Future<QueryResult> execute(String query, [List<dynamic>? parameters]) {
    return acquireConnection().then((connection) async {
      try {
        return await connection.execute(query, parameters);
      } finally {
        await connection.close();
      }
    });
  }

  /// Executes a callback within a transaction.
  ///
  /// The connection used in the callback is bound to the transaction.
  Future<T> transaction<T>(Future<T> Function(Connection connection) callback) {
    return acquireConnection().then((connection) async {
      try {
        return await connection.transaction(callback);
      } finally {
        await connection.close();
      }
    });
  }

  /// Check if the physical connection/pool is initialized and ready.
  bool get isOpen;

  /// The dialect of the underlying database (e.g., MySQL, SQLite).
  SqlDialect get dialect;
}

/// Represents a pre-compiled SQL query and its bound parameters.
class CompiledQuery {
  final String sql;
  final List<dynamic> bindings;

  const CompiledQuery({required this.sql, required this.bindings});

  @override
  String toString() => sql;
}

/// Event fired after a database query has been executed.
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
