import 'package:forge_core/forge_core.dart';
import '../../forge_orm.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart' as mysql;

import '../dialect/mysql_dialect.dart';
import '../dialect/sql_dialect.dart';

class MySQLDatabase implements Database {
  final String host;
  final int port;
  final String username;
  final String password;
  final String database;
  final bool secure;

  mysql.MySQLConnection? _connection;

  final MySqlDialect _dialect = MySqlDialect();

  MySQLDatabase({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.database,
    this.secure = true,
  });

  @override
  Future<void> connect() async {
    if (_connection == null || _connection!.connected == false) {
      _connection = await mysql.MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: username,
        password: password,
        databaseName: database,
        secure: secure,
      );
      await _connection!.connect();
    }
  }

  @override
  Connection get connection {
    if (_connection == null || _connection!.connected == false) {
      throw Exception('No active database connection. Call connect() first.');
    }
    return MySQLConnection(_connection!, _dialect);
  }

  @override
  SqlDialect get dialect => _dialect;

  @override
  Future<void> closeAllConnections() async {
    if (_connection != null && _connection!.connected) {
      try {
        await _connection!.close();
      } catch (_) {
        // Ignora erros ao fechar a conexão
      }
    }
  }
}

class MySQLConnection implements Connection {
  final mysql.MySQLConnection _connection;
  final MySqlDialect _dialect;

  late final EventBus? eventBus;

  MySQLConnection(this._connection, this._dialect);

  @override
  bool get isConnected => _connection.connected;

  @override
  SqlDialect get dialect => _dialect;

  @override
  set withEventBus(EventBus eventBus) {
    this.eventBus = eventBus;
  }

  @override
  Future<void> connect() async {
    if (!_connection.connected) {
      await _connection.connect();
    }
  }

  @override
  Future<void> disconnect() async {
    if (_connection.connected) {
      await _connection.close();
    }
  }

  @override
  Future<QueryResult> execute(String query, [List<dynamic>? parameters]) async {
    try {
      if (parameters == null || parameters.isEmpty) {
        return MySQLQueryResult(await _connection.execute(query));
      }

      int index = 0;
      final processedQuery = query.replaceAllMapped(RegExp(r'\?'), (match) {
        return ':p${index++}';
      });

      final processedParams = <String, dynamic>{};
      for (int i = 0; i < parameters.length; i++) {
        processedParams['p$i'] = parameters[i];
      }

      return MySQLQueryResult(
        await _connection.execute(processedQuery, processedParams),
      );
    } catch (e) {
      throw MySqlExceptionParser.parse(e, query, parameters);
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Connection connection) callback,
  ) async {
    await _connection.execute(_dialect.getTransactionBegin());
    try {
      final result = await callback(this);
      await _connection.execute(_dialect.getTransactionCommit());
      return result;
    } catch (e) {
      await _connection.execute(_dialect.getTransactionRollback());
      rethrow;
    }
  }
}

class MySQLQueryResult implements QueryResult {
  final mysql.IResultSet _result;

  MySQLQueryResult(this._result);

  @override
  List<Map<String, dynamic>> get rows {
    return _result.rows.map((row) => row.typedAssoc()).toList();
  }

  List<Map<String, dynamic>> get rawRows {
    return _result.rows.map((row) => row.assoc()).toList();
  }

  @override
  int get affectedRows => _result.affectedRows.toInt();

  @override
  int? get insertId => _result.lastInsertID.toInt();

  @override
  bool get hasResults => _result.rows.isNotEmpty;
}
