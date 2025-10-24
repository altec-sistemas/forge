import '../../../forge.dart';
import '../exception/argument_resolver_exception.dart';

/// Wrapper for resolved argument values.
///
/// Distinguishes between "value resolved" (even if null) and "not resolved".
class ArgumentValue {
  final dynamic value;

  const ArgumentValue(this.value);
}

/// Result of argument resolution.
///
/// Contains separated positional and named arguments for use with Function.apply().
class ArgumentsResult {
  /// Positional arguments
  final List<dynamic> positional;

  /// Named arguments
  final Map<Symbol, dynamic> named;

  ArgumentsResult({
    required this.positional,
    required this.named,
  });

  /// Creates an empty result.
  factory ArgumentsResult.empty() {
    return ArgumentsResult(
      positional: [],
      named: {},
    );
  }

  /// Checks if there are any arguments.
  bool get isEmpty => positional.isEmpty && named.isEmpty;

  /// Checks if there are any arguments.
  bool get isNotEmpty => !isEmpty;
}

/// Main argument resolution manager for handlers.
///
/// Responsible for coordinating multiple [ValueResolver]s and resolving
/// all arguments needed to invoke a handler.
///
/// ## Usage
///
/// ```dart
/// final resolver = ArgumentResolver();
/// resolver.addResolver(QueryParametersResolver());
/// resolver.addResolver(InjectorResolver(injector));
///
/// final result = await resolver.resolveArgumentsFor(request, myHandler);
/// Function.apply(myHandler, result.positional, result.named);
/// ```
abstract class ArgumentResolver {
  /// Creates a new ArgumentResolver instance.
  factory ArgumentResolver(List<ValueResolver> resolvers) =>
      _ArgumentResolverImpl(resolvers);

  /// Resolves all arguments needed to invoke the handler.
  ///
  /// Returns [ArgumentsResult] with positional and named arguments.
  Future<ArgumentsResult> resolveArgumentsFor(
    Request request,
    MethodMetadata handler,
  );
}

abstract class ValueResolver {
  /// Resolves a value of type [T] based on the request and metadata.
  ///
  /// Returns [ArgumentValue] wrapping the resolved value if this resolver can handle it,
  /// or returns null if it cannot (so the next resolver can try).
  Future<ArgumentValue?> resolve(Request request, ParameterMetadata meta);

  /// Resolver priority (higher = processed first).
  int get priority => 0;
}

class _ArgumentResolverImpl implements ArgumentResolver {
  final List<ValueResolver> _resolvers = [];

  _ArgumentResolverImpl(List<ValueResolver> resolvers) {
    resolvers.sort((a, b) => b.priority.compareTo(a.priority));
    _resolvers.addAll(resolvers);
  }

  @override
  Future<ArgumentsResult> resolveArgumentsFor(
    Request request,
    MethodMetadata handler,
  ) async {
    final positionalArgs = <dynamic>[];
    final namedArgs = <Symbol, dynamic>{};

    if (!handler.hasMappedParameters) {
      throw Exception(
        'No argument mapping found for handler',
      );
    }

    for (final meta in handler.parameters!) {
      final value = await _resolveArgument(request, meta);

      if (meta.isNamed) {
        namedArgs[Symbol(meta.name)] = value;
      } else {
        positionalArgs.add(value);
      }
    }

    return ArgumentsResult(
      positional: positionalArgs,
      named: namedArgs,
    );
  }

  Future<dynamic> _resolveArgument(
    Request request,
    ParameterMetadata meta,
  ) async {
    for (final resolver in _resolvers) {
      final argumentValue = await resolver.resolve(request, meta);

      if (argumentValue != null) {
        return argumentValue.value;
      }

      continue;
    }

    if (meta.isOptional) {
      return meta.defaultValue;
    }

    throw ArgumentResolutionException(
      'Could not resolve required argument: ${meta.name}',
      argumentName: meta.name,
    );
  }
}

/// Resolver for query string parameters.
///
/// Extracts and converts values from URL query parameters.
/// Supports basic type conversions: String, int, double, bool, DateTime.
class QueryParametersResolver implements ValueResolver {
  @override
  int get priority => 100;

  @override
  Future<ArgumentValue?> resolve(
    Request request,
    ParameterMetadata meta,
  ) async {
    if (!meta.hasAnnotation<QueryParam>()) {
      return null;
    }

    final annotation = meta.firstAnnotationOf<QueryParam>();
    final paramName = annotation?.name ?? meta.name;

    final value = request.url.queryParameters[paramName];

    if (value == null && meta.isNullable) {
      return ArgumentValue(null);
    }

    if (value != null) {
      final converted = meta.typeMetadata.captureGeneric(
        <T>() => _convertValue<T>(value),
      );
      if (converted != null) {
        return ArgumentValue(converted);
      }
    }

    return null;
  }
}

/// Resolver for dependency injection container dependencies.
///
/// Injects dependencies from the DI container into handler parameters.
/// Can inject both typed dependencies and named instances.
class InjectorResolver implements ValueResolver {
  final Injector injector;

  InjectorResolver(this.injector);

  @override
  int get priority => 50;

  @override
  Future<ArgumentValue?> resolve(
    Request request,
    ParameterMetadata meta,
  ) async {
    final inject = meta.firstAnnotationOf<Inject>();

    if (inject == null) {
      return null;
    }

    final isRegistered = meta.typeMetadata.captureGeneric(<T>() {
      return injector.contains<T>(inject.name);
    });

    if (!isRegistered) {
      return null;
    }

    final annotation = meta.firstAnnotationOf<Inject>();
    final name = annotation?.name;

    return ArgumentValue(
      meta.typeMetadata.captureGeneric(
        <T>() => injector.get<T>(name),
      ),
    );
  }
}

/// Resolver that injects the original Request.
///
/// Automatically injects the Shelf Request object when a handler
/// parameter is typed as Request.
class RequestResolver implements ValueResolver {
  @override
  int get priority => 200;

  @override
  Future<ArgumentValue?> resolve(
    Request request,
    ParameterMetadata meta,
  ) async {
    if (meta.typeMetadata.type == Request) {
      return ArgumentValue(request);
    }

    return null;
  }
}

/// Resolver for route path parameters.
///
/// Extracts and converts values from route path parameters (e.g., /users/:id).
/// Does not require any annotation - parameters are resolved by their name.
/// Supports basic type conversions: String, int, double, bool, DateTime.
///
/// Example:
/// ```dart
/// // Route: /users/:id
/// Future<Response> getUser(String id) async { ... }
///
/// // Route: /posts/:postId/comments/:commentId
/// Future<Response> getComment(int postId, int commentId) async { ... }
/// ```
class PathParametersResolver implements ValueResolver {
  @override
  int get priority => 150;

  @override
  Future<ArgumentValue?> resolve(
    Request request,
    ParameterMetadata meta,
  ) async {
    final params = request.params;

    if (!params.containsKey(meta.name)) {
      return null;
    }

    final value = params[meta.name];

    if (value == null && meta.isNullable) {
      return ArgumentValue(null);
    }

    if (value != null) {
      return ArgumentValue(
        meta.typeMetadata.captureGeneric(<S>() => _convertValue<S>(value)),
      );
    }

    throw ArgumentResolutionException(
      'Could not convert path parameter "${meta.name}" to type ${meta.typeMetadata.type}',
      argumentName: meta.name,
    );
  }
}

T? _convertValue<T>(String value) {
  if (T == String) {
    return value as T;
  }

  if (T == int) {
    return int.tryParse(value) as T?;
  }

  if (T == double) {
    return double.tryParse(value) as T?;
  }

  if (T == bool) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true as T;
    if (lower == 'false' || lower == '0') return false as T;
    return null;
  }

  if (T == DateTime) {
    return DateTime.tryParse(value) as T?;
  }

  throw ArgumentResolutionException(
    'Unsupported type conversion for parameter: $T',
  );
}

class MapRequestPayloadResolver implements ValueResolver {
  final Serializer _serializer;
  final Validator _validator;
  final ConstraintExtractor _constraintExtractor;

  MapRequestPayloadResolver(
    this._serializer,
    this._validator,
    this._constraintExtractor,
  );

  @override
  int get priority => 75;

  @override
  Future<ArgumentValue?> resolve(
    Request request,
    ParameterMetadata meta,
  ) async {
    if (!meta.hasAnnotation<MapRequestPayload>()) {
      return null;
    }

    final contentType = request.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) {
      throw ArgumentResolutionException(
        'Unsupported content type for MapRequestPayload: $contentType',
        argumentName: meta.name,
      );
    }

    final annotation = meta.firstAnnotationOf<MapRequestPayload>();

    final body = await request.readAsString();
    final decoded = _serializer.decode(body, 'json');

    if (annotation!.validade) {
      final constraint = meta.typeMetadata.captureGeneric(
        <T>() => _constraintExtractor.extractConstraint<T>(),
      );

      if (constraint != null) {
        _validator.validateOrThrow(decoded, constraint);
      }
    }

    final denormalized = meta.typeMetadata.captureGeneric(
      <T>() => _serializer.denormalize<T>(
        decoded,
      ),
    );
    return ArgumentValue(denormalized);
  }
}

class MapRequestQueryResolver implements ValueResolver {
  final Serializer _serializer;
  final Validator _validator;
  final ConstraintExtractor _constraintExtractor;

  MapRequestQueryResolver(
    this._serializer,
    this._validator,
    this._constraintExtractor,
  );

  @override
  int get priority => 80;

  @override
  Future<ArgumentValue?> resolve(
    Request request,
    ParameterMetadata meta,
  ) async {
    if (!meta.hasAnnotation<MapRequestQuery>()) {
      return null;
    }

    final queryParams = request.url.queryParameters;

    if (meta.firstAnnotationOf<MapRequestQuery>()?.validade == true) {
      final constraint = meta.typeMetadata.captureGeneric(
        <T>() => _constraintExtractor.extractConstraint<T>(),
      );

      if (constraint != null) {
        _validator.validateOrThrow(queryParams, constraint);
      }
    }

    final decoded = meta.typeMetadata.captureGeneric(
      <T>() => _serializer.denormalize<T>(
        queryParams,
      ),
    );

    return ArgumentValue(decoded);
  }
}
