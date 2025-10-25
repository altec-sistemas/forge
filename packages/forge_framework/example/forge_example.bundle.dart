// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=10000

import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

import 'controller/home_controller.dart' as prefix1;
import 'dart:async' as prefix2;
import 'package:forge_framework/forge_framework.dart' as prefix0;
import 'package:forge_core/forge_core.dart' as prefix0;

abstract class AbstractExampleBundle implements Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    // Register services
    builder.registerSingleton<prefix1.HomeController>(
      (i) => prefix1.HomeController(i<prefix0.Serializer>()),
      onCreate: (instance, i) {
        instance.setValidador(i<prefix0.Validator>());
      },
    );
    builder.registerFactory<prefix1.SomeListener>((i) => prefix1.SomeListener());
    builder.registerFactory<prefix1.SomeNamedService>((i) => prefix1.SomeNamedService());
    builder.registerFactory<prefix1.OtherService>((i) => prefix1.OtherService(i<prefix1.SomeNamedService>()));
    builder.registerFactory<prefix1.CreditCardPayment>((i) => prefix1.CreditCardPayment());
    builder.registerFactory<prefix1.PaypalPayment>((i) => prefix1.PaypalPayment());
    builder.registerFactory<prefix1.PaymentService>((i) => prefix1.PaymentService(i('paypal')));
    // Register modules
    builder.registerSingleton<prefix1.ValidationModule>((i) => prefix1.ValidationModule());
    builder.registerSingleton<prefix0.ValidationMessageProvider>((i) => i<prefix1.ValidationModule>().messageProvider);
  }

  @override
  Future<void> buildMetadata(MetadataRegistryBuilder metaBuilder, String env) async {
    metaBuilder.registerClass<prefix1.HomeController>(
      meta.clazz(
        meta.type<prefix1.HomeController>(),
        const <Object>[prefix0.Controller()],
        [
          meta.constructor(() => prefix1.HomeController.new, [meta.parameter(meta.type<prefix0.Serializer>(), '_serializer', 0, false, false, null, const [])], 'new', const []),
        ],
        [
          meta.method(meta.type<void>(), 'setValidador', (instance) => instance.setValidador, [meta.parameter(meta.type<prefix0.Validator>(), 'validator', 0, false, false, null, const [])], const <Object>[prefix0.Required()]),
          meta.method(
            meta.type<prefix2.Future<List<prefix1.User>>>([
              meta.type<List<prefix1.User>>([meta.type<prefix1.User>()]),
            ]),
            'users',
            (instance) => instance.users,
            [meta.parameter(meta.type<prefix0.Request>(), 'request', 0, false, false, null, const [])],
            const <Object>[prefix0.Route.get('/')],
          ),
          meta.method(
            meta.type<prefix2.Future<prefix1.User>>([meta.type<prefix1.User>()]),
            'createUser',
            (instance) => instance.createUser,
            [
              meta.parameter(meta.type<prefix1.CreateUserRequest>(), 'request', 0, false, false, null, const <Object>[prefix0.MapRequestQuery()]),
            ],
            const <Object>[prefix0.Route.get('/users/create')],
          ),
          meta.method(
            meta.type<prefix0.Response>(),
            'index',
            (instance) => instance.index,
            [
              meta.parameter(meta.type<prefix0.Request>(), 'request', 0, false, false, null, const []),
              meta.parameter(meta.type<String>(), 'name', 1, true, false, 'Bob', const <Object>[prefix0.QueryParam()]),
            ],
            const <Object>[prefix0.Route.get('/hello')],
          ),
          meta.method(
            meta.type<prefix0.JsonResponse>(),
            'preSerialize',
            (instance) => instance.preSerialize,
            null, // parameters
            const <Object>[prefix0.Route.get('/pre-serialize')],
          ),
        ],
        [
          meta.getter(meta.type<List<prefix1.User>>([meta.type<prefix1.User>()]), '_users', (instance) => instance._users, const []),
          meta.getter(meta.type<prefix0.Serializer>(), '_serializer', (instance) => instance._serializer, const []),
          meta.getter(meta.type<prefix0.Validator>(), '_validator', (instance) => instance._validator, const []),
        ],
        [meta.setter(meta.type<prefix0.Validator>(), '_validator', (instance, value) => instance._validator = value, const [])],
      ),
    );

    metaBuilder.registerClass<prefix1.User>(
      meta.clazz(
        meta.type<prefix1.User>(),
        const <Object>[prefix0.Mappable()],
        [
          meta.constructor(() => prefix1.User.new, [meta.parameter(meta.type<String>(), 'name', 0, false, false, null, const []), meta.parameter(meta.type<String>(), 'email', 1, false, false, null, const []), meta.parameter(meta.type<String>(), 'password', 2, false, false, null, const [])], 'new', const []),
        ],
        null, // methods
        [
          meta.getter(meta.type<String>(), 'name', (instance) => instance.name, const <Object>[prefix0.Property(name: 'user_name')]),
          meta.getter(meta.type<String>(), 'email', (instance) => instance.email, const []),
          meta.getter(meta.type<String>(), 'password', (instance) => instance.password, const <Object>[prefix0.Ignore()]),
        ],
        null, // setters
      ),
    );

    metaBuilder.registerClass<prefix1.CreateUserRequest>(
      meta.clazz(
        meta.type<prefix1.CreateUserRequest>(),
        const <Object>[prefix0.Mappable()],
        [
          meta.constructor(() => prefix1.CreateUserRequest.new, [meta.parameter(meta.type<String>(), 'name', 0, false, false, null, const []), meta.parameter(meta.type<String>(), 'email', 1, false, false, null, const []), meta.parameter(meta.type<String>(), 'password', 2, false, false, null, const [])], 'new', const []),
        ],
        null, // methods
        [
          meta.getter(meta.type<String>(), 'name', (instance) => instance.name, const <Object>[prefix0.NotBlank(), prefix0.Length(min: 3)]),
          meta.getter(meta.type<String>(), 'email', (instance) => instance.email, const <Object>[prefix0.NotBlank(), prefix0.Email()]),
          meta.getter(meta.type<String>(), 'password', (instance) => instance.password, const <Object>[prefix0.NotBlank()]),
        ],
        null, // setters
      ),
    );

    metaBuilder.registerClass<prefix1.SomeListener>(
      meta.clazz(
        meta.type<prefix1.SomeListener>(),
        const <Object>[prefix0.Service()],
        null, // constructors
        [
          meta.method(meta.type<void>(), 'onRequest', (instance) => instance.onRequest, [meta.parameter(meta.type<prefix0.HttpKernelRequestEvent>(), 'event', 0, false, false, null, const [])], const <Object>[prefix0.AsEventListener()]),
          meta.method(meta.type<void>(), 'onHttpKernelException', (instance) => instance.onHttpKernelException, [meta.parameter(meta.type<prefix0.HttpKernelExceptionEvent>(), 'event', 0, false, false, null, const [])], const <Object>[prefix0.AsEventListener()]),
          meta.method(meta.type<void>(), 'onHttpServerStarted', (instance) => instance.onHttpServerStarted, [meta.parameter(meta.type<prefix0.HttpRunnerStarted>(), 'event', 0, false, false, null, const [])], const <Object>[prefix0.AsEventListener()]),
        ],
        null, // getters
        null, // setters
      ),
    );
  }

  @override
  Future<void> boot(Injector i) async {
    // No boot methods to execute
  }
}
