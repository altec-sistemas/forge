import 'package:forge_core/forge_core.dart';
import '../forge_orm.dart';
import 'connection/mysql_connection.dart';
import 'connection/sqllite_connection.dart';
import 'database_manger.dart';

final _log = Logger('Orm');

@Module()
class OrmModule {
  /// Cria e conecta o Database
  @ProvideSingleton()
  DatabaseManager createDatabase(Injector injector) {
    final config = injector.tryGet<DatabaseConfig>();
    final factory = DatabaseManager(ConnectionFactory());

    if (config == null) {
      throw StateError('No DatabaseConfig found in Injector');
    }

    for (final entry in config.connections.entries) {
      factory.register(
        entry.key,
        entry.value,
        isDefault: config.defaultConnectionName == entry.key,
      );
    }

    return factory;
  }

  @Provide()
  MetadataSchemaResolver createSchemaResolver(
    MetadataRegistry metadataRegistry,
    Injector injector,
  ) {
    return MetadataSchemaResolver(
      metadataRegistry,
      injector.contains<NamingStrategy>()
          ? injector.get<NamingStrategy>()
          : DefaultNamingStrategy(),
    );
  }

  @Provide()
  EntityManager createEntityManager(
    Orm orm,
  ) {
    return orm.entityManager;
  }

  /// Cria a instância principal do ORM
  @Provide()
  Orm createOrm(
    DatabaseManager manager,
    Serializer serializer,
    MetadataSchemaResolver schemaResolver,
  ) {
    return OrmImpl(
      serializer: serializer,
      schemaResolver: schemaResolver,
      database: manager.defaultDatabase,
    );
  }

  @Boot()
  Future<void> setupDatabaseConnection(DatabaseManager databaseManager) async {
    try {
      await databaseManager.connectAll();
    } catch (e) {
      _log.error('Error connecting to database', error: e);
    }
  }
}

/// Factory para criar conexões baseadas em URI
class ConnectionFactory {
  /// Cria a instância de Database apropriada baseada na URI
  Database create(ConnectionConfig config) {
    switch (config) {
      case MySQLConfig mysqlConfig:
        return MySQLDatabase(
          host: mysqlConfig.host,
          port: mysqlConfig.port,
          username: mysqlConfig.username,
          password: mysqlConfig.password,
          databaseName: mysqlConfig.database,
          secure: mysqlConfig.secure,
        );

      case SqliteConfig sqliteConfig:
        return SqliteDatabase(path: sqliteConfig.path);

      default:
        throw UnsupportedError('PostgresSQL support not implemented yet');
    }
  }
}
