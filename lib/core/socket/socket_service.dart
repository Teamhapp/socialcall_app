import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_endpoints.dart';
import '../storage/storage_service.dart';

typedef MessageCallback = void Function(Map<String, dynamic> data);

/// Singleton socket manager with:
/// - Auto-reconnect on app resume (WidgetsBindingObserver)
/// - Re-attaches all Dart listeners after reconnection
/// - Safe off() that doesn't wipe other listeners
class SocketService with WidgetsBindingObserver {
  SocketService._();
  static final _instance = SocketService._();

  static io.Socket? _socket;
  static final Map<String, List<MessageCallback>> _listeners = {};

  static io.Socket? get socket => _socket;
  static bool get isConnected => _socket?.connected ?? false;

  // ── Initialise lifecycle observer once ──────────────────────────────────────

  static void initLifecycle() {
    WidgetsBinding.instance.addObserver(_instance);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-establish socket when app comes back to foreground.
      if (_socket == null || !_socket!.connected) {
        connect();
      }
    }
  }

  // ── Connect ─────────────────────────────────────────────────────────────────

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
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected — re-attaching ${_listeners.length} listener groups');
      // Re-attach all registered Dart callbacks after reconnect.
      _reattachAll();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('[Socket] Connect error: $err');
    });

    // Initial attach for any listeners already registered before connect().
    _reattachAll();
  }

  // ── Re-attach all Dart callbacks to the native socket ───────────────────────

  static void _reattachAll() {
    _listeners.forEach((event, callbacks) {
      _socket?.off(event); // clear stale native handlers first
      for (final cb in callbacks) {
        _socket?.on(event, (data) => cb(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
        ));
      }
    });
  }

  // ── Register a listener ─────────────────────────────────────────────────────

  static void on(String event, MessageCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, (data) => callback(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    ));
  }

  // ── Remove a specific listener (won't wipe others) ──────────────────────────

  static void off(String event, [MessageCallback? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
      if (_listeners[event]?.isEmpty ?? false) _listeners.remove(event);
    } else {
      _listeners.remove(event);
    }

    // socket_io_client off(event) clears ALL native handlers for that event.
    // Remove all then re-register the remaining Dart callbacks.
    _socket?.off(event);
    for (final cb in List<MessageCallback>.from(_listeners[event] ?? [])) {
      _socket?.on(event, (data) => cb(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      ));
    }
  }

  // ── Emit ────────────────────────────────────────────────────────────────────

  static void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  // ── Disconnect (logout) ─────────────────────────────────────────────────────

  static void disconnect() {
    WidgetsBinding.instance.removeObserver(_instance);
    _socket?.disconnect();
    _socket = null;
    _listeners.clear();
  }
}
