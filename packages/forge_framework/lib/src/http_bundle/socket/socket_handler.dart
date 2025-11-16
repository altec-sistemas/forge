import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../../../forge_framework.dart';

/// Handler para gerenciar conexões WebSocket no servidor
class SocketHandler {
  final Logger _logger = Logger('SocketHandler');
  final EventBus _eventBus;

  final Map<String, WebSocketClient> _clients = {};
  final Map<String, DateTime> _clientLastConnection = {};

  SocketHandler(this._eventBus);

  /// Handler do Shelf para gerenciar conexões WebSocket
  Handler get handler => (Request request) {
    return webSocketHandler((webSocket, protocol) {
      final clientId =
          request.requestedUri.queryParameters['clientId'] ??
          _generateClientId();

      // Busca a última conexão deste cliente
      final lastConnection = _clientLastConnection[clientId];

      final client = WebSocketClient(
        id: clientId,
        channel: webSocket,
        lastConnectedAt: lastConnection,
      );

      _clients[clientId] = client;
      _logger.info('Cliente conectado: $clientId');

      // Dispara evento de conexão
      _eventBus.dispatch(
        SocketClientConnectEvent(
          client: client,
          lastConnectedAt: lastConnection,
        ),
      );

      // Escuta mensagens do cliente
      webSocket.stream.listen(
        (message) => _handleMessage(client, message),
        onDone: () => _handleDisconnect(client),
        onError: (error) => _handleError(client, error),
      );
    })(request);
  };

  /// Processa mensagens recebidas de um cliente
  void _handleMessage(WebSocketClient client, dynamic message) async {
    try {
      final data = jsonDecode(message as String);
      final event = data['event'] as String?;
      final body = data['body'] as Map<String, dynamic>? ?? {};

      if (event != null) {
        _logger.info('Evento recebido: $event de ${client.id}');

        // Dispara evento de mensagem no EventBus
        _eventBus.dispatch(
          SocketMessageEvent(
            client: client,
            event: event,
            data: body,
          ),
        );
      }
    } catch (e, st) {
      _logger.warning(
        'Erro ao processar mensagem do cliente ${client.id}: $e',
        error: e,
        stackTrace: st,
      );
      client.sendError('Formato de mensagem inválido');
    }
  }

  /// Lida com a desconexão de um cliente
  void _handleDisconnect(WebSocketClient client) {
    final connectionDuration = DateTime.now().difference(client.connectedAt);

    // Salva o timestamp desta conexão como última conexão
    _clientLastConnection[client.id] = client.connectedAt;

    _clients.remove(client.id);
    _logger.info('Cliente desconectado: ${client.id}');

    // Dispara evento de desconexão
    _eventBus.dispatch(
      SocketClientDisconnectedEvent(
        client: client,
        connectionDuration: connectionDuration,
      ),
    );
  }

  /// Lida com erros de um cliente
  void _handleError(WebSocketClient client, dynamic error) {
    _logger.warning('Erro no cliente ${client.id}: $error');
  }

  /// Envia um evento para todos os clientes conectados
  void emit(String event, Map<String, dynamic> body) {
    for (final client in _clients.values) {
      client.emit(event, body);
    }
  }

  /// Envia um evento para um cliente específico
  void emitTo(String clientId, String event, Map<String, dynamic> body) {
    final client = _clients[clientId];
    if (client != null) {
      client.emit(event, body);
    } else {
      _logger.warning(
        'Tentativa de enviar para cliente inexistente: $clientId',
      );
    }
  }

  /// Envia um evento para todos os clientes exceto um específico
  void broadcast(
    String excludeClientId,
    String event,
    Map<String, dynamic> body,
  ) {
    for (final client in _clients.values) {
      if (client.id != excludeClientId) {
        client.emit(event, body);
      }
    }
  }

  /// Obtém um cliente específico pelo ID
  WebSocketClient? getClient(String clientId) {
    return _clients[clientId];
  }

  /// Verifica se um cliente está conectado
  bool isClientConnected(String clientId) {
    return _clients.containsKey(clientId);
  }

  /// Desconecta um cliente específico
  void disconnectClient(String clientId) {
    final client = _clients[clientId];
    if (client != null) {
      client.disconnect();
      _clients.remove(clientId);
      _logger.info('Cliente $clientId desconectado manualmente');
    }
  }

  /// Retorna estatísticas do servidor
  Map<String, dynamic> getStats() {
    return {
      'connectedClients': _clients.length,
      'clientIds': _clients.keys.toList(),
    };
  }

  /// Retorna a lista de todos os clientes conectados
  List<WebSocketClient> get clients => _clients.values.toList();

  /// Retorna a quantidade de clientes conectados
  int get clientCount => _clients.length;

  /// Gera um ID único para o cliente
  String _generateClientId() {
    return Uuid().v4();
  }

  /// Limpa todos os recursos
  void dispose() {
    for (final client in _clients.values) {
      client.disconnect();
    }
    _clients.clear();
    _clientLastConnection.clear();
  }
}
