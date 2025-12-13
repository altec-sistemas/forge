import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../forge_core.dart';

enum _SocketState {
  disconnected,
  connected,
  connectionLost,
  reconnecting,
}

final _list = <SocketClient>[];

/// Cliente WebSocket com reconexão automática e listeners
class SocketClient implements Disposable {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  Timer? _reconnectTimer;

  String? _url;
  String? _id;

  _SocketState _state = _SocketState.disconnected;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = false;
  bool _wasConnected = false;
  bool _disposed = false;

  final Map<String, List<Function(Map<String, dynamic>)>> _eventListeners = {};
  final List<Function()> _onConnectListeners = [];
  final List<Function()> _onDisconnectListeners = [];
  final List<Function(dynamic error)> _onErrorListeners = [];
  final List<Function()> _onReconnectingListeners = [];
  final List<Function()> _onConnectionLostListeners = [];

  SocketClient() {
    _list.add(this);
  }

  bool get isConnected => _state == _SocketState.connected;
  bool get isReconnecting => _state == _SocketState.reconnecting;
  String? get clientId => _id;
  int get reconnectAttempts => _reconnectAttempts;
  bool get isDisposed => _disposed;

  void onConnect(Function() callback) {
    _onConnectListeners.add(callback);
  }

  void onDisconnect(Function() callback) {
    _onDisconnectListeners.add(callback);
  }

  void onError(Function(dynamic error) callback) {
    _onErrorListeners.add(callback);
  }

  void onReconnecting(Function() callback) {
    _onReconnectingListeners.add(callback);
  }

  void onConnectionLost(Function() callback) {
    _onConnectionLostListeners.add(callback);
  }

  Future<bool> connect(String url, String id) async {
    if (_disposed) {
      return false;
    }

    if (isConnected) {
      return true;
    }

    _url = url;
    _id = id;
    _shouldReconnect = true;

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

      _state = _SocketState.connected;
      _reconnectAttempts = 0;
      _wasConnected = true;

      _notifyListeners(_onConnectListeners);

      return true;
    } catch (e) {
      if (_wasConnected && _state != _SocketState.connectionLost) {
        _state = _SocketState.connectionLost;
        _notifyListeners(_onConnectionLostListeners);
      }

      _notifyErrorListeners(e);

      if (_shouldReconnect && _wasConnected && !_disposed) {
        _scheduleReconnect();
      }

      return false;
    }
  }

  void _notifyListeners(List<Function()> listeners) {
    for (var listener in listeners) {
      try {
        listener();
      } catch (e) {
        // Ignora erros em listeners individuais
      }
    }
  }

  void _notifyErrorListeners(dynamic error) {
    for (var listener in _onErrorListeners) {
      try {
        listener(error);
      } catch (e) {
        // Ignora erros em listeners individuais
      }
    }
  }

  void _handleMessage(dynamic message) {
    if (_disposed) return;

    try {
      final data = jsonDecode(message as String);
      final event = data['event'] as String?;
      final body = data['body'] as Map<String, dynamic>? ?? {};

      if (event != null && _eventListeners.containsKey(event)) {
        for (var callback in _eventListeners[event]!) {
          try {
            callback(body);
          } catch (e) {
            // Ignora erros em callbacks individuais
          }
        }
      }
    } catch (e) {
      _notifyErrorListeners(e);
    }
  }

  void _handleDisconnection() {
    if (_disposed) return;

    if (_wasConnected && _shouldReconnect) {
      if (_state != _SocketState.connectionLost) {
        _state = _SocketState.connectionLost;
        _notifyListeners(_onConnectionLostListeners);
      }
      _scheduleReconnect();
    } else {
      _state = _SocketState.disconnected;
      _notifyListeners(_onDisconnectListeners);
    }
  }

  void _handleError(dynamic error) {
    if (_disposed) return;

    if (_wasConnected && _shouldReconnect) {
      if (_state != _SocketState.connectionLost) {
        _state = _SocketState.connectionLost;
        _notifyListeners(_onConnectionLostListeners);
      }
    }

    _notifyErrorListeners(error);

    if (_shouldReconnect && _wasConnected && !_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_url == null || _id == null || !_wasConnected || _disposed) return;

    if (_state != _SocketState.reconnecting) {
      _state = _SocketState.reconnecting;
      _notifyListeners(_onReconnectingListeners);
    }

    _reconnectAttempts++;

    // Delay progressivo: 1s, 2s, 4s, 8s... até máximo de 60s
    int delaySeconds = min(pow(1.2, _reconnectAttempts - 1).toInt(), 60);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldReconnect && _url != null && _id != null && !_disposed) {
        connect(_url!, _id!);
      }
    });
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
    if (_disposed || !isConnected) {
      return;
    }

    try {
      final message = jsonEncode({"event": event, "body": body});
      _channel?.sink.add(message);
    } catch (e) {
      _handleError(e);
    }
  }

  void tryReconnect() {
    if (_disposed) {
      return;
    }

    if (_url != null && _id != null) {
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      connect(_url!, _id!);
    }
  }

  void stopReconnection() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();

    if (_state == _SocketState.reconnecting) {
      _state = _SocketState.disconnected;
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _wasConnected = false;
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();

    try {
      _channel?.sink.close();
    } catch (e) {
      // Ignora erros ao fechar
    }

    _state = _SocketState.disconnected;
    _notifyListeners(_onDisconnectListeners);
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;

    disconnect();
    _eventListeners.clear();
    _onConnectListeners.clear();
    _onDisconnectListeners.clear();
    _onErrorListeners.clear();
    _onReconnectingListeners.clear();
    _onConnectionLostListeners.clear();
  }
}