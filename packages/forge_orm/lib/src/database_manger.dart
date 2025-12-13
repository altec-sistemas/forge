// file: database_manger.dart
import 'package:forge_core/forge_core.dart';
import '../forge_orm.dart';

/// Manages multiple named database connections and configurations.
///
/// This is the central access point for obtaining Database instances and
/// acquiring live connections.
class DatabaseManager {
  final Map<String, Database> _databases = {};
  final Map<String, ConnectionConfig> _configs = {};
  final ConnectionFactory _factory;

  String? _defaultKey;

  /// Creates a [DatabaseManager] using a [ConnectionFactory] to instantiate drivers.
  DatabaseManager(this._factory);

  /// Registers a new database configuration and initializes the driver.
  ///
  /// The driver instance is created via the [ConnectionFactory], and the [Database.open]
  /// method is called to establish the physical connection/pool.
  Future<void> register(
    String key,
    ConnectionConfig config, {
    bool isDefault = false,
  }) async {
    if (_databases.containsKey(key)) {
      await remove(key);
    }

    _configs[key] = config;
    final database = _factory.create(config);
    _databases[key] = database;

    if (isDefault || _defaultKey == null) {
      _defaultKey = key;
    }
  }

  /// Reconfigures and re-registers an existing database key.
  Future<void> reconfigure(String key, ConnectionConfig config) async {
    await remove(key);
    await register(key, config, isDefault: key == _defaultKey);
  }

  /// Removes a registered database and closes its connections.
  Future<void> remove(String key) async {
    final database = _databases.remove(key);
    await database?.close(); // Usa close()
    _configs.remove(key);

    if (_defaultKey == key) {
      _defaultKey = _databases.keys.firstOrNull;
    }
  }

  /// Retrieves a registered [Database] instance by its key.
  Database getDatabase([String? key]) {
    final targetKey = key ?? _defaultKey;
    final database = _databases[targetKey];
    if (database == null) {
      throw StateError(
        'Database "$targetKey" not registered or default not set',
      );
    }
    return database;
  }

  /// Helper to acquire an active [Connection] from the specified or default database.
  Future<Connection> acquireConnection([String? key]) async {
    final database = getDatabase(key);
    if (!database.isOpen) {
      await database.open();
    }
    return database.acquireConnection();
  }

  /// Retrieves the default registered [Database] instance.
  Database get defaultDatabase => getDatabase(_defaultKey);

  /// Sets a new default database key.
  void setDefault(String key) {
    if (!_databases.containsKey(key)) {
      throw StateError('Database "$key" not registered');
    }
    _defaultKey = key;
  }

  /// Checks if a database key is registered.
  bool has(String key) => _databases.containsKey(key);

  /// Returns a list of all registered database keys.
  List<String> get keys => _databases.keys.toList();

  /// Closes all registered database connections and clears the manager.
  Future<void> closeAll() async {
    for (final database in _databases.values) {
      await database.close();
    }
    _databases.clear();
    _configs.clear();
    _defaultKey = null;
  }

  /// Connect all registered database connections.
  Future<void> connectAll() async {
    for (final database in _databases.values) {
      if (!database.isOpen) {
        await database.open();
      }
    }
  }
}
