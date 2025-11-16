import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Representa um cliente conectado ao WebSocket no servidor
class WebSocketClient {
  final String id;
  final WebSocketChannel channel;
  final DateTime connectedAt;

  /// Data/hora da última conexão anterior deste cliente
  /// Útil para rastrear reconexões e histórico do cliente
  final DateTime? lastConnectedAt;

  WebSocketClient({
    required this.id,
    required this.channel,
    this.lastConnectedAt,
  }) : connectedAt = DateTime.now();

  /// Envia um evento para este cliente específico
  void emit(String event, Map<String, dynamic> body) {
    try {
      final message = jsonEncode({
        'event': event,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
      });

      channel.sink.add(message);
    } catch (e) {
      print('Erro ao enviar mensagem para cliente $id: $e');
    }
  }

  /// Envia uma mensagem de erro para o cliente
  void sendError(String message) {
    emit('error', {'message': message});
  }

  /// Fecha a conexão com este cliente
  void disconnect() {
    try {
      channel.sink.close();
    } catch (e) {
      print('Erro ao desconectar cliente $id: $e');
    }
  }

  @override
  String toString() {
    return 'WebSocketClient(id: $id, connectedAt: $connectedAt)';
  }
}
