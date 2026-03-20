import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Agora RTC service for 1-on-1 audio/video calls.
/// Drop-in replacement for WebRTCService — same callback surface,
/// but Agora handles all signaling, ICE, TURN, and media transport internally.
class AgoraCallService {
  RtcEngine? _engine;
  int? _remoteUid;
  String? _channelName;

  bool _connected = false;
  bool _failed    = false;

  // ── Callbacks (same interface as old WebRTCService) ────────────────────────
  void Function()? onConnected;
  void Function()? onConnectionFailed;
  void Function()? onRemoteStreamReady;

  // ── Getters used by the UI ─────────────────────────────────────────────────
  RtcEngine? get engine      => _engine;
  int?       get remoteUid   => _remoteUid;
  String?    get channelName => _channelName;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> initialize(String appId) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
  }

  Future<void> start({
    required String token,
    required String channelName,
    required int    uid,
    required bool   isVideo,
  }) async {
    _channelName = channelName;

    // ── Runtime permissions ────────────────────────────────────────────────
    final perms = [Permission.microphone];
    if (isVideo) perms.add(Permission.camera);
    final statuses = await perms.request();
    for (final e in statuses.entries) {
      if (!e.value.isGranted) {
        throw Exception('${e.key} permission denied — cannot start call');
      }
    }

    // ── Enable media ───────────────────────────────────────────────────────
    await _engine!.enableAudio();
    if (isVideo) await _engine!.enableVideo();

    // ── Event handlers ─────────────────────────────────────────────────────
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[Agora] Joined channel: ${connection.channelId} uid=$uid');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[Agora] Remote user joined: $remoteUid');
          _remoteUid = remoteUid;
          onRemoteStreamReady?.call();
          _triggerConnected();
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[Agora] Remote user left: $remoteUid reason=$reason');
          // Call ending is handled via socket (call_summary), not here.
        },
        onConnectionStateChanged: (connection, state, reason) {
          debugPrint('[Agora] Connection state: $state reason=$reason');
          if (state == ConnectionStateType.connectionStateFailed) {
            _triggerFailed();
          }
        },
      ),
    );

    // ── Join channel ───────────────────────────────────────────────────────
    await _engine!.joinChannel(
      token:     token,
      channelId: channelName,
      uid:       uid,
      options: ChannelMediaOptions(
        channelProfile:       ChannelProfileType.channelProfileCommunication,
        clientRoleType:       ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack:   isVideo,
        publishMicrophoneTrack: true,
        autoSubscribeVideo:   true,
        autoSubscribeAudio:   true,
      ),
    );
  }

  // ── One-shot triggers ─────────────────────────────────────────────────────

  void _triggerConnected() {
    if (_connected || _failed) return;
    _connected = true;
    debugPrint('[Agora] ✅ Connected');
    onConnected?.call();
  }

  void _triggerFailed() {
    if (_failed || _connected) return;
    _failed = true;
    debugPrint('[Agora] ❌ Connection failed');
    onConnectionFailed?.call();
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> setMuted(bool muted)          async => _engine?.muteLocalAudioStream(muted);
  Future<void> setCameraEnabled(bool on)     async => _engine?.enableLocalVideo(on);
  Future<void> setSpeaker(bool on)           async => _engine?.setEnableSpeakerphone(on);
  Future<void> switchCamera()               async => _engine?.switchCamera();

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine      = null;
    _remoteUid   = null;
    _channelName = null;
  }
}
