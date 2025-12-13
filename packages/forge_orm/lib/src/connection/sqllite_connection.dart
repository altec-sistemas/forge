import 'package:forge_core/forge_core.dart';
import '../../forge_orm.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../dialect/sql_dialect.dart';
import '../dialect/sqlite_dialect.dart';

/// SQLite database implementation
/// Acts as the manager for the SQLite database instance.
class SqliteDatabase extends Database {
  final String? path;

  sqlite.Database? _database;
  final SqliteDialect _dialect = SqliteDialect();

  SqliteDatabase({
    required this.path,
  });

  @override
  bool get isOpen => _database != null;

  @override
  SqlDialect get dialect => _dialect;

  @override
  Future<void> open() async {
    if (isOpen) return;

    try {
      _database = (path != null && path!.isNotEmpty)
          ? sqlite.sqlite3.open(path!)
          : sqlite.sqlite3.openInMemory();

      // Opcional: Configurações padrão de performance/segurança
      _database!.execute('PRAGMA foreign_keys = ON;');
    } catch (e, stackTrace) {
      throw ConnectionException(
        message: 'Failed to open SQLite database: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Connection> acquireConnection() async {
    if (!isOpen) {
      await open();
    }

    return SqliteConnection(_database!, _dialect);
  }

  @override
  Future<void> close() async {
    if (_database != null) {
      try {
        _database!.dispose();
        _database = null;
      } catch (e, stackTrace) {
        throw ConnectionException(
          message: 'Failed to close database: $e',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

/// SQLite connection implementation
/// Handles query execution, event logging, and transactions.
class SqliteConnection implements Connection {
  final sqlite.Database _database;
  final SqliteDialect _dialect;

  EventBus? _eventBus;

  SqliteConnection(this._database, this._dialect);

  @override
  String get id => 'sqlite-${identityHashCode(this)}';

  @override
  SqlDialect get dialect => _dialect;

  @override
  set withEventBus(EventBus eventBus) {
    _eventBus = eventBus;
  }

  @override
  Future<void> close() async {
    _database.dispose();
  }

  @override
  Future<QueryResult> execute(String query, [List<dynamic>? parameters]) async {
    final start = DateTime.now();
    try {
      final processedParams = _parseParameters(parameters ?? []);

      late SqliteQueryResult result;

      if (processedParams.isEmpty) {
        final rs = _database.select(query);
        result = SqliteQueryResult(
          rs,
          _database.lastInsertRowId,
          _database.updatedRows,
        );
      } else {
        // Execute query with parameters using prepared statement
        final stmt = _database.prepare(query);
        try {
          final rs = stmt.select(processedParams);
          result = SqliteQueryResult(
            rs,
            _database.lastInsertRowId,
            _database.updatedRows,
          );
        } finally {
          stmt.dispose();
        }
      }

      _logQuery(query, processedParams, start);
      return result;
    } catch (e, stackTrace) {
      throw SqliteExceptionParser.parse(
        e,
        query,
        parameters,
        stackTrace: stackTrace,
      );
    }
  }

  void _logQuery(String query, List<dynamic> params, DateTime start) {
    if (_eventBus != null) {
      _eventBus!.dispatch(
        QueryExecutedEvent(
          query: query,
          parameters: params,
          duration: DateTime.now().difference(start),
        ),
      );
    }
  }

  /// Parses parameters to SQLite-compatible types
  List<dynamic> _parseParameters(List<dynamic> parameters) {
    return parameters.map((param) {
      if (param is DateTime) {
        return param.toIso8601String();
      }
      if (param is bool) {
        return param ? 1 : 0;
      }
      return param;
    }).toList();
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Connection connection) callback,
  ) async {
    // In SQLite, transactions are serial.
    // We execute statements directly on the shared _database instance.
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
      // We pass 'this' because in SQLite (blocking FFI),
      // the transaction is bound to the connection thread/instance.
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
