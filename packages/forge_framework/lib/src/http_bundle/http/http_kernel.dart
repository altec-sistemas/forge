import 'dart:async';

import '../../../forge_framework.dart';

const _log = Logger('HttpKernel');

class HttpKernel {
  final EventBus eventBus;
  final Router router;
  final bool debug;

  HttpKernel({
    required this.eventBus,
    required this.router,
    this.debug = false,
  });

  Future<Response> handle(Request request) async {
    final context = RequestContext(request);
    final completer = Completer<Response>();

    runZonedGuarded(
      () async {
        final requestEvent = HttpKernelRequestEvent(context);
        await eventBus.dispatch(requestEvent);

        if (requestEvent.response != null) {
          completer.complete(requestEvent.response!);
          return;
        }

        final handler = router.call;

        final response = await handler(context.request);

        final responseEvent = HttpKernelResponseEvent(context, response);
        await eventBus.dispatch(responseEvent);

        terminate(context, response);

        completer.complete(response);
      },
      (error, stackTrace) {
        if (error is HijackException) {
          return;
        }

        if (error is! HttpException && error is! ValidationException) {
          _log.error(
            'Exception caught in HttpKernel: $error',
            error: error,
            stackTrace: stackTrace,
          );
        }

        if (!completer.isCompleted) {
          _handleException(context, error, stackTrace, completer);
        }
      },
    );

    return completer.future;
  }

  void _handleException(
    RequestContext context,
    Object exception,
    StackTrace stackTrace,
    Completer<Response> completer,
  ) async {
    final exceptionEvent = HttpKernelExceptionEvent(
      context,
      exception,
      stackTrace,
    );

    await eventBus.dispatch(exceptionEvent);

    Response response;
    if (exceptionEvent.response != null) {
      response = exceptionEvent.response!;
    } else {
      response = JsonResponse({
        'message': 'An internal server error occurred.',
        if (debug) 'error': exception.toString(),
      }, statusCode: 500);
    }

    if (!completer.isCompleted) {
      completer.complete(response);
    }

    if (exceptionEvent.promoteToKernelException) {
      throw exception;
    }
  }

  Future<void> terminate(RequestContext context, Response response) async {
    eventBus.dispatch(HttpKernelTerminateEvent(context, response));
  }
}
