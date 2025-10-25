import '../../forge_core.dart';

typedef Factory<T> = T Function(Injector i);
typedef AsyncFactory<T> = Future<T> Function(Injector i);
typedef PostCreate<T> = void Function(T instance, Injector i);
typedef AsyncPostCreate<T> = Future<void> Function(T instance, Injector i);

/// Defines a modular component that can register services and perform initialization.
///
/// Bundles are the primary way to organize and encapsulate related functionality
/// in the application. They have two phases:
/// - **Build phase**: Register services in the container
/// - **Boot phase**: Perform initialization logic after the container is built
abstract class Bundle {
  /// Registers services, factories, and configurations in the container builder.
  ///
  /// This is called during the kernel's build phase, before the container
  /// becomes immutable.
  Future<void> build(InjectorBuilder builder, String env);

  Future<void> buildMetadata(
    MetadataRegistryBuilder metaBuilder,
    String env,
  ) async {}

  /// Performs initialization logic after the container is built.
  ///
  /// This is called during the kernel's boot phase, when all services
  /// are available for resolution.
  Future<void> boot(Injector i);
}

/// Defines the interface for building and registering services within a dependency container.
abstract class InjectorBuilder {
  factory InjectorBuilder() => _InjectorBuilderImpl();

  /// Registers an existing instance directly into the container.
  ///
  /// Typically used for pre-created singletons or global objects
  /// that should not be instantiated by the container itself.
  void registerInstance<T>(T instance, {String? name});

  /// Registers a factory that creates a **new instance** of [T]
  /// every time it is resolved.
  ///
  /// Optionally, an [onCreate] callback can be provided, which is called
  /// immediately after each instance is created.
  void registerFactory<T>(
    Factory<T> factory, {
    PostCreate<T>? onCreate,
    String? name,
  });

  /// Registers a factory that creates a **shared singleton instance** of [T].
  ///
  /// The instance is lazily created the first time it is requested.
  /// Optionally, an [onCreate] callback can be provided, which is called
  /// once after the singleton instance is created.
  void registerSingleton<T>(
    Factory<T> factory, {
    PostCreate<T>? onCreate,
    String? name,
  });

  /// Registers an async factory that creates a **new instance** of [T]
  /// every time it is resolved using [Injector.getAsync].
  ///
  /// These services can only be resolved with [getAsync] and will throw
  /// if accessed via the synchronous [get] method.
  void registerAsyncFactory<T>(
    AsyncFactory<T> factory, {
    AsyncPostCreate<T>? onCreate,
    String? name,
  });

  /// Registers an async factory that creates a **shared singleton instance** of [T].
  ///
  /// The instance is lazily created the first time it is requested using [getAsync].
  /// These services can only be resolved with [getAsync] and will throw
  /// if accessed via the synchronous [get] method.
  void registerAsyncSingleton<T>(
    AsyncFactory<T> factory, {
    AsyncPostCreate<T>? onCreate,
    String? name,
  });

  /// Registers an eager singleton that is resolved immediately during the build phase.
  ///
  /// The factory is executed during [build()], and the resulting instance is stored
  /// as a regular instance in the container. After build, these services can be
  /// accessed normally via [Injector.get].
  ///
  /// Use this for services that must be initialized early, such as configuration
  /// loaders, database connections, or core infrastructure.
  void registerEagerSingleton<T>(
    AsyncFactory<T> factory, {
    AsyncPostCreate<T>? onCreate,
    String? name,
  });

  /// Builds and returns an immutable [Injector] instance.
  ///
  /// This method resolves all eager singletons before creating the container.
  /// Once built, the container can no longer be modified.
  Future<Injector> build();
}

/// Immutable dependency container runtime interface.
///
/// Provides service resolution and access to all registered instances and factories.
abstract class Injector {
  /// Resolves and returns an instance of [T].
  ///
  /// If multiple instances are registered under different names,
  /// an optional [name] can be provided to specify which one to retrieve.
  ///
  /// Throws [StateError] if the service is registered as async-only.
  T get<T>([String? name]);

  /// Resolves and returns an async instance of [T].
  ///
  /// Use this method to resolve services registered with [registerAsyncFactory]
  /// or [registerAsyncSingleton].
  Future<T> getAsync<T>([String? name]);

  /// A shorthand for [get].
  T call<T>([String? name]) => get<T>(name);

  /// Checks whether a synchronous service of type [T] (and optional [name])
  /// is registered in the container.
  bool contains<T>([String? name]);

  /// Checks whether an async service of type [T] (and optional [name])
  /// is registered in the container.
  bool containsAsync<T>([String? name]);

  /// Returns all registered implementations of [T].
  ///
  /// Only returns synchronously available services (instances, factories, singletons).
  /// Async services are not included.
  List<T> all<T>();
}

class _InjectorBuilderImpl implements InjectorBuilder {
  final Map<_ServiceKey, _ServiceRegistration> _services = {};
  final List<_EagerSingletonRegistration> _eagerSingletons = [];

  @override
  void registerInstance<T>(T instance, {String? name}) {
    final key = _ServiceKey(T, name);
    _services[key] = _InstanceRegistration<T>(instance);
  }

  @override
  void registerFactory<T>(
    Factory<T> factory, {
    PostCreate<T>? onCreate,
    String? name,
  }) {
    final key = _ServiceKey(T, name);
    _services[key] = _FactoryRegistration<T>(factory, onCreate);
  }

  @override
  void registerSingleton<T>(
    Factory<T> factory, {
    PostCreate<T>? onCreate,
    String? name,
  }) {
    final key = _ServiceKey(T, name);
    _services[key] = _SingletonRegistration<T>(factory, onCreate);
  }

  @override
  void registerAsyncFactory<T>(
    AsyncFactory<T> factory, {
    AsyncPostCreate<T>? onCreate,
    String? name,
  }) {
    final key = _ServiceKey(T, name);
    _services[key] = _AsyncFactoryRegistration<T>(factory, onCreate);
  }

  @override
  void registerAsyncSingleton<T>(
    AsyncFactory<T> factory, {
    AsyncPostCreate<T>? onCreate,
    String? name,
  }) {
    final key = _ServiceKey(T, name);
    _services[key] = _AsyncSingletonRegistration<T>(factory, onCreate);
  }

  @override
  void registerEagerSingleton<T>(
    AsyncFactory<T> factory, {
    AsyncPostCreate<T>? onCreate,
    String? name,
  }) {
    final key = _ServiceKey(T, name);
    final registration = _EagerSingletonRegistration<T>(
      key: key,
      factory: factory,
      onCreate: onCreate,
    );
    _eagerSingletons.add(registration);
  }

  @override
  Future<Injector> build() async {
    final services = Map<_ServiceKey, _ServiceRegistration>.from(_services);

    final tempInjector = _InjectorImpl._(services, {}, {});

    for (final eager in _eagerSingletons) {
      final instance = await eager.factory(tempInjector);

      await eager.callOnCreate(instance, tempInjector);

      services[eager.key] = _InstanceRegistration(instance);
    }

    return _InjectorImpl._(
      services,
      tempInjector._singletonInstances,
      tempInjector._asyncSingletonInstances,
    );
  }
}

class _EagerSingletonRegistration<T> {
  final _ServiceKey key;
  final AsyncFactory<T> factory;
  final AsyncPostCreate<T>? onCreate;

  _EagerSingletonRegistration({
    required this.key,
    required this.factory,
    required this.onCreate,
  });

  Future<void> callOnCreate(dynamic instance, Injector container) async {
    if (onCreate != null) {
      await onCreate!(instance as T, container);
    }
  }
}

class _InjectorImpl implements Injector {
  final Map<_ServiceKey, _ServiceRegistration> _services;
  final Map<_ServiceKey, dynamic> _singletonInstances;
  final Map<_ServiceKey, dynamic> _asyncSingletonInstances;

  _InjectorImpl._(
    this._services,
    this._singletonInstances,
    this._asyncSingletonInstances,
  );

  @override
  T get<T>([String? name]) {
    final key = _ServiceKey(T, name);
    final registration = _services[key];

    if (registration == null) {
      throw ServiceNotFoundException(
        T,
        resolutionStack: const [],
        requestingType: null,
      );
    }

    if (registration.isAsync) {
      throw StateError(
        'Service $T${name != null ? ' with name "$name"' : ''} is registered as async. Use getAsync() instead.',
      );
    }

    return _resolveWithStack<T>(key, registration, []);
  }

  T _resolveWithStack<T>(
    _ServiceKey key,
    _ServiceRegistration registration,
    List<Type> resolutionStack,
  ) {
    // Check for circular dependency
    if (resolutionStack.contains(key.type)) {
      throw CircularDependencyException([...resolutionStack, key.type]);
    }

    final newStack = [...resolutionStack, key.type];

    // Create a resolution context wrapper around the container
    final contextInjector = _ResolutionContextInjector(this, newStack);

    try {
      return registration.resolve(contextInjector, key, _singletonInstances)
          as T;
    } on ServiceNotFoundException catch (e) {
      // If exception already has detailed resolution info, preserve it
      if (e.resolutionStack.isNotEmpty) {
        rethrow;
      }
      // Otherwise, add current context
      throw ServiceNotFoundException(
        e.serviceType,
        resolutionStack: newStack,
        requestingType: key.type,
      );
    }
  }

  @override
  Future<T> getAsync<T>([String? name]) async {
    final key = _ServiceKey(T, name);
    final registration = _services[key];

    if (registration == null) {
      throw ServiceNotFoundException(
        T,
        resolutionStack: const [],
        requestingType: null,
      );
    }

    return await _resolveAsyncWithStack<T>(key, registration, []);
  }

  Future<T> _resolveAsyncWithStack<T>(
    _ServiceKey key,
    _ServiceRegistration registration,
    List<Type> resolutionStack,
  ) async {
    // Check for circular dependency
    if (resolutionStack.contains(key.type)) {
      throw CircularDependencyException([...resolutionStack, key.type]);
    }

    // Create a resolution context wrapper around the container
    final contextInjector = _ResolutionContextInjector(
      this,
      [...resolutionStack, key.type],
    );

    try {
      return await registration.resolveAsync(
            contextInjector,
            key,
            _asyncSingletonInstances,
          )
          as T;
    } on ServiceNotFoundException catch (e) {
      // If exception already has detailed resolution info, preserve it
      if (e.resolutionStack.isNotEmpty) {
        rethrow;
      }
      // Otherwise, add current context
      throw ServiceNotFoundException(
        e.serviceType,
        resolutionStack: [...resolutionStack, key.type],
        requestingType: key.type,
      );
    }
  }

  @override
  T call<T>([String? name]) => get<T>(name);

  @override
  bool contains<T>([String? name]) {
    final key = _ServiceKey(T, name);
    final registration = _services[key];
    return registration != null && !registration.isAsync;
  }

  @override
  bool containsAsync<T>([String? name]) {
    final key = _ServiceKey(T, name);
    return _services.containsKey(key);
  }

  @override
  List<T> all<T>() {
    final results = <T>[];

    for (final entry in _services.entries) {
      if (entry.value.matches<T>() && !entry.value.isAsync) {
        final instance = _resolveWithStack(
          entry.key,
          entry.value,
          [],
        );
        results.add(instance as T);
      }
    }

    return results;
  }
}

/// Wrapper around the actual injector that tracks resolution context
class _ResolutionContextInjector implements Injector {
  final _InjectorImpl _actualInjector;
  final List<Type> _resolutionStack;

  _ResolutionContextInjector(this._actualInjector, this._resolutionStack);

  @override
  T get<T>([String? name]) {
    final key = _ServiceKey(T, name);
    final registration = _actualInjector._services[key];

    if (registration == null) {
      throw ServiceNotFoundException(
        T,
        resolutionStack: _resolutionStack,
        requestingType: _resolutionStack.isNotEmpty
            ? _resolutionStack.last
            : null,
      );
    }

    if (registration.isAsync) {
      throw StateError(
        'Service $T${name != null ? ' with name "$name"' : ''} is registered as async. Use getAsync() instead.',
      );
    }

    return _actualInjector._resolveWithStack<T>(
      key,
      registration,
      _resolutionStack,
    );
  }

  @override
  Future<T> getAsync<T>([String? name]) async {
    final key = _ServiceKey(T, name);
    final registration = _actualInjector._services[key];

    if (registration == null) {
      throw ServiceNotFoundException(
        T,
        resolutionStack: _resolutionStack,
        requestingType: _resolutionStack.isNotEmpty
            ? _resolutionStack.last
            : null,
      );
    }

    return await _actualInjector._resolveAsyncWithStack<T>(
      key,
      registration,
      _resolutionStack,
    );
  }

  @override
  T call<T>([String? name]) => get<T>(name);

  @override
  bool contains<T>([String? name]) => _actualInjector.contains<T>(name);

  @override
  bool containsAsync<T>([String? name]) =>
      _actualInjector.containsAsync<T>(name);

  @override
  List<T> all<T>() => _actualInjector.all<T>();
}

class _ServiceKey {
  final Type type;
  final String? name;

  const _ServiceKey(this.type, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ServiceKey &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name;

  @override
  int get hashCode => Object.hash(type, name);
}

abstract class _ServiceRegistration<T> {
  bool get isAsync => false;

  dynamic resolve(
    Injector container,
    _ServiceKey key,
    Map<_ServiceKey, dynamic> singletonCache,
  ) {
    throw StateError('This service can only be resolved asynchronously');
  }

  Future<dynamic> resolveAsync(
    Injector container,
    _ServiceKey key,
    Map<_ServiceKey, dynamic> singletonCache,
  ) async {
    // Default: delegate to sync resolve
    return resolve(container, key, singletonCache);
  }

  bool matches<D>() {
    return <T>[] is List<D>;
  }
}

class _InstanceRegistration<T> extends _ServiceRegistration<T> {
  final T instance;

  _InstanceRegistration(this.instance);

  @override
  T resolve(
    Injector container,
    _ServiceKey key,
    Map<_ServiceKey, dynamic> singletonCache,
  ) {
    return instance;
  }

  @override
  bool matches<D>() {
    if (instance is D) {
      return true;
    }

    return super.matches<D>();
  }
}

class _FactoryRegistration<T> extends _ServiceRegistration<T> {
  final Factory<T> factory;
  final PostCreate<T>? onCreate;

  _FactoryRegistration(this.factory, this.onCreate);

  @override
  T resolve(
    Injector container,
    _ServiceKey key,
    Map<_ServiceKey, dynamic> singletonCache,
  ) {
    final instance = factory(container);
    onCreate?.call(instance, container);
    return instance;
  }
}

class _SingletonRegistration<T> extends _ServiceRegistration<T> {
  final Factory<T> factory;
  final PostCreate<T>? onCreate;

  _SingletonRegistration(this.factory, this.onCreate);

  @override
  T resolve(
    Injector container,
    _ServiceKey key,
    Map<_ServiceKey, dynamic> singletonCache,
  ) {
    if (singletonCache.containsKey(key)) {
      return singletonCache[key] as T;
    }

    final instance = factory(container);
    singletonCache[key] = instance;
    onCreate?.call(instance, container);
    return instance;
  }
}

class _AsyncFactoryRegistration<T> extends _ServiceRegistration<T> {
  final AsyncFactory<T> factory;
  final AsyncPostCreate<T>? onCreate;

  _AsyncFactoryRegistration(this.factory, this.onCreate);

  @override
  bool get isAsync => true;

  @override
  Future<T> resolveAsync(
    Injector container,
    _ServiceKey key,
    Map<_ServiceKey, dynamic> singletonCache,
  ) async {
    final instance = await factory(container);
    if (onCreate != null) {
      await onCreate!(instance, container);
    }
    return instance;
  }
}

class _AsyncSingletonRegistration<T> extends _ServiceRegistration<T> {
  final AsyncFactory<T> factory;
  final AsyncPostCreate<T>? onCreate;

  _AsyncSingletonRegistration(this.factory, this.onCreate);

  @override
  bool get isAsync => true;

  @override
  Future<T> resolveAsync(
    Injector container,
    _ServiceKey key,
    Map<_ServiceKey, dynamic> singletonCache,
  ) async {
    if (singletonCache.containsKey(key)) {
      return singletonCache[key] as T;
    }

    final instance = await factory(container);
    singletonCache[key] = instance;

    if (onCreate != null) {
      await onCreate!(instance, container);
    }

    return instance;
  }
}
