import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../providers/incoming_call_provider.dart';
import '../router/app_router.dart';

// ─── Background message handler (top-level, outside any class) ───────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
  // Show local notification for call if host is in background
  if (message.data['type'] == 'call') {
    await FirebaseService._showCallLocalNotification(
      callerName: message.notification?.title ?? 'Incoming Call',
      callType: message.data['callType'] ?? 'audio',
      callId: message.data['callId'] ?? '',
    );
  }
}

// ─── FirebaseService ──────────────────────────────────────────────────────────
class FirebaseService {
  FirebaseService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localPlugin = FlutterLocalNotificationsPlugin();

  static const _callChannelId = 'incoming_call';
  static const _callChannelName = 'Incoming Calls';
  static const _defaultChannelId = 'socialcall_default';
  static const _defaultChannelName = 'General Notifications';

  // ── Called once at app startup ──────────────────────────────────────────────
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      debugPrint('[Firebase] Initialized');

      // Register the top-level background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Init local notifications (for heads-up display of FCM in foreground)
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _localPlugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onLocalNotifTap,
      );

      // Create Android notification channels
      if (Platform.isAndroid) {
        await _localPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              _callChannelId,
              _callChannelName,
              description: 'Incoming call alerts',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ));
        await _localPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              _defaultChannelId,
              _defaultChannelName,
              description: 'General app notifications',
              importance: Importance.high,
            ));
      }

      // Request permission
      await requestPermission();

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // App opened from terminated state via notification
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleNotificationOpen(initial);

      // App opened from background via notification tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
    } catch (e) {
      debugPrint('[Firebase] Init failed: $e');
    }
  }

  // ── Request notification permission ──────────────────────────────────────────
  static Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      debugPrint('[FCM] Permission request failed: $e');
      return false;
    }
  }

  // ── Get & register FCM token with backend ─────────────────────────────────
  static Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
      await ApiClient.dio.post(
        ApiEndpoints.fcmToken,
        data: {'fcmToken': token},
      );
      debugPrint('[FCM] Token registered with backend');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await ApiClient.dio.post(
            ApiEndpoints.fcmToken,
            data: {'fcmToken': newToken},
          );
          debugPrint('[FCM] Token refreshed & re-registered');
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  // ── Handle foreground FCM messages ───────────────────────────────────────────
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground: ${message.data}');
    final type = message.data['type'];

    if (type == 'call') {
      // Show high-priority call notification as heads-up
      await _showCallLocalNotification(
        callerName: message.notification?.title ?? 'Incoming Call',
        callType: message.data['callType'] ?? 'audio',
        callId: message.data['callId'] ?? '',
      );
    } else {
      // General notification
      final notif = message.notification;
      if (notif == null) return;
      await _localPlugin.show(
        message.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannelId,
            _defaultChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'type=${message.data['type'] ?? 'general'}',
      );
    }
  }

  // ── Show incoming call local notification ─────────────────────────────────
  static Future<void> _showCallLocalNotification({
    required String callerName,
    required String callType,
    required String callId,
  }) async {
    final isVideo = callType == 'video';
    await _localPlugin.show(
      999, // fixed ID so duplicate calls don't stack
      isVideo ? '📹 Incoming Video Call' : '📞 Incoming Call',
      callerName,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannelId,
          _callChannelName,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true, // show even when screen is off
          playSound: true,
          enableVibration: true,
          ongoing: false,
          autoCancel: true,
          timeoutAfter: 30000, // auto-dismiss after 30s
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: 'type=call&callId=$callId&callType=$callType',
    );
  }

  // ── Handle notification tap ───────────────────────────────────────────────
  static void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[FCM] Notification opened: ${message.data}');
    final type = message.data['type'];
    if (type == 'host_online') {
      AppRouter.router.go('/home');
    } else if (type == 'call') {
      final callId   = message.data['callId']     ?? '';
      final callType = message.data['callType']   ?? 'audio';
      // Caller name may be in data (if REST /initiate included it) or in body
      String callerName = message.data['callerName'] ?? '';
      if (callerName.isEmpty) {
        final body = message.notification?.body ?? '';
        callerName = body.contains(' is calling')
            ? body.replaceFirst(' is calling you', '')
            : 'Caller';
      }
      if (callId.isNotEmpty) {
        IncomingCallNotifier.setPendingCall({
          'callId':      callId,
          'callType':    callType,
          'callerName':  callerName,
        });
      }
      AppRouter.router.go('/home');
    }
  }

  static void _onLocalNotifTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped: ${response.payload}');
    final payload = response.payload ?? '';
    if (payload.contains('type=host_online')) {
      AppRouter.router.go('/home');
    } else if (payload.contains('type=call')) {
      final params   = Uri.splitQueryString(payload);
      final callId   = params['callId']   ?? '';
      final callType = params['callType'] ?? 'audio';
      if (callId.isNotEmpty) {
        IncomingCallNotifier.setPendingCall({
          'callId':     callId,
          'callType':   callType,
          'callerName': 'Caller',
        });
      }
      AppRouter.router.go('/home');
    }
  }

  // ── Delete token on logout ────────────────────────────────────────────────
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('[FCM] Token deleted');
    } catch (_) {}
  }
}
