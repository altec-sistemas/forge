import 'package:forge_framework/forge_framework.dart';
import 'package:forge_orm/forge_orm.dart';

import '../entity/user.dart';

@Module()
class OrmConfig {
  @Provide()
  DatabaseConfig get databaseConfig => DatabaseConfig(
    defaultConnectionName: 'default',
    connections: {
      'default': SqliteConfig.inMemory(),
    },
  );

  @Boot()
  Future<void> initializeOrm(
    Database database,
    MetadataSchemaResolver schemaResolver,
    Logger logger,
  ) async {
    await database.open();

    final migrator = Migrator(database, schemaResolver);
    await migrator.createTables([User]);

    logger.success('Tables created successfully.');
  }
}
