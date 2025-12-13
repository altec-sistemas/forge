import 'package:forge_core/forge_core.dart';
import '../../forge_orm.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart' as mysql;

import '../dialect/mysql_dialect.dart';
import '../dialect/sql_dialect.dart';

class MySQLDatabase extends Database {
  final String host;
  final int port;
  final String username;
  final String password;
  final String databaseName;
  final bool secure;

  mysql.MySQLConnection? _driverConnection;
  final MySqlDialect _dialect = MySqlDialect();

  MySQLDatabase({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.databaseName,
    this.secure = true,
  });

  @override
  bool get isOpen => _driverConnection != null && _driverConnection!.connected;

  @override
  SqlDialect get dialect => _dialect;

  @override
  Future<void> open() async {
    if (isOpen) return;

    try {
      _driverConnection = await mysql.MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: username,
        password: password,
        secure: secure,
        databaseName: databaseName,
      );

      await _driverConnection!.connect();
    } catch (e, stackTrace) {
      throw ConnectionException(
        message: 'Failed to open MySQL database: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
    // A biblioteca mysql_client_plus já lida com seleção de DB na conexão
    // mas se necessário: await _driverConnection!.execute('USE `$databaseName`');
  }

  @override
  Future<Connection> acquireConnection() async {
    if (!isOpen) {
      await open();
    }

    return MySQLConnectionWrapper(_driverConnection!, _dialect);
  }

  @override
  Future<void> close() async {
    if (_driverConnection != null) {
      await _driverConnection!.close();
      _driverConnection = null;
    }
  }
}

class MySQLConnectionWrapper implements Connection {
  final mysql.MySQLConnection _driver;
  final MySqlDialect _dialect;
  EventBus? _eventBus;

  MySQLConnectionWrapper(this._driver, this._dialect);

  @override
  String get id => 'mysql-${identityHashCode(this)}';

  @override
  SqlDialect get dialect => _dialect;

  @override
  set withEventBus(EventBus eventBus) => _eventBus = eventBus;

  @override
  Future<void> close() async {
    // Em uma implementação de pool real, aqui devolveríamos a conexão ao pool.
    // Como estamos usando a conexão compartilhada do driver neste exemplo específico,
    // não fechamos a conexão física aqui, apenas marcamos o wrapper como concluído se necessário.
  }

  @override
  Future<QueryResult> execute(String query, [List<dynamic>? parameters]) async {
    final start = DateTime.now();
    try {
      if (parameters == null || parameters.isEmpty) {
        final result = await _driver.execute(query);
        _logQuery(query, [], start);
        return MySQLQueryResult(result);
      }

      // Tratamento de parâmetros (exemplo simples)
      int index = 0;
      final processedQuery = query.replaceAllMapped(
        RegExp(r'\?'),
        (_) => ':p${index++}',
      );
      final processedParams = <String, dynamic>{};
      for (int i = 0; i < parameters.length; i++) {
        processedParams['p$i'] = parameters[i];
      }

      final result = await _driver.execute(processedQuery, processedParams);
      _logQuery(query, parameters, start);
      return MySQLQueryResult(result);
    } catch (e) {
      throw MySqlExceptionParser.parse(e, query, parameters);
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

  @override
  Future<T> transaction<T>(
    Future<T> Function(Connection connection) callback,
  ) async {
    // MySQL implementation specific
    await execute('START TRANSACTION');
    try {
      // Cria um novo wrapper que compartilha a MESMA conexão física
      // (já que estamos dentro de uma transação na mesma conexão TCP)
      final result = await callback(this);
      await execute('COMMIT');
      return result;
    } catch (e) {
      await execute('ROLLBACK');
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
