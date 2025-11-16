import 'dart:async';
import 'package:flutter/material.dart';
import 'package:forge_core/forge_core.dart';

/// Flutter application kernel que gerencia o ciclo de vida da aplicação.
abstract class Application extends BaseKernel {
  factory Application([String? env]) =>
      _ApplicationImpl(env ?? 'prod')..addBundle(CoreBundle());

  static Application? _instance;

  static Application get instance {
    if (_instance == null) {
      throw KernelException(
        'Application has not been created yet. '
        'Create an Application instance before accessing it globally.',
      );
    }
    return _instance!;
  }

  static bool get hasInstance => _instance != null;

  /// Limpa a instância atual (útil para hot restart)
  static void reset() {
    if (_instance != null) {
      (_instance as _ApplicationImpl)._dispose();
      _instance = null;
    }
  }

  Future<void> run(Widget Function(Injector i) main);
}

const _log = Logger('Application');

class _ApplicationImpl with BaseKernelMixin implements Application {
  @override
  final String env;

  bool _running = false;
  bool _disposed = false;
  final List<Disposable> _disposables = [];

  _ApplicationImpl(this.env) {
    // Limpa a instância anterior antes de criar uma nova
    if (Application._instance != null) {
      _log.info('Limpando instância anterior do Application');
      Application.reset();
    }

    Application._instance = this;
  }

  @override
  void registerCoreServices(InjectorBuilder builder) {
    builder.registerInstance<Application>(this as Application);
    builder.registerInstance<BaseKernel>(this);
  }

  @override
  Future<void> run(Widget Function(Injector i) main) async {
    if (_disposed) {
      throw KernelException('Cannot run a disposed Application');
    }

    if (_running) {
      throw KernelException('Application is already running');
    }

    _running = true;

    _log.info('Starting Flutter application', extra: {'env': env});

    await build();
    await boot();

    _registerDisposables();

    return runApp(
      _ApplicationLifecycleWrapper(onDispose: _dispose, child: main(injector)),
    );
  }

  void _registerDisposables() {
    try {
      // Procura por todos os serviços que implementam Disposable
      final bindings = injector.all<Disposable>();

      for (final binding in bindings) {
        _disposables.add(binding);
        _log.info('Registrado disposable: ${binding.runtimeType}');
      }
    } catch (e) {
      _log.warning('Erro ao registrar disposables: $e');
    }
  }

  void _dispose() {
    if (_disposed) return;

    _log.info('Disposing Application e limpando recursos');
    _disposed = true;
    _running = false;

    // Dispõe todos os serviços registrados
    for (final disposable in _disposables) {
      try {
        disposable.dispose();
      } catch (e) {
        _log.warning('Erro ao dispor serviço: $e');
      }
    }

    _disposables.clear();
  }
}

/// Widget que detecta quando o app é reconstruído (hot restart)
class _ApplicationLifecycleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDispose;

  const _ApplicationLifecycleWrapper({
    required this.child,
    required this.onDispose,
  });

  @override
  State<_ApplicationLifecycleWrapper> createState() =>
      _ApplicationLifecycleWrapperState();
}

class _ApplicationLifecycleWrapperState
    extends State<_ApplicationLifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _log.info('Application lifecycle iniciado');
  }

  @override
  void dispose() {
    _log.info('Application lifecycle dispose chamado (hot restart detectado)');
    WidgetsBinding.instance.removeObserver(this);
    widget.onDispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log.info('App lifecycle mudou para: $state');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Global shortcut to access the Application injector.
Injector get injector => Application.instance.injector;
