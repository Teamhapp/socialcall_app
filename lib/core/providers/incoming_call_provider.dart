import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../socket/socket_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class IncomingCallState {
  final String? callId;
  final String? callerId;   // the caller's user ID (used to build the HostModel on the call screen)
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final bool isRinging;

  const IncomingCallState({
    this.callId,
    this.callerId,
    this.callerName = '',
    this.callerAvatar,
    this.isVideo = false,
    this.isRinging = false,
  });

  /// True only when there is an active incoming call waiting for response.
  bool get hasCall => isRinging && callId != null && callId!.isNotEmpty;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class IncomingCallNotifier extends StateNotifier<IncomingCallState> {
  Timer? _missedTimer;
  MessageCallback? _incomingCb;
  MessageCallback? _cancelledCb;

  IncomingCallNotifier() : super(const IncomingCallState());

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Attach socket listeners.  Call after socket is connected and user is
  /// authenticated.  Safe to call multiple times (no-ops if already listening).
  void startListening() {
    if (_incomingCb != null) return; // already listening

    _incomingCb = (data) {
      final callId     = data['callId']   as String? ?? '';
      final callType   = data['callType'] as String? ?? 'audio';
      final callerMap  = data['caller']   as Map<String, dynamic>? ?? {};

      state = IncomingCallState(
        callId:       callId,
        callerId:     callerMap['id']     as String?,
        callerName:   callerMap['name']   as String? ?? 'Unknown',
        callerAvatar: callerMap['avatar'] as String?,
        isVideo:      callType == 'video',
        isRinging:    true,
      );

      // Auto-dismiss as missed call after 30 s
      _missedTimer?.cancel();
      _missedTimer = Timer(const Duration(seconds: 30), dismiss);
    };

    _cancelledCb = (data) {
      // Caller hung up / cancelled before we responded
      final cid = data['callId'] as String?;
      if (cid == null || cid == state.callId) dismiss();
    };

    SocketService.on('incoming_call', _incomingCb!);
    SocketService.on('call_cancelled', _cancelledCb!);
  }

  /// Detach socket listeners.  Call on logout / socket disconnect.
  void stopListening() {
    _missedTimer?.cancel();
    if (_incomingCb != null) {
      SocketService.off('incoming_call', _incomingCb);
      _incomingCb = null;
    }
    if (_cancelledCb != null) {
      SocketService.off('call_cancelled', _cancelledCb);
      _cancelledCb = null;
    }
  }

  /// Clear the current incoming-call state (accepted, declined, or missed).
  void dismiss() {
    _missedTimer?.cancel();
    if (mounted) state = const IncomingCallState();
  }

  @override
  void dispose() {
    _missedTimer?.cancel();
    stopListening();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final incomingCallProvider =
    StateNotifierProvider<IncomingCallNotifier, IncomingCallState>(
  (ref) => IncomingCallNotifier(),
);
