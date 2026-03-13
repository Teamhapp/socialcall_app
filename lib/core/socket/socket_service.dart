import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_endpoints.dart';
import '../storage/storage_service.dart';

typedef MessageCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static io.Socket? _socket;
  static final Map<String, List<MessageCallback>> _listeners = {};

  static io.Socket? get socket => _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await StorageService.getAccessToken();
    if (token == null) return;

    _socket = io.io(
      ApiEndpoints.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      // ignore: avoid_print
      print('[Socket] Connected');
    });

    _socket!.onDisconnect((_) {
      // ignore: avoid_print
      print('[Socket] Disconnected');
    });

    _socket!.onConnectError((err) {
      // ignore: avoid_print
      print('[Socket] Connect error: $err');
    });

    // Re-attach all event listeners
    _listeners.forEach((event, callbacks) {
      for (final cb in callbacks) {
        _socket!.on(event, (data) => cb(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
        ));
      }
    });
  }

  static void on(String event, MessageCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, (data) => callback(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    ));
  }

  static void off(String event, [MessageCallback? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
      if (_listeners[event]?.isEmpty ?? false) _listeners.remove(event);
    } else {
      _listeners.remove(event);
    }

    // socket_io_client's off(event) removes ALL native handlers for that event.
    // Remove all, then re-register any remaining Dart callbacks.
    _socket?.off(event);
    for (final cb in List<MessageCallback>.from(_listeners[event] ?? [])) {
      _socket?.on(event, (data) => cb(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      ));
    }
  }

  static void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _listeners.clear();
  }
}
