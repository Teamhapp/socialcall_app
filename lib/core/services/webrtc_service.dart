import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../socket/socket_service.dart';

/// WebRTC peer-to-peer audio/video service.
/// Uses Socket.IO (already connected) as the signaling channel.
///
/// FIX — Timing race + ICE buffering:
/// • Caller does NOT send the offer immediately. Instead it waits for the
///   `webrtc_ready` event that the host emits once its listeners are live.
///   This prevents the offer arriving before the host's CallScreen has mounted.
/// • ICE candidates received before setRemoteDescription is called are buffered
///   and applied in order once the remote description is set.
class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  String? _callId;
  bool _isCaller = false;
  bool _isVideo = false;
  List<Map<String, dynamic>>? _iceServers;

  // Callbacks set by CallScreen
  void Function()? onConnected;
  void Function()? onConnectionFailed;
  void Function()? onRemoteStreamReady;

  // Internal listener refs for cleanup
  MessageCallback? _offerCb;
  MessageCallback? _answerCb;
  MessageCallback? _iceCb;
  MessageCallback? _readyCb; // caller waits for host-ready

  // ICE candidate buffer — holds candidates that arrive before
  // setRemoteDescription is called (Bug 2 fix).
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescSet = false;

  // Guards so callbacks fire exactly once
  bool _connected = false;
  bool _failed    = false;

  // Default ICE servers — used when the backend fetch fails.
  // Includes Metered open relay as a free TURN fallback so calls work on
  // most mobile networks even without a dedicated TURN server configured.
  static const _defaultIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'turn:openrelay.metered.ca:80',  'username': 'openrelayproject', 'credential': 'openrelayproject'},
    {'urls': 'turn:openrelay.metered.ca:443', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
    {'urls': 'turns:openrelay.metered.ca:443','username': 'openrelayproject', 'credential': 'openrelayproject'},
  ];

  Map<String, dynamic> _buildIceConfig(List<Map<String, dynamic>>? servers) => {
    'iceServers': servers ?? _defaultIceServers,
    'sdpSemantics': 'unified-plan',
  };

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// [isCaller=true]  → registers webrtc_ready listener, waits for host, then offers.
  /// [isCaller=false] → sets up listeners immediately, then emits webrtc_ready.
  Future<void> start({
    required String callId,
    required bool isCaller,
    required bool isVideo,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    _callId    = callId;
    _isCaller  = isCaller;
    _isVideo   = isVideo;
    _iceServers = iceServers;

    debugPrint('[WebRTC] start() — callId=$callId isCaller=$isCaller isVideo=$isVideo iceServers=${iceServers?.length ?? 0} servers');

    await _startLocalStream();
    debugPrint('[WebRTC] Local stream started');

    await _createPeerConnection();
    debugPrint('[WebRTC] Peer connection created');

    _setupSignalingListeners();
    debugPrint('[WebRTC] Signaling listeners registered');

    if (isCaller) {
      // BUG 1 FIX: Don't send offer yet.
      // Wait for the host to signal it is ready (webrtc_ready event).
      // Falls back to a 4-second hard timeout in case the event is missed.
      debugPrint('[WebRTC] CALLER waiting for webrtc_ready from host...');
      _waitForHostReady();
    } else {
      // Host: listeners are all registered — signal caller we are ready.
      debugPrint('[WebRTC] HOST emitting webrtc_ready');
      SocketService.emit('webrtc_ready', {'callId': callId});
      // Start ICE timeout — 30 s to connect or fail
      _startIceTimeout();
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Caller: listens for webrtc_ready from host, then sends offer.
  /// Hard timeout of 4 s in case the event is missed (e.g. host already sent it
  /// before the caller registered the listener).
  void _waitForHostReady() {
    bool offered = false;

    _readyCb = (data) {
      if (data['callId'] != _callId) return;
      if (offered) return;
      offered = true;
      debugPrint('[WebRTC] CALLER got webrtc_ready — creating offer');
      SocketService.off('webrtc_ready', _readyCb);
      _readyCb = null;
      _createAndSendOffer();
      _startIceTimeout(); // start 30 s ICE timeout
    };
    SocketService.on('webrtc_ready', _readyCb!);

    // Fallback: if webrtc_ready never arrives (race / missed), send offer anyway.
    // 8 s gives the host enough time to navigate to CallScreen and register its
    // webrtc_offer listener even on a slow phone (was 4 s — too short on budget
    // devices where activity start + camera init can take 3-5 s).
    Future.delayed(const Duration(seconds: 8), () {
      if (!offered && _peerConnection != null) {
        offered = true;
        debugPrint('[WebRTC] CALLER webrtc_ready timeout — sending offer anyway');
        if (_readyCb != null) {
          SocketService.off('webrtc_ready', _readyCb);
          _readyCb = null;
        }
        _createAndSendOffer();
        _startIceTimeout(); // start 30 s ICE timeout from fallback path too
      }
    });
  }

  // ── One-shot connected / failed triggers ────────────────────────────────────

  void _triggerConnected() {
    if (_connected || _failed) return;
    _connected = true;
    debugPrint('[WebRTC] ✅ P2P connected');
    onConnected?.call();
  }

  void _triggerFailed() {
    if (_failed || _connected) return;
    _failed = true;
    debugPrint('[WebRTC] ❌ P2P failed');
    onConnectionFailed?.call();
  }

  /// 30-second ICE timeout — if we haven't connected by then, fail the call.
  void _startIceTimeout() {
    Future.delayed(const Duration(seconds: 30), () {
      if (!_connected && _peerConnection != null) {
        debugPrint('[WebRTC] ICE timeout after 30 s — triggering failure');
        _triggerFailed();
      }
    });
  }

  Future<void> _startLocalStream() async {
    debugPrint('[WebRTC] Requesting getUserMedia audio=true video=$_isVideo');
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _isVideo
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false,
    });
    debugPrint('[WebRTC] Got local stream — tracks: ${_localStream!.getTracks().length}');
    localRenderer.srcObject = _localStream;
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_buildIceConfig(_iceServers));

    // Add local tracks to the connection
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Remote stream arrives → update renderer
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        onRemoteStreamReady?.call();
      }
    };

    // ICE candidate discovered → send via socket to the other party
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        debugPrint('[WebRTC] Sending ICE candidate: ${candidate.candidate!.substring(0, (candidate.candidate!.length).clamp(0, 60))}...');
        SocketService.emit('webrtc_ice_candidate', {
          'callId': _callId!,
          'candidate': candidate.toMap(),
        });
      }
    };

    // P2P connection state changes.
    // onConnectionState is unreliable on some Android versions — use
    // onIceConnectionState as the authoritative trigger for onConnected.
    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state → $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _triggerConnected();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _triggerFailed();
      }
    };

    // PRIMARY trigger on Android — fires reliably even when onConnectionState
    // doesn't. Both 'connected' and 'completed' mean P2P is live.
    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('[WebRTC] ICE connection state → $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _triggerConnected();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _triggerFailed();
      }
    };

    _peerConnection!.onSignalingState = (state) {
      debugPrint('[WebRTC] Signaling state → $state');
    };
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null) return;
    debugPrint('[WebRTC] Creating offer...');
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _isVideo,
    });
    await _peerConnection!.setLocalDescription(offer);
    debugPrint('[WebRTC] Offer created, sending via socket');
    SocketService.emit('webrtc_offer', {
      'callId': _callId!,
      'sdp': offer.toMap(),
    });
    debugPrint('[WebRTC] webrtc_offer emitted for callId=$_callId');
  }

  // BUG 2 FIX: Apply buffered ICE candidates after remote description is set.
  Future<void> _flushPendingCandidates() async {
    debugPrint('[WebRTC] Flushing ${_pendingCandidates.length} buffered ICE candidates');
    for (final c in _pendingCandidates) {
      try {
        await _peerConnection!.addCandidate(c);
      } catch (e) {
        debugPrint('[WebRTC] Failed to flush buffered ICE candidate: $e');
      }
    }
    _pendingCandidates.clear();
  }

  void _setupSignalingListeners() {
    // Host (receiver): waits for offer → creates answer
    if (!_isCaller) {
      _offerCb = (data) async {
        debugPrint('[WebRTC] HOST received webrtc_offer for callId=${data['callId']} (expected=$_callId)');
        if (data['callId'] != _callId) return;
        final sdp = data['sdp'] as Map<String, dynamic>;
        debugPrint('[WebRTC] HOST setting remote description (offer)');
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
        );
        _remoteDescSet = true;
        await _flushPendingCandidates(); // apply any buffered ICE candidates
        debugPrint('[WebRTC] HOST creating answer...');
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        debugPrint('[WebRTC] HOST sending webrtc_answer');
        SocketService.emit('webrtc_answer', {
          'callId': _callId!,
          'sdp': answer.toMap(),
        });
      };
      SocketService.on('webrtc_offer', _offerCb!);
      debugPrint('[WebRTC] HOST registered webrtc_offer listener');
    }

    // Caller: waits for answer → sets remote description
    if (_isCaller) {
      _answerCb = (data) async {
        debugPrint('[WebRTC] CALLER received webrtc_answer for callId=${data['callId']}');
        if (data['callId'] != _callId) return;
        final sdp = data['sdp'] as Map<String, dynamic>;
        debugPrint('[WebRTC] CALLER setting remote description (answer)');
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
        );
        _remoteDescSet = true;
        await _flushPendingCandidates(); // apply any buffered ICE candidates
        debugPrint('[WebRTC] CALLER remote description set');
      };
      SocketService.on('webrtc_answer', _answerCb!);
    }

    // Both: buffer ICE candidates until remote description is set (Bug 2 fix)
    _iceCb = (data) async {
      if (data['callId'] != _callId) return;
      if (_peerConnection == null) return; // already disposed
      final c = data['candidate'] as Map<String, dynamic>?;
      if (c == null) return;
      final candidateStr = c['candidate'] as String?;
      if (candidateStr == null || candidateStr.isEmpty) return;

      final candidate = RTCIceCandidate(
        candidateStr,
        c['sdpMid'] as String?,
        (c['sdpMLineIndex'] as num?)?.toInt(),
      );

      if (!_remoteDescSet) {
        // Remote description not yet set — buffer this candidate
        debugPrint('[WebRTC] Buffering ICE candidate (remote desc not ready yet)');
        _pendingCandidates.add(candidate);
        return;
      }

      debugPrint('[WebRTC] Adding remote ICE candidate');
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        debugPrint('[WebRTC] Failed to add ICE candidate: $e');
      }
    };
    SocketService.on('webrtc_ice_candidate', _iceCb!);
  }

  // ── Controls ─────────────────────────────────────────────────────────────────

  void setMuted(bool muted) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  void setCameraEnabled(bool on) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = on);
  }

  void setSpeaker(bool on) {
    Helper.setSpeakerphoneOn(on);
  }

  Future<void> switchCamera() async {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track != null) await Helper.switchCamera(track);
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    if (_readyCb  != null) SocketService.off('webrtc_ready',         _readyCb);
    if (_offerCb  != null) SocketService.off('webrtc_offer',         _offerCb);
    if (_answerCb != null) SocketService.off('webrtc_answer',        _answerCb);
    if (_iceCb    != null) SocketService.off('webrtc_ice_candidate', _iceCb);

    _pendingCandidates.clear();
    _connected = false;
    _failed    = false;
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    await remoteRenderer.dispose();

    _localStream    = null;
    _peerConnection = null;
  }
}
