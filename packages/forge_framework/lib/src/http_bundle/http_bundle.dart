import '../../forge_framework.dart';
import 'http/http_kernel.dart';
import 'runner/http_runner.dart';
import 'subscriber/exception_subscriber.dart';

export 'package:shelf/shelf.dart';
export 'package:shelf_router/shelf_router.dart' hide Route;

export 'annotation.dart';
export 'config/http_config.dart';
export 'events.dart';
export 'exception/http_exception.dart';
export 'http/request_context.dart';
export 'http/response.dart';
export 'http/argument_resolver.dart';

class HttpBundle extends Bundle {
  @override
  Future<void> build(
    InjectorBuilder builder,
    String env,
  ) async {
    builder.registerSingleton<ExceptionSubscriber>(
      (i) => ExceptionSubscriber(),
    );

    builder.registerSingleton<Router>(
      (i) => Router(),
    );

    builder.registerFactory<ValueResolver>(
      (i) => RequestResolver(),
      name: 'http.value_resolver.request',
    );

    builder.registerFactory<ValueResolver>(
      (i) => PathParametersResolver(),
      name: 'http.value_resolver.path_parameters',
    );

    builder.registerFactory<ValueResolver>(
      (i) => QueryParametersResolver(),
      name: 'http.value_resolver.query_parameters',
    );

    builder.registerFactory<ValueResolver>(
      (i) => InjectorResolver(i),
      name: 'http.value_resolver.injector',
    );

    builder.registerFactory<ValueResolver>(
      (i) => MapRequestPayloadResolver(i(), i(), i()),
      name: 'http.value_resolver.map_request_payload',
    );

    builder.registerFactory<ValueResolver>(
      (i) => MapRequestQueryResolver(i(), i(), i()),
      name: 'http.value_resolver.map_request_query',
    );

    builder.registerSingleton<ArgumentResolver>((i) {
      return ArgumentResolver(i.all<ValueResolver>());
    });

    builder.registerSingleton<HttpKernel>((i) {
      return HttpKernel(
        router: i<Router>(),
        eventBus: i<EventBus>(),
      );
    });

    builder.registerSingleton<HttpRunner>((i) {
      return HttpRunner(
        httpKernel: i<HttpKernel>(),
        eventBus: i<EventBus>(),
        config: (i.contains<HttpConfig>()) ? i<HttpConfig>() : null,
      );
    });
  }

  @override
  Future<void> boot(
    Injector container,
  ) async {
    final router = container.get<Router>();
    final argumentResolver = container.get<ArgumentResolver>();
    final metadataRegistry = container.get<MetadataRegistry>();

    _registerControllers(
      metadataRegistry,
      router,
      argumentResolver,
      container,
    );

    router.all('/<ignored|.*>', (Request request) {
      throw HttpException.notFound(
        'Route not found: ${request.method} ${request.requestedUri.path}',
      );
    });
  }

  void _registerControllers(
    MetadataRegistry metadataRegistry,
    Router router,
    ArgumentResolver argumentResolver,
    Injector container,
  ) {
    final controllers = metadataRegistry.classesAnnotatedWith<Controller>();

    for (final controllerMeta in controllers) {
      final controllerAnnotation = controllerMeta
          .firstAnnotationOf<Controller>();
      final prefix = controllerAnnotation?.prefix ?? '';

      if (!controllerMeta.hasMappedMethods) continue;

      for (final methodMeta in controllerMeta.methods!) {
        if (!methodMeta.hasAnnotation<Route>()) continue;

        final routeAnnotation = methodMeta.firstAnnotationOf<Route>()!;

        final fullPath = _buildPath(prefix, routeAnnotation.path);

        final handler = _createHandler(
          argumentResolver,
          controllerMeta,
          methodMeta,
          container,
        );

        for (final httpMethod in routeAnnotation.method) {
          router.add(httpMethod, fullPath, handler);
        }
      }
    }
  }

  Function _createHandler(
    ArgumentResolver argumentResolver,
    ClassMetadata controllerMeta,
    MethodMetadata methodMeta,
    Injector injector,
  ) {
    return (Request request) async {
      final instance = controllerMeta.typeMetadata.captureGeneric(
        <T>() => injector.get<T>(),
      );

      final method = methodMeta.getMethod(instance);

      final arguments = await argumentResolver.resolveArgumentsFor(
        request,
        methodMeta,
      );

      final response = await Function.apply(
        method,
        arguments.positional,
        arguments.named,
      );

      return _handleResponse(response, injector, methodMeta);
    };
  }

  Future<Response> _handleResponse(
    dynamic response,
    Injector injector,
    MethodMetadata methodMeta,
  ) async {
    if (response is Future<Response>) {
      return await response;
    }

    if (response is Response) {
      return response;
    }

    if (methodMeta.typeMetadata.isType<Future>()) {
      return methodMeta.typeMetadata.typeArguments.first.captureGeneric(
        <T>() async {
          final resolved = await response;
          return JsonResponse(
            injector.get<Serializer>().normalize<T>(resolved),
          );
        },
      );
    }

    return methodMeta.typeMetadata.captureGeneric(
      <T>() => JsonResponse(injector.get<Serializer>().normalize<T>(response)),
    );
  }

  String _buildPath(String prefix, String path) {
    if (prefix.isEmpty) return path;

    final cleanPrefix = prefix.endsWith('/')
        ? prefix.substring(0, prefix.length - 1)
        : prefix;

    final cleanPath = path.startsWith('/') ? path : '/$path';

    return '$cleanPrefix$cleanPath';
  }
}
