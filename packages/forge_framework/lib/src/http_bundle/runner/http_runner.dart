import 'dart:io';

import 'package:shelf/shelf_io.dart';

import '../../../forge_framework.dart';
import '../http/http_kernel.dart';

class HttpRunner implements Runner, Stoppable {
  final HttpKernel httpKernel;
  final HttpConfig config;
  final EventBus eventBus;

  HttpRunner({
    required this.httpKernel,
    required this.eventBus,
    HttpConfig? config,
  }) : config = config ?? HttpConfig(port: 8080, host: InternetAddress.anyIPv4);

  Future<HttpServer>? _server;

  @override
  Future<void> run([List<String>? args]) async {
    _server = serve(
      httpKernel.handle,
      config.host,
      config.port,
      shared: true,
    );
    eventBus.dispatch(HttpRunnerStarted(config.host, config.port));
  }

  @override
  Future<void> stop() async {
    _server?.then((server) async {
      await server.close(force: true);
    });
  }
}
