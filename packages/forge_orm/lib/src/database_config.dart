class DatabaseConfig {
  final Map<String, ConnectionConfig> connections;
  final String defaultConnectionName;

  final int? maxConnections;
  final Duration? timeout;

  DatabaseConfig({
    required this.connections,
    required this.defaultConnectionName,
    this.maxConnections,
    this.timeout,
  }) {
    assert(
      connections.containsKey(defaultConnectionName),
      'A conexão padrão "$defaultConnectionName" não está definida em connections.',
    );
  }

  ConnectionConfig get defaultConnection => connections[defaultConnectionName]!;
}

abstract class ConnectionConfig {}

class MySQLConfig implements ConnectionConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String database;
  final bool secure;

  const MySQLConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.database,
    this.secure = true,
  });
}

class SqliteConfig implements ConnectionConfig {
  final String? path;

  const SqliteConfig({
    required this.path,
  });

  factory SqliteConfig.inMemory() => SqliteConfig(path: null);
}
