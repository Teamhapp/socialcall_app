import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows / dismisses a persistent "call in progress" notification so the
/// user can return to the call screen after backgrounding the app.
///
/// The notification is marked ongoing (non-dismissible) and backed by
/// WAKE_LOCK + FOREGROUND_SERVICE permissions declared in AndroidManifest.xml,
/// which prevents Android from killing the process during an active call.
class CallNotificationService {
  CallNotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'ongoing_call';
  static const _channelName = 'Ongoing Calls';
  static const _notifId     = 777;

  // ── Initialise once at app startup ──────────────────────────────────────────

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  // ── Show a persistent ongoing notification ───────────────────────────────────

  static Future<void> showOngoingCall({
    required String hostName,
    required bool isVideo,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Keeps your call active when the app is backgrounded',
      importance:         Importance.high,
      priority:           Priority.high,
      ongoing:            true,    // cannot be swiped away
      autoCancel:         false,
      playSound:          false,
      enableVibration:    false,
      category:           AndroidNotificationCategory.call,
      when:               DateTime.now().millisecondsSinceEpoch,
      usesChronometer:    true,    // shows live elapsed time in notification
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: false,
      presentBadge: false,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      _notifId,
      isVideo ? '📹 Video call in progress' : '📞 Audio call in progress',
      hostName,
      details,
    );
  }

  // ── Cancel the notification ──────────────────────────────────────────────────

  static Future<void> dismiss() async {
    await _plugin.cancel(_notifId);
  }
}
