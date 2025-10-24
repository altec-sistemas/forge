import 'dart:async';
import 'package:flutter/material.dart';
import 'package:forge_core/forge_core.dart';

abstract class Application extends BaseKernel {
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

  Future<void> run(Widget Function(Injector i) main);
}

class _ApplicationImpl with BaseKernelMixin implements Application {
  @override
  final String env;

  _ApplicationImpl(this.env) {
    Application._instance = this;
  }

  @override
  void registerCoreServices(InjectorBuilder builder) {
    builder.registerInstance<Application>(this as Application);
    builder.registerInstance<BaseKernel>(this);
  }

  @override
  Future<void> run(Widget Function(Injector i) main) async {
    if (isBooted) {
      throw KernelException('Application is already running.');
    }

    await build();

    runZonedGuarded(
      () async {
        await boot();
        runApp(main(injector));
      },
      (error, stackTrace) async {
        await eventDispatcher.dispatch(
          KernelErrorEvent(this, error, stackTrace),
        );
      },
    );
  }
}

Injector get injector => Application.instance.injector;
