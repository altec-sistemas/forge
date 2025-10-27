import 'package:forge_framework/forge_framework.dart';
import 'package:forge_orm/forge_orm.dart';

import '../entity/user.dart';

@Module()
class OrmConfig {
  @Provide()
  DatabaseConfig get databaseConfig => DatabaseConfig(
    connection: SqliteConfig.inMemory(),
  );

  @Boot()
  Future<void> initializeOrm(
    Database database,
    MetadataSchemaResolver schemaResolver,
    Logger logger,
  ) async {
    await database.connect();

    final migrator = SchemaCreator(database, schemaResolver);
    await migrator.createTables([User]);

    logger.success('Tables created successfully.');
  }
}
