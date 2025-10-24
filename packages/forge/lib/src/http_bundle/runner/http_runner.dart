import 'dart:io';

import 'package:shelf/shelf_io.dart';

import '../../../forge.dart';
import '../http/http_kernel.dart';

class HttpRunner implements Runner {
  final HttpKernel httpKernel;
  final HttpConfig config;
  final EventBus eventBus;

  HttpRunner({
    required this.httpKernel,
    required this.eventBus,
    HttpConfig? config,
  }) : config = config ?? HttpConfig(port: 8080, host: InternetAddress.anyIPv4);

  @override
  Future<void> run([List<String>? args]) async {
    await serve(httpKernel.handle, config.host, config.port);
    eventBus.dispatch(HttpRunnerStarted(config.host, config.port));
  }
}
