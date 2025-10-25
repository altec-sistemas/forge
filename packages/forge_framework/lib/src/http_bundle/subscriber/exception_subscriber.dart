import '../../../forge_framework.dart';

class ExceptionSubscriber implements EventSubscriber {
  @override
  void subscribe(EventBus dispatcher) {
    dispatcher.on<HttpKernelExceptionEvent>(_onException, priority: 200);
  }

  void _onException(HttpKernelExceptionEvent event) {
    final exception = event.exception;

    if (exception is HttpException) {
      event.response = JsonResponse({
        'message': exception.message,
      }, statusCode: exception.statusCode);
    }

    if (exception is ValidationException) {
      event.response = JsonResponse({
        'message': 'Validation Failed',
        'violations': exception.byField,
      }, statusCode: 422);
    }
  }
}
