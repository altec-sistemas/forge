import 'web_socket_client.dart';

/// Evento disparado quando um cliente se conecta ao WebSocket
class SocketClientConnectEvent {
  final WebSocketClient client;

  /// Data/hora da última conexão anterior (null se é a primeira conexão)
  final DateTime? lastConnectedAt;

  SocketClientConnectEvent({
    required this.client,
    this.lastConnectedAt,
  });

  /// Verifica se é uma reconexão
  bool get isReconnection => lastConnectedAt != null;

  /// Tempo desde a última conexão (null se é a primeira conexão)
  Duration? get timeSinceLastConnection {
    if (lastConnectedAt == null) return null;
    return client.connectedAt.difference(lastConnectedAt!);
  }
}

/// Evento disparado quando um cliente se desconecta do WebSocket
class SocketClientDisconnectedEvent {
  final WebSocketClient client;

  /// Duração da conexão
  final Duration connectionDuration;

  SocketClientDisconnectedEvent({
    required this.client,
    required this.connectionDuration,
  });
}

/// Evento disparado quando uma mensagem é recebida de um cliente
class SocketMessageEvent {
  /// Cliente que enviou a mensagem
  final WebSocketClient client;

  /// Nome do evento
  final String event;

  /// Dados da mensagem (body)
  final Map<String, dynamic> data;

  SocketMessageEvent({
    required this.client,
    required this.event,
    required this.data,
  });

  /// Helper para obter um valor do data
  T? get<T>(String key) {
    return data[key] as T?;
  }

  /// Helper para obter um valor obrigatório do data
  T getRequired<T>(String key) {
    final value = data[key];
    if (value == null) {
      throw ArgumentError('Campo obrigatório não encontrado: $key');
    }
    return value as T;
  }
}
