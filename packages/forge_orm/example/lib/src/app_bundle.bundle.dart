// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000
// ignore_for_file: prefer_relative_imports, depend_on_referenced_packages, camel_case_types

import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

import 'config/orm_config.dart' as prefix5;
import 'controller/users_controller.dart' as prefix3;
import 'dart:async' as prefix10;
import 'entity/user.dart' as prefix6;
import 'package:forge_framework/forge_framework.dart' as prefix0;
import 'package:forge_orm/forge_orm.dart' as prefix1;
import 'subscribers/exception_subscriber.dart' as prefix4;

abstract class AbstractAppBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    // Register services
    builder.registerSingleton<prefix3.UsersController>((i) => prefix3.UsersController(i<prefix1.Orm>()));
    builder.registerFactory<prefix4.ExceptionSubscriber>((i) => prefix4.ExceptionSubscriber());
    // Register modules
    builder.registerSingleton<prefix5.OrmConfig>((i) => prefix5.OrmConfig());
    builder.registerFactory<prefix1.DatabaseConfig>((i) => i<prefix5.OrmConfig>().databaseConfig);
  }

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {
    metaBuilder.registerClass<prefix6.User>(
      meta.clazz(
        meta.type<prefix6.User>(),
        const <Object>[prefix0.Mappable(), prefix1.Entity('users')],
        [meta.constructor(() => prefix6.User.new, [], 'new', const [])],
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
        (target, handler, metadata) => _prefix6UserProxy._(target, handler, metadata),
      ),
    );

    metaBuilder.registerClass<prefix3.UsersController>(
      meta.clazz(
        meta.type<prefix3.UsersController>(),
        const <Object>[prefix0.Controller(prefix: '/users')],
        [
          meta.constructor(() => prefix3.UsersController.new, [meta.parameter(meta.type<prefix1.Orm>(), 'orm', 0, false, false, null, const [])], 'new', const []),
        ],
        [
          meta.method(
            meta.type<prefix10.Future<List<prefix6.User>>>([
              meta.type<List<prefix6.User>>([meta.type<prefix6.User>()]),
            ]),
            'getUsers',
            (instance) => instance.getUsers,
            [meta.parameter(meta.type<prefix0.Request>(), 'request', 0, false, false, null, const [])],
            const <Object>[prefix0.Route.get()],
          ),
          meta.method(
            meta.type<prefix10.Future<prefix6.User>>([meta.type<prefix6.User>()]),
            'createUser',
            (instance) => instance.createUser,
            [
              meta.parameter(meta.type<prefix3.CreateUserRequest>(), 'request', 0, false, false, null, const <Object>[prefix0.MapRequestQuery()]),
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

    metaBuilder.registerClass<prefix3.CreateUserRequest>(
      meta.clazz(
        meta.type<prefix3.CreateUserRequest>(),
        const <Object>[prefix0.Mappable()],
        [
          meta.constructor(() => prefix3.CreateUserRequest.new, [meta.parameter(meta.type<String>(), 'name', 0, false, false, null, const []), meta.parameter(meta.type<String>(), 'email', 1, false, false, null, const [])], 'new', const []),
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
    await i<prefix5.OrmConfig>().initializeOrm(i<prefix1.Database>(), i<prefix1.MetadataSchemaResolver>(), i<prefix0.Logger>());
  }
}

class _prefix6UserProxy extends AbstractProxy implements prefix6.User {
  _prefix6UserProxy._(super.target, super.handler, super.metadata);
}
