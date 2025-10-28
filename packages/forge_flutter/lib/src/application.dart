import 'dart:async';
import 'package:flutter/material.dart';
import 'package:forge_core/forge_core.dart';

/// Flutter application kernel that manages the Flutter app lifecycle.
///
/// The Application class extends [BaseKernel] and provides Flutter-specific
/// functionality for building and running a Flutter application with
/// dependency injection and bundle management.
abstract class Application extends BaseKernel {
  /// Creates a new Application instance for the specified environment.
  ///
  /// [env] typically represents the application environment (e.g., 'dev', 'prod', 'test').
  factory Application([String? env]) => _ApplicationImpl(env ?? 'prod');

  /// Global Application instance.
  static Application? _instance;

  /// Accesses the global Application instance.
  ///
  /// Throws [KernelException] if the Application has not been created yet.
  static Application get instance {
    if (_instance == null) {
      throw KernelException(
        'Application has not been created yet. '
        'Create an Application instance before accessing it globally.',
      );
    }
    return _instance!;
  }

  /// Checks if the Application has already been initialized.
  static bool get hasInstance => _instance != null;

  /// Builds, boots, and runs the Flutter application.
  ///
  /// [main] is a function that receives the [Injector] and returns the root widget.
  ///
  /// This method:
  /// 1. Builds the dependency container
  /// 2. Boots all bundles
  /// 3. Calls Flutter's runApp with the widget returned by [main]
  ///
  /// Any errors during execution are caught and dispatched as [KernelErrorEvent].
  ///
  /// Throws [KernelException] if called more than once.
  Future<void> run(Widget Function(Injector i) main);
}

class _ApplicationImpl with BaseKernelMixin implements Application {
  @override
  final String env;

  bool _running = false;

  @override
  Logger logger;

  _ApplicationImpl(this.env, [Logger? logger])
    : logger =
          logger ??
          Logger(handlers: [ConsoleLogHandler()], minLevel: LogLevel.info) {
    Application._instance = this;
  }

  @override
  void registerCoreServices(InjectorBuilder builder) {
    builder.registerInstance<Application>(this as Application);
    builder.registerInstance<BaseKernel>(this);
  }

  @override
  Future<void> run(Widget Function(Injector i) main) async {
    if (_running) {
      throw KernelException('Application is already running');
    }

    _running = true;

    logger.info('Starting Flutter application', extra: {'env': env});

    await build();
    await boot();

    return runGuarded(() async {
      logger.info('Launching Flutter UI');
      runApp(main(injector));
    });
  }
}

/// Global shortcut to access the Application injector.
///
/// Throws [KernelException] if the Application has not been created yet.
Injector get injector => Application.instance.injector;

/// Global shortcut to access the Application logger.
///
/// Throws [KernelException] if the Application has not been created yet.
Logger get logger => Application.instance.logger;
