// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000
// ignore_for_file: prefer_relative_imports, depend_on_referenced_packages, camel_case_types

import 'package:forge_core/forge_core.dart';

import 'package:forge_core/forge_core.dart' as prefix1;
import 'package:forge_orm/src/database.dart' as prefix7;
import 'package:forge_orm/src/entity_manager/entity_manager.dart' as prefix9;
import 'package:forge_orm/src/metadata_schema_resolver.dart' as prefix8;
import 'package:forge_orm/src/orm.dart' as prefix10;
import 'package:forge_orm/src/orm_module.dart' as prefix6;

abstract class AbstractOrmBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    // Register modules
    builder.registerSingleton<prefix6.OrmModule>((i) => prefix6.OrmModule());
    builder.registerSingleton<prefix6.ConnectionFactory>((i) => i<prefix6.OrmModule>().createConnectionFactory(i<prefix1.Injector>()));
    builder.registerSingleton<prefix7.Database>((i) => i<prefix6.OrmModule>().createDatabase(i<prefix6.ConnectionFactory>()));
    builder.registerFactory<prefix8.MetadataSchemaResolver>((i) => i<prefix6.OrmModule>().createSchemaResolver(i<prefix1.MetadataRegistry>(), i<prefix1.Injector>()));
    builder.registerFactory<prefix9.EntityManager>((i) => i<prefix6.OrmModule>().createEntityManager(i<prefix10.Orm>()));
    builder.registerFactory<prefix10.Orm>((i) => i<prefix6.OrmModule>().createOrm(i<prefix7.Database>(), i<prefix1.Serializer>(), i<prefix8.MetadataSchemaResolver>()));
  }

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {}

  @override
  Future<void> boot(Injector i) async {
    // Execute boot methods
    await i<prefix6.OrmModule>().setupDatabaseConnection(i<prefix7.Database>());
  }
}
