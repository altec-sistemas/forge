import 'dart:async';
import 'package:flutter/material.dart';
import 'package:forge_core/forge_core.dart';

abstract class Application extends BaseKernel {
  factory Application([String? env]) => _ApplicationImpl(env ?? 'prod');

  /// Instância global do Application
  static Application? _instance;

  /// Acessa a instância global do Application
  ///
  /// Throws [KernelException] se o Application ainda não foi criado
  static Application get instance {
    if (_instance == null) {
      throw KernelException(
        'Application has not been created yet. '
        'Create an Application instance before accessing it globally.',
      );
    }
    return _instance!;
  }

  /// Verifica se o Application já foi inicializado
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
