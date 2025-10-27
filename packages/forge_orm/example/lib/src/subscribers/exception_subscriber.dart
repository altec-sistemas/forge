import 'package:forge_framework/forge_framework.dart';

@Service()
class ExceptionSubscriber implements EventSubscriber {
  @override
  void subscribe(EventBus eventBus) {
    eventBus.on<KernelErrorEvent>(onException);
  }

  void onException(KernelErrorEvent event) {
    print('Exception caught: ${event.error}');
  }

  void onHttpException(HttpKernelExceptionEvent event) {
    print('HTTP Kernel Exception caught: ${event.exception}');
  }
}
