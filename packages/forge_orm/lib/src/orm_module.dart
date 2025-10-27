import 'package:forge_core/forge_core.dart';
import '../forge_orm.dart';
import 'connection/mysql_connection.dart';
import 'connection/sqllite_connection.dart';

@Module()
class OrmModule {
  /// Cria a factory de conexão
  @ProvideSingleton()
  ConnectionFactory createConnectionFactory(Injector injector) {
    return ConnectionFactory(
      injector.contains<DatabaseConfig>()
          ? injector.get<DatabaseConfig>()
          : throw Exception(
              '''DatabaseConfig not found in Injector. Please provide a DatabaseConfig instance to configure the database connection.''',
            ),
    );
  }

  /// Cria e conecta o Database
  @ProvideSingleton()
  Database createDatabase(ConnectionFactory factory) {
    return factory.create();
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
    Database database,
    Serializer serializer,
    MetadataSchemaResolver schemaResolver,
  ) {
    return EntityManagerImpl(
      schemaResolver: schemaResolver,
      database: database,
      serializer: serializer,
    );
  }

  /// Cria a instância principal do ORM
  @ProvideSingleton()
  Orm createOrm(
    Database database,
    Serializer serializer,
    MetadataSchemaResolver schemaResolver,
  ) {
    return OrmImpl(
      database: database,
      serializer: serializer,
      schemaResolver: schemaResolver,
    );
  }

  /// Fecha conexões no shutdown
  @Boot()
  Future<void> setupDatabaseConnection(Database database) async {
    await database.connect();
  }
}

/// Factory para criar conexões baseadas em URI
class ConnectionFactory {
  final DatabaseConfig config;

  ConnectionFactory(this.config);

  /// Cria a instância de Database apropriada baseada na URI
  Database create() {
    switch (config.connection) {
      case MySQLConfig mysqlConfig:
        return MySQLDatabase(
          host: mysqlConfig.host,
          port: mysqlConfig.port,
          username: mysqlConfig.username,
          password: mysqlConfig.password,
          database: mysqlConfig.database,
          secure: mysqlConfig.secure,
        );

      case SqliteConfig sqliteConfig:
        return SqliteDatabase(path: sqliteConfig.path);

      default:
        throw UnsupportedError('PostgresSQL support not implemented yet');
    }
  }
}
