// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000
// ignore_for_file: prefer_relative_imports, depend_on_referenced_packages, camel_case_types

import 'package:forge_core/forge_core.dart';

import 'database.dart' as prefix7;
import 'entity_manager.dart' as prefix6;
import 'metadata_schema_resolver.dart' as prefix5;
import 'orm.dart' as prefix11;
import 'package:forge_core/forge_core.dart' as prefix1;
import 'package:forge_orm/src/orm_module.dart' as prefix20;

abstract class AbstractOrmBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    // Register modules
    builder.registerSingleton<prefix20.OrmModule>((i) => prefix20.OrmModule());
    builder.registerSingleton<prefix20.ConnectionFactory>((i) => i<prefix20.OrmModule>().createConnectionFactory(i<prefix1.Injector>()));
    builder.registerSingleton<prefix7.Database>((i) => i<prefix20.OrmModule>().createDatabase(i<prefix20.ConnectionFactory>()));
    builder.registerFactory<prefix5.MetadataSchemaResolver>((i) => i<prefix20.OrmModule>().createSchemaResolver(i<prefix1.MetadataRegistry>(), i<prefix1.Injector>()));
    builder.registerFactory<prefix6.EntityManager>((i) => i<prefix20.OrmModule>().createEntityManager(i<prefix7.Database>(), i<prefix1.Serializer>(), i<prefix5.MetadataSchemaResolver>()));
    builder.registerSingleton<prefix11.Orm>((i) => i<prefix20.OrmModule>().createOrm(i<prefix7.Database>(), i<prefix1.Serializer>(), i<prefix5.MetadataSchemaResolver>()));
  }

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {}

  @override
  Future<void> boot(Injector i) async {
    // Execute boot methods
    await i<prefix20.OrmModule>().setupDatabaseConnection(i<prefix7.Database>());
  }
}
