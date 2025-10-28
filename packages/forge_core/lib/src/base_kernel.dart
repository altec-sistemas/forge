import 'dart:async';
import '../forge_core.dart';

/// Base interface for all kernels (Application and Kernel).
abstract class BaseKernel {
  /// The immutable dependency container.
  Injector get injector;

  /// The current application environment.
  String get env;

  /// Event bus for dispatching events
  EventBus get eventDispatcher;

  /// Logger instance
  Logger get logger;
  set logger(Logger value);

  /// Registers a bundle to be built and initialized with the kernel.
  void addBundle(Bundle bundle);

  /// Checks if the kernel has already been initialized.
  bool get isBooted;

  /// Builds the dependency container.
  Future<void> build();

  /// Initializes the kernel and all bundles.
  Future<void> boot();

  /// Hook for subclasses to register core services.
  void registerCoreServices(InjectorBuilder builder);

  /// Hook for subclasses to register additional services.
  Future<void> registerServices(InjectorBuilder builder);

  /// Hook called after basic boot.
  Future<void> onBoot();
}

/// Mixin that implements the common logic of BaseKernel.
mixin BaseKernelMixin implements BaseKernel {
  final List<Bundle> _bundles = [];
  bool _booted = false;
  bool _built = false;
  Injector? _injector;

  @override
  final EventBus eventDispatcher = EventBus();

  @override
  Injector get injector {
    if (_injector == null) {
      throw KernelException('Kernel is not built yet. Call build() first.');
    }
    return _injector!;
  }

  @override
  void addBundle(Bundle bundle) {
    if (_built) {
      throw KernelException('Cannot add bundles after kernel has been built');
    }
    _bundles.add(bundle);
  }

  @override
  bool get isBooted => _booted;

  @override
  Future<void> build() async {
    if (_built) {
      throw KernelException('Kernel is already built');
    }

    logger.debug('Building kernel', extra: {'env': env});

    final builder = InjectorBuilder();

    // Register core services first
    registerCoreServices(builder);

    builder.registerFactory<EventBus>((c) => eventDispatcher);
    builder.registerFactory<Logger>((c) => logger);
    builder.registerSingleton<Injector>((i) => _injector!);
    builder.registerInstance<String>(env, name: 'env');

    // Hook for custom services
    await registerServices(builder);

    // Build metadata registry
    final metaBuilder = MetadataRegistryBuilder();

    for (final bundle in _bundles) {
      await bundle.buildMetadata(metaBuilder, env);
    }

    final metadataRegistry = metaBuilder.build();
    builder.registerInstance<MetadataRegistry>(metadataRegistry);

    // Build bundles
    for (final bundle in _bundles) {
      await bundle.build(builder, env);
    }

    _injector = await builder.build();
    _built = true;
  }

  @override
  Future<void> boot() async {
    if (!_built) {
      throw KernelException(
        'Kernel must be built before booting. Call build() first.',
      );
    }

    if (_booted) {
      throw KernelException('Kernel is already booted');
    }

    logger.debug('Booting kernel');

    _booted = true;

    // Register event subscribers
    final eventSubscribers = injector.all<EventSubscriber>();
    for (final subscriber in eventSubscribers) {
      eventDispatcher.addSubscriber(subscriber);
    }

    // Register event listeners from metadata
    _registerEventListeners();

    // Boot bundles
    for (final bundle in _bundles) {
      await bundle.boot(injector);
    }

    // Custom boot hook
    await onBoot();

    logger.info('Kernel booted successfully');
  }

  /// Executes code within a guarded zone that catches errors and dispatches them as events.
  ///
  /// This is the common implementation used by both Kernel and Application.
  Future<void> runGuarded(
    Future<void> Function() task, {
    void Function()? onError,
  }) async {
    final completer = Completer<void>();

    runZonedGuarded(
      () async {
        try {
          await task();
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (error, stackTrace) {
          logger.error(
            'Error during task execution',
            error: error,
            stackTrace: stackTrace,
          );

          await eventDispatcher.dispatch(
            KernelErrorEvent(this, error, stackTrace),
          );

          onError?.call();

          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      },
      (error, stackTrace) async {
        logger.error(
          'Unhandled error in zone',
          error: error,
          stackTrace: stackTrace,
        );

        await eventDispatcher.dispatch(
          KernelErrorEvent(this, error, stackTrace),
        );

        onError?.call();

        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    return completer.future;
  }

  @override
  Future<void> registerServices(InjectorBuilder builder) async {}

  @override
  Future<void> onBoot() async {}

  void _registerEventListeners() {
    final withListeners = injector
        .get<MetadataRegistry>()
        .methodsAnnotatedWith<AsEventListener>();

    for (final methodMeta in withListeners) {
      final listenerMeta = methodMeta.firstAnnotationOf<AsEventListener>()!;
      final priority = listenerMeta.priority;

      final instance = methodMeta.classMetadata.typeMetadata.captureGeneric(
        injector.get,
      );

      final method = methodMeta.getMethod(instance);

      if (methodMeta.parameters == null || methodMeta.parameters!.isEmpty) {
        throw KernelException(
          'Event listener methods must have exactly one parameter: '
          '${methodMeta.classMetadata.typeMetadata.type}.${methodMeta.name}',
        );
      }

      final parameter = methodMeta.parameters!.first;

      parameter.typeMetadata.captureGeneric(<T>() {
        eventDispatcher.on<T>((event) async {
          await Function.apply(method, [event]);
        }, priority: priority);
      });
    }
  }
}

/// Event dispatched when an error occurs during kernel execution.
class KernelErrorEvent {
  final BaseKernel kernel;
  final Object error;
  final StackTrace stackTrace;

  KernelErrorEvent(this.kernel, this.error, this.stackTrace);
}
