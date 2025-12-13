// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000
// ignore_for_file: prefer_relative_imports, depend_on_referenced_packages, camel_case_types

import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

import 'package:forge_core/forge_core.dart' as prefix1;
import 'package:forge_orm/forge_orm.dart' as prefix4;
import 'package:forge_orm/src/database_manger.dart' as prefix7;

abstract class AbstractOrmBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    // Register modules
    builder.registerSingleton<prefix4.OrmModule>((i) => prefix4.OrmModule());
    builder.registerSingleton<prefix7.DatabaseManager>((i) => i<prefix4.OrmModule>().createDatabase(i<prefix1.Injector>()));
    builder.registerFactory<prefix4.MetadataSchemaResolver>((i) => i<prefix4.OrmModule>().createSchemaResolver(i<prefix1.MetadataRegistry>(), i<prefix1.Injector>()));
    builder.registerFactory<prefix4.EntityManager>((i) => i<prefix4.OrmModule>().createEntityManager(i<prefix4.Orm>()));
    builder.registerFactory<prefix4.Orm>((i) => i<prefix4.OrmModule>().createOrm(i<prefix7.DatabaseManager>(), i<prefix1.Serializer>(), i<prefix4.MetadataSchemaResolver>()));
  }

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {}

  @override
  Future<void> boot(Injector i) async {
    // Execute boot methods
    await i<prefix4.OrmModule>().setupDatabaseConnection(i<prefix7.DatabaseManager>());
  }
}
