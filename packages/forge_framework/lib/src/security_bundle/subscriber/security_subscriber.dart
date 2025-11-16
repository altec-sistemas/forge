import 'package:forge_core/forge_core.dart';

import '../../../forge_framework.dart';
import '../security.dart';

class SecuritySubscriber implements EventSubscriber {
  final Security _security;

  SecuritySubscriber(this._security);

  @override
  void subscribe(EventBus eventBus) {
    eventBus.on<HttpKernelRequestEvent>(onRequest, priority: 100);
  }

  Future<void> onRequest(HttpKernelRequestEvent event) async {
    await _security.authenticate(event.context);
  }
}
