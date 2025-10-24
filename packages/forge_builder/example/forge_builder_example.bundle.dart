// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000

import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

import 'dart:collection' as prefix1;
import 'dart:io' as prefix0;
import 'dart:math' as prefix2;
import 'foo.dart' as prefix5;
import 'package:forge_core/forge_core.dart' as prefix4;

abstract class AbstractExampleBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    // Register services
    builder.registerFactory<prefix5.Car>((i) => prefix5.Car());
    builder.registerFactory<prefix5.Truck>((i) => prefix5.Truck());
    builder.registerFactory<prefix5.Bar>((i) => prefix5.Bar(i<prefix5.Car>()));
    builder.registerSingleton<prefix5.UserController>((i) => prefix5.UserController());
    // Register modules
    builder.registerSingleton<prefix5.SerializerModule>((i) => prefix5.SerializerModule());
    builder.registerEagerSingleton<prefix4.JsonEncoder>((i) => i<prefix5.SerializerModule>().errorFuture(i<String>()));
    builder.registerSingleton<prefix4.Serializer>((i) => i<prefix5.SerializerModule>().serializer);
    builder.registerAsyncSingleton<prefix1.UnmodifiableListView<List<List<int>>>>((i) => i<prefix5.SerializerModule>().readOnlyList);
    builder.registerSingleton<prefix0.HttpClient>((i) => i<prefix5.SerializerModule>().httpClient);
    builder.registerSingleton<List<prefix2.Random>>((i) => i<prefix5.SerializerModule>().randomGenerators);
  }

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {
    metaBuilder.registerClass<prefix5.UserController>(
      meta.clazz(
        meta.type<prefix5.UserController>(),
        const <Object>[prefix5.Controller()],
        null, // constructors
        [
          meta.method(meta.type<void>(), 'getUser', (instance) => instance.getUser, [meta.parameter(meta.type<prefix0.HttpRequest>([], true), 'request', 0, false, false)], const <Object>[prefix5.Route('/')]),
          meta.method(
            meta.type<void>(),
            'anotherMethod',
            (instance) => instance.anotherMethod,
            null, // parameters
            const [],
          ),
        ],
        null, // getters
        null, // setters
      ),
    );
  }

  @override
  Future<void> boot(Injector i) async {
    // Execute boot methods
    await i<prefix5.SerializerModule>().computedValue;
  }
}
