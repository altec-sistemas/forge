import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../forge_core.dart';
import '../logger.dart';

/// Estados possíveis da conexão WebSocket
enum SocketState {
  disconnected,
  connecting,
  connected,
  connectionLost,
  reconnecting,
}

const _logger = Logger('SocketClient');
final _list = <SocketClient>[];

/// Cliente WebSocket com reconexão automática e listeners
class SocketClient implements Disposable {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  Timer? _reconnectTimer;

  String? _url;
  String? _id;

  SocketState _currentState = SocketState.disconnected;

  int _reconnectAttempts = 0;
  bool _shouldReconnect = false;
  bool _wasConnected = false;
  bool _disposed = false;

  final Map<String, List<Function(Map<String, dynamic>)>> _eventListeners = {};

  Function()? _onConnect;
  Function()? _onDisconnect;
  Function(dynamic error)? _onError;
  Function()? _onReconnecting;
  Function()? _onConnectionLost;

  SocketClient() {
    _logger.info('SocketClient criado (instance: ${identityHashCode(this)})');
    _list.add(this);
    _logger.info('Total de SocketClients ativos: ${_list.length}');
  }

  SocketState get state => _currentState;
  bool get isConnected => _currentState == SocketState.connected;
  bool get isConnecting => _currentState == SocketState.connecting;
  bool get isDisconnected => _currentState == SocketState.disconnected;
  bool get isConnectionLost => _currentState == SocketState.connectionLost;
  bool get isReconnecting => _currentState == SocketState.reconnecting;
  String? get clientId => _id;
  int get reconnectAttempts => _reconnectAttempts;
  bool get isDisposed => _disposed;

  void onConnect(Function() callback) {
    _onConnect = callback;
  }

  void onDisconnect(Function() callback) {
    _onDisconnect = callback;
  }

  void onError(Function(dynamic error) callback) {
    _onError = callback;
  }

  void onReconnecting(Function() callback) {
    _onReconnecting = callback;
  }

  void onConnectionLost(Function() callback) {
    _onConnectionLost = callback;
  }

  Future<bool> connect(String url, String id) async {
    if (_disposed) {
      _logger.warning('Tentativa de conectar com SocketClient disposed');
      return false;
    }

    if (isConnected) {
      _logger.info('Já está conectado');
      return true;
    }

    _url = url;
    _id = id;
    _shouldReconnect = true;

    if (_currentState != SocketState.reconnecting) {
      _updateState(SocketState.connecting);
    }

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(url).replace(queryParameters: {'clientId': id}, path: '/ws'),
      );

      await _channel!.ready;

      _streamSubscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnection,
        onError: _handleError,
        cancelOnError: false,
      );

      _updateState(SocketState.connected);
      _reconnectAttempts = 0;
      _wasConnected = true;

      _logger.info(
        'WebSocket conectado com sucesso (instance: ${identityHashCode(this)})',
      );
      _onConnect?.call();

      return true;
    } catch (e) {
      _logger.warning('Erro ao conectar WebSocket: $e');

      if (_wasConnected) {
        _updateState(SocketState.connectionLost);
        _onConnectionLost?.call();
      } else {
        _updateState(SocketState.disconnected);
      }

      _onError?.call(e);

      if (_shouldReconnect && _wasConnected && !_disposed) {
        _scheduleReconnect();
      }

      return false;
    }
  }

  void _handleMessage(dynamic message) {
    if (_disposed) return;

    _logger.info('hash: ${this.hashCode}');

    try {
      final data = jsonDecode(message as String);
      final event = data['event'] as String?;
      final body = data['body'] as Map<String, dynamic>? ?? {};

      if (event != null && _eventListeners.containsKey(event)) {
        for (var callback in _eventListeners[event]!) {
          try {
            callback(body);
          } catch (e) {
            _logger.warning('Erro no listener do evento $event: $e');
          }
        }
      }
    } catch (e) {
      _logger.warning('Erro ao processar mensagem: $e');
      _onError?.call(e);
    }
  }

  void _handleDisconnection() {
    if (_disposed) return;

    _logger.info('WebSocket desconectado');

    if (_wasConnected && _shouldReconnect) {
      _updateState(SocketState.connectionLost);
      _onConnectionLost?.call();
    } else {
      _updateState(SocketState.disconnected);
      _onDisconnect?.call();
    }

    if (_shouldReconnect && _wasConnected && !_disposed) {
      _scheduleReconnect();
    }
  }

  void _handleError(dynamic error) {
    if (_disposed) return;

    _logger.warning('Erro no WebSocket: $error');

    if (_wasConnected && _shouldReconnect) {
      _updateState(SocketState.connectionLost);
      _onConnectionLost?.call();
    } else {
      _updateState(SocketState.disconnected);
    }

    _onError?.call(error);

    if (_shouldReconnect && _wasConnected && !_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_url == null || _id == null || !_wasConnected || _disposed) return;

    _updateState(SocketState.reconnecting);
    _onReconnecting?.call();

    _reconnectAttempts++;

    // Delay progressivo: 1s, 2s, 4s, 8s... até máximo de 60s
    int delaySeconds = min(pow(1.2, _reconnectAttempts - 1).toInt(), 60);

    _logger.info(
      'Agendando reconexão em ${delaySeconds}s (tentativa $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldReconnect && _url != null && _id != null && !_disposed) {
        _logger.info('Tentando reconectar...');
        connect(_url!, _id!);
      }
    });
  }

  void _updateState(SocketState newState) {
    if (_currentState != newState) {
      _logger.info('Estado mudou de $_currentState para $newState');
      _currentState = newState;
    }
  }

  void on(String event, Function(Map<String, dynamic>) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
  }

  void off(String event, [Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _eventListeners[event]?.remove(callback);
    } else {
      _eventListeners.remove(event);
    }
  }

  void emit(String event, Map<String, dynamic> body) {
    if (_disposed) {
      _logger.warning('Tentativa de enviar mensagem com SocketClient disposed');
      return;
    }

    if (!isConnected) {
      _logger.warning('Tentativa de enviar mensagem sem estar conectado');
      return;
    }

    try {
      final message = jsonEncode({"event": event, "body": body});
      _channel?.sink.add(message);
    } catch (e) {
      _logger.warning('Erro ao enviar mensagem: $e');
      _handleError(e);
    }
  }

  void tryReconnect() {
    if (_disposed) {
      _logger.warning('Tentativa de reconectar com SocketClient disposed');
      return;
    }

    if (_url != null && _id != null) {
      _logger.info('Tentativa manual de reconexão');
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      connect(_url!, _id!);
    } else {
      _logger.warning(
        'Não é possível reconectar: parâmetros de conexão não definidos',
      );
    }
  }

  void stopReconnection() {
    _logger.info('Parando reconexão automática');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();

    if (!isConnected) {
      _updateState(SocketState.disconnected);
    }
  }

  void disconnect() {
    _logger.info('Desconectando manualmente');
    _shouldReconnect = false;
    _wasConnected = false;
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();

    try {
      _channel?.sink.close();
    } catch (e) {
      _logger.warning('Erro ao fechar WebSocket: $e');
    }

    _updateState(SocketState.disconnected);
    _onDisconnect?.call();
  }

  @override
  void dispose() {
    if (_disposed) return;

    throw Exception('Use disconnect() para fechar a conexão antes de dispor.');

    _logger.info(
      'Disposing SocketClient (instance: ${identityHashCode(this)})',
    );

    _disposed = true;

    disconnect();
    _eventListeners.clear();
    _onConnect = null;
    _onDisconnect = null;
    _onError = null;
    _onReconnecting = null;
    _onConnectionLost = null;
  }
}
