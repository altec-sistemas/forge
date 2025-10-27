import 'dart:async';

import 'package:forge_core/forge_core.dart';

import 'http_bundle/http_bundle.dart';

/// The core application kernel that manages bundles, runners, and the dependency container.
///
/// The kernel is responsible for:
/// - Building and managing the dependency injection container
/// - Registering and booting bundles
/// - Coordinating application runners
/// - Handling global error events
abstract class Kernel extends BaseKernel {
  /// Creates a new kernel instance for the specified environment.
  ///
  /// [env] typically represents the application environment (e.g., 'dev', 'prod', 'test').
  factory Kernel([String? env]) => _KernelImpl(env ?? 'prod')
    ..addBundle(CoreBundle())
    ..addBundle(HttpBundle());

  /// Adds a runner to be executed when the kernel runs.
  void addRunner(Runner runner);

  /// Builds the container, boots all bundles, and executes all runners.
  ///
  /// This method:
  /// 1. Builds the dependency container by calling [Bundle.build] on all registered bundles
  /// 2. Boots all bundles by calling [Bundle.boot]
  /// 3. Dispatches a [KernelRunEvent]
  /// 4. Executes all registered runners concurrently
  ///
  /// Any errors during execution are caught and dispatched as [KernelErrorEvent].
  ///
  /// Throws [KernelException] if called more than once.
  Future<void> run([List<String>? args]);
}

/// Defines an executable component that runs as part of the kernel lifecycle.
///
/// Runners are executed concurrently after the kernel has booted.
/// Common examples include HTTP servers, CLI command processors, or background workers.
abstract class Runner {
  /// Executes the runner's main logic.
  ///
  /// [args] are the command-line arguments passed to the kernel.
  Future<void> run([List<String>? args]);
}

class _KernelImpl with BaseKernelMixin implements Kernel {
  final List<Runner> _runners = [];
  bool _running = false;

  @override
  final String env;

  _KernelImpl(this.env);

  @override
  void addRunner(Runner runner) {
    _runners.add(runner);
  }

  @override
  Future<void> onBoot() async {
    final runners = injector.all<Runner>();

    for (final runner in runners) {
      addRunner(runner);
    }
  }

  @override
  Future<void> run([List<String>? args]) async {
    if (_running) {
      throw KernelException('Kernel is already running');
    }

    _running = true;

    await build();

    if (isBooted) {
      throw KernelException('Kernel is already booted');
    }

    // Use a Completer to ensure the Future only completes when everything is finished
    final completer = Completer<void>();

    runZonedGuarded(
      () async {
        await boot();
        await eventDispatcher.dispatch(KernelRunEvent(this, args));
        await Future.wait(
          _runners.map((runner) async {
            await runner.run(args);
          }),
        );
        completer.complete();
      },
      (error, stackTrace) async {
        await eventDispatcher.dispatch(
          KernelErrorEvent(this, error, stackTrace),
        );
        logger.error(
          'Unhandled error during kernel run: $error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  @override
  void registerCoreServices(InjectorBuilder builder) {
    builder.registerInstance<Kernel>(this);
    builder.registerInstance<BaseKernel>(this);
  }
}

/// Event dispatched when the kernel begins executing runners.
class KernelRunEvent {
  /// The kernel instance that is running.
  final Kernel kernel;

  /// The command-line arguments passed to the kernel.
  final List<String>? args;

  KernelRunEvent(this.kernel, this.args);
}
