// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000
// ignore_for_file: prefer_relative_imports, depend_on_referenced_packages, camel_case_types

import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

import 'config/orm_config.dart' as prefix4;
import 'controller/users_controller.dart' as prefix2;
import 'dart:async' as prefix9;
import 'entity/user.dart' as prefix5;
import 'package:forge_framework/forge_framework.dart' as prefix0;
import 'package:forge_orm/forge_orm.dart' as prefix1;
import 'subscribers/exception_subscriber.dart' as prefix3;

abstract class AbstractAppBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    // Register services
    builder.registerSingleton<prefix2.UsersController>((i) => prefix2.UsersController(i<prefix1.Orm>()));
    builder.registerFactory<prefix3.ExceptionSubscriber>((i) => prefix3.ExceptionSubscriber());
    // Register modules
    builder.registerSingleton<prefix4.OrmConfig>((i) => prefix4.OrmConfig());
    builder.registerFactory<prefix1.DatabaseConfig>((i) => i<prefix4.OrmConfig>().databaseConfig);
  }

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {
    metaBuilder.registerClass<prefix5.User>(
      meta.clazz(
        meta.type<prefix5.User>(),
        const <Object>[prefix0.Mappable(), prefix1.Entity('users')],
        [meta.constructor(() => prefix5.User.new, [], 'new', const [])],
        null, // methods
        [
          meta.getter(meta.type<int>([], true), 'id', (instance) => instance.id, const <Object>[prefix1.Column.id()]),
          meta.getter(meta.type<String>([], true), 'name', (instance) => instance.name, const <Object>[prefix1.Column.varchar()]),
          meta.getter(meta.type<String>([], true), 'email', (instance) => instance.email, const <Object>[prefix1.Column.varchar(unique: true)]),
        ],
        [
          meta.setter(meta.type<int>([], true), 'id', (instance, value) => instance.id = value, const <Object>[prefix1.Column.id()]),
          meta.setter(meta.type<String>([], true), 'name', (instance, value) => instance.name = value, const <Object>[prefix1.Column.varchar()]),
          meta.setter(meta.type<String>([], true), 'email', (instance, value) => instance.email = value, const <Object>[prefix1.Column.varchar(unique: true)]),
        ],
        (target, handler, metadata) => _prefix5UserProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix2.UsersController>(
      meta.clazz(
        meta.type<prefix2.UsersController>(),
        const <Object>[prefix0.Controller(prefix: '/users')],
        [
          meta.constructor(() => prefix2.UsersController.new, [meta.parameter(meta.type<prefix1.Orm>(), 'orm', 0, false, false, null, const [])], 'new', const []),
        ],
        [
          meta.method(
            meta.type<prefix9.Future<List<prefix5.User>>>([
              meta.type<List<prefix5.User>>([meta.type<prefix5.User>()]),
            ]),
            'getUsers',
            (instance) => instance.getUsers,
            [meta.parameter(meta.type<prefix0.Request>(), 'request', 0, false, false, null, const [])],
            const <Object>[prefix0.Route.get()],
          ),
          meta.method(
            meta.type<prefix9.Future<prefix5.User>>([meta.type<prefix5.User>()]),
            'createUser',
            (instance) => instance.createUser,
            [
              meta.parameter(meta.type<prefix2.CreateUserRequest>(), 'request', 0, false, false, null, const <Object>[prefix0.MapRequestQuery()]),
              meta.parameter(meta.type<prefix1.EntityManager>(), 'em', 1, false, false, null, const <Object>[prefix0.Inject()]),
            ],
            const <Object>[prefix0.Route.get('/create')],
          ),
        ],
        [meta.getter(meta.type<prefix1.Orm>(), 'orm', (instance) => instance.orm, const [])],
        null, // setters
        null, // createProxy
      ),
    );

    metaBuilder.registerClass<prefix2.CreateUserRequest>(
      meta.clazz(
        meta.type<prefix2.CreateUserRequest>(),
        const <Object>[prefix0.Mappable()],
        [
          meta.constructor(() => prefix2.CreateUserRequest.new, [meta.parameter(meta.type<String>(), 'name', 0, false, false, null, const []), meta.parameter(meta.type<String>(), 'email', 1, false, false, null, const [])], 'new', const []),
        ],
        null, // methods
        [
          meta.getter(meta.type<String>(), 'name', (instance) => instance.name, const <Object>[prefix0.NotBlank()]),
          meta.getter(meta.type<String>(), 'email', (instance) => instance.email, const <Object>[prefix0.NotBlank(), prefix0.Email()]),
        ],
        null, // setters
        null, // createProxy
      ),
    );
  }

  @override
  Future<void> boot(Injector i) async {
    // Execute boot methods
    await i<prefix4.OrmConfig>().initializeOrm(i<prefix1.Database>(), i<prefix1.MetadataSchemaResolver>(), i<prefix0.Logger>());
  }
}

class _prefix5UserProxy extends AbstractProxy implements prefix5.User {
  _prefix5UserProxy._(super.target, super.handler, super.metadata);
}
