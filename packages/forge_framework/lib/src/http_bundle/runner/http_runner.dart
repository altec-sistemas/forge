import 'dart:io';

import 'package:shelf/shelf_io.dart';

import '../../../forge_framework.dart';
import '../http/http_kernel.dart';

class HttpRunner implements Runner, Stoppable {
  final HttpKernel httpKernel;
  final HttpConfig? config;
  final EventBus eventBus;
  final Injector injector;

  HttpRunner({
    required this.httpKernel,
    required this.eventBus,
    this.config,
    required this.injector,
  });

  Future<HttpServer>? _server;

  @override
  Future<void> run([List<String>? args]) async {
    if (config == null) {
      return;
    }

    _server = serve(
      httpKernel.handle,
      config!.host,
      config!.port,
      shared: true,
    );
    eventBus.dispatch(HttpRunnerStarted(config!.host, config!.port));
  }

  @override
  Future<void> stop() async {
    _server?.then((server) async {
      await server.close(force: true);
    });
  }
}
