import '../../forge_framework.dart';

export 'socket/socket_events.dart';
export 'socket/socket_handler.dart';
export 'socket/web_socket_client.dart';

/// Bundle para WebSocket com suporte completo a anotações e argument resolvers
class SocketBundle extends Bundle {
  @override
  Future<void> build(
    InjectorBuilder builder,
    String env,
  ) async {
    // Registra o SocketHandler com suporte a argument resolution
    builder.registerSingleton<SocketHandler>((i) {
      return SocketHandler(
        i<EventBus>(),
      );
    });
  }

  @override
  Future<void> boot(
    Injector container,
  ) async {}
}
