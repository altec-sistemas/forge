import '../../forge_framework.dart';

class HttpKernelRequestEvent {
  final RequestContext context;
  Response? response;

  HttpKernelRequestEvent(this.context);
}

class HttpKernelControllerEvent {
  final RequestContext context;
  final ClassMetadata controllerMetadata;
  final MethodMetadata methodMetadata;
  Response? response;

  HttpKernelControllerEvent(
    this.context,
    this.controllerMetadata,
    this.methodMetadata,
  );
}

class HttpKernelControllerArgumentsEvent {
  final RequestContext context;
  final MethodMetadata methodMetadata;
  final ArgumentsResult arguments;

  HttpKernelControllerArgumentsEvent(
    this.context,
    this.methodMetadata,
    this.arguments,
  );
}

class HttpKernelResponseEvent {
  final RequestContext context;
  final Response response;

  HttpKernelResponseEvent(this.context, this.response);
}

class HttpKernelExceptionEvent {
  final RequestContext context;
  final Object exception;
  final StackTrace? stackTrace;
  Response? response;

  /// If set to true, this exception will be promoted to a kernel-level exception
  /// and can be handled by higher-level exception handlers.
  bool promoteToKernelException;

  HttpKernelExceptionEvent(
    this.context,
    this.exception,
    this.stackTrace, {
    this.promoteToKernelException = false,
  });
}

class HttpKernelTerminateEvent {
  final RequestContext context;
  final Response response;

  HttpKernelTerminateEvent(this.context, this.response);
}

class HttpRunnerStarted {
  final Object host;
  final int port;

  const HttpRunnerStarted(this.host, this.port);
}
