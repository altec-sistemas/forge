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
  Injector? _injector;

  @override
  final EventBus eventDispatcher = EventBus();

  @override
  Injector get injector {
    if (_injector == null) {
      throw KernelException('Kernel is not built yet. Call run() first.');
    }
    return _injector!;
  }

  @override
  void addBundle(Bundle bundle) {
    _bundles.add(bundle);
  }

  @override
  bool get isBooted => _booted;

  @override
  Future<void> build() async {
    final builder = InjectorBuilder();

    registerCoreServices(builder);

    builder.registerFactory<EventBus>((c) => eventDispatcher);
    builder.registerFactory<Injector>((c) => _injector!);
    builder.registerInstance<String>(env, name: 'env');

    await registerServices(builder);

    final metaBuilder = MetadataRegistryBuilder();

    for (final bundle in _bundles) {
      await bundle.buildMetadata(metaBuilder, env);
    }

    final metadataRegistry = metaBuilder.build();

    builder.registerInstance<MetadataRegistry>(metadataRegistry);

    for (final bundle in _bundles) {
      await bundle.build(builder, env);
    }

    _injector = await builder.build();
  }

  @override
  Future<void> boot() async {
    if (_booted) {
      throw KernelException('Kernel is already booted');
    }

    _booted = true;

    final eventSubscribers = injector.all<EventSubscriber>();
    for (final subscriber in eventSubscribers) {
      eventDispatcher.addSubscriber(subscriber);
    }

    _registerEventListeners();

    for (final bundle in _bundles) {
      await bundle.boot(injector);
    }

    await onBoot();
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
          '${methodMeta.classMetadata.typeMetadata.type}.${methodMeta.name} ',
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
