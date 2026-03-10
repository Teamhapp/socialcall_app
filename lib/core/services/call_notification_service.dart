import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows / dismisses a persistent "call in progress" notification so the
/// user can return to the call screen after backgrounding the app.
///
/// Uses [flutter_local_notifications] which is already declared in pubspec.yaml.
/// POST_NOTIFICATIONS permission is already declared in AndroidManifest.xml.
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

  // ── Show an ongoing (non-dismissible) notification ───────────────────────────

  static Future<void> showOngoingCall({
    required String hostName,
    required bool isVideo,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Keeps track of your active call',
      importance:        Importance.high,
      priority:          Priority.high,
      ongoing:           true,   // cannot be swiped away
      autoCancel:        false,
      playSound:         false,
      enableVibration:   false,
      category:          AndroidNotificationCategory.call,
      // usesChronometer shows elapsed time next to the notification timestamp
      when:              DateTime.now().millisecondsSinceEpoch,
      usesChronometer:   true,
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
