import 'package:forge_core/forge_core.dart';
import '../../forge_orm.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../dialect/sql_dialect.dart';
import '../dialect/sqlite_dialect.dart';

/// SQLite database implementation
/// Provides connection management for SQLite databases (file-based or in-memory)
class SqliteDatabase implements Database {
  final String? path;

  sqlite.Database? _database;

  final SqliteDialect _dialect = SqliteDialect();

  SqliteDatabase({
    required this.path,
  });

  @override
  Future<void> connect() async {
    try {
      _database ??= (path != null && path!.isNotEmpty)
          ? sqlite.sqlite3.open(path!)
          : sqlite.sqlite3.openInMemory();
    } catch (e, stackTrace) {
      throw ConnectionException(
        message: 'Failed to connect to SQLite database: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Connection get connection {
    if (_database == null) {
      throw ConnectionException(
        message: 'No active database connection. Call connect() first.',
      );
    }
    return SqliteConnection(_database!, _dialect);
  }

  @override
  SqlDialect get dialect => _dialect;

  @override
  Future<void> closeAllConnections() async {
    if (_database != null) {
      try {
        _database!.dispose();
        _database = null;
      } catch (e, stackTrace) {
        throw ConnectionException(
          message: 'Failed to close database connection: $e',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

/// SQLite connection implementation
/// Handles query execution and transaction management
class SqliteConnection implements Connection {
  final sqlite.Database _database;
  final SqliteDialect _dialect;

  late final EventBus? eventBus;

  SqliteConnection(this._database, this._dialect);

  @override
  bool get isConnected => true;

  @override
  SqlDialect get dialect => _dialect;

  @override
  set withEventBus(EventBus eventBus) {
    this.eventBus = eventBus;
  }

  @override
  Future<void> connect() async {
    // SQLite doesn't require explicit connection
  }

  @override
  Future<void> disconnect() async {
    // SQLite connections are managed by the Database instance
  }

  @override
  Future<QueryResult> execute(String query, [List<dynamic>? parameters]) async {
    try {
      // Execute query without parameters
      if (parameters == null || parameters.isEmpty) {
        final result = _database.select(query);
        return SqliteQueryResult(
          result,
          _database.lastInsertRowId,
          _database.updatedRows,
        );
      }

      // Execute query with parameters using prepared statement
      final stmt = _database.prepare(query);

      try {
        final result = stmt.select(_parseParameters(parameters));
        return SqliteQueryResult(
          result,
          _database.lastInsertRowId,
          _database.updatedRows,
        );
      } finally {
        stmt.dispose();
      }
    } catch (e, stackTrace) {
      throw SqliteExceptionParser.parse(
        e,
        query,
        parameters,
        stackTrace: stackTrace,
      );
    }
  }

  /// Parses parameters to SQLite-compatible types
  /// Converts DateTime to ISO8601 string format
  List<dynamic> _parseParameters(List<dynamic> parameters) {
    return parameters.map((param) {
      if (param is DateTime) {
        return param.toIso8601String();
      }
      return param;
    }).toList();
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Connection connection) callback,
  ) async {
    // Begin transaction
    try {
      _database.execute(_dialect.getTransactionBegin());
    } catch (e, stackTrace) {
      throw TransactionException(
        message: 'Failed to begin transaction',
        state: TransactionState.begin,
        originalError: e,
        stackTrace: stackTrace,
      );
    }

    try {
      final result = await callback(this);

      try {
        _database.execute(_dialect.getTransactionCommit());
      } catch (e, stackTrace) {
        throw TransactionException(
          message: 'Failed to commit transaction',
          state: TransactionState.commit,
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      return result;
    } catch (e) {
      try {
        _database.execute(_dialect.getTransactionRollback());
      } catch (rollbackError, rollbackStackTrace) {
        throw TransactionException(
          message: 'Failed to rollback transaction after error: $e',
          state: TransactionState.rollback,
          originalError: rollbackError,
          stackTrace: rollbackStackTrace,
        );
      }

      rethrow;
    }
  }
}

/// SQLite query result implementation
/// Wraps SQLite ResultSet with standard QueryResult interface
class SqliteQueryResult implements QueryResult {
  final sqlite.ResultSet _result;
  final int _lastInsertId;

  @override
  final int affectedRows;

  SqliteQueryResult(this._result, this._lastInsertId, this.affectedRows);

  @override
  List<Map<String, dynamic>> get rows {
    return _result.map((row) {
      return row.map((key, value) => MapEntry(key, value));
    }).toList();
  }

  @override
  int? get insertId => _lastInsertId > 0 ? _lastInsertId : null;

  @override
  bool get hasResults => _result.isNotEmpty;
}
