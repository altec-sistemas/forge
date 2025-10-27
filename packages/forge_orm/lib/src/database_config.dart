
class DatabaseConfig {
  final ConnectionConfig connection;
  final int? maxConnections;
  final Duration? timeout;

  const DatabaseConfig({
    required this.connection,
    this.maxConnections,
    this.timeout,
  });
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
