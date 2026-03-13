import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../socket/socket_service.dart';

/// WebRTC peer-to-peer audio/video service.
/// Uses Socket.IO (already connected) as the signaling channel.
/// No external API required — only Google's free STUN servers.
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

  /// Call this after the host accepts (caller receives call_connected event).
  /// [iceServers] — fetched from backend; falls back to defaults if null.
  Future<void> start({
    required String callId,
    required bool isCaller,
    required bool isVideo,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    _callId = callId;
    _isCaller = isCaller;
    _isVideo = isVideo;
    _iceServers = iceServers;

    await _startLocalStream();
    await _createPeerConnection();
    _setupSignalingListeners();

    // Caller creates and sends the offer to start negotiation
    if (isCaller) {
      await _createAndSendOffer();
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _startLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _isVideo
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false,
    });
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
        SocketService.emit('webrtc_ice_candidate', {
          'callId': _callId!,
          'candidate': candidate.toMap(),
        });
      }
    };

    // P2P connection state changes.
    // RTCPeerConnectionStateDisconnected is TRANSIENT — WebRTC retries ICE
    // automatically. Only RTCPeerConnectionStateFailed (permanent) should end
    // the call; treating Disconnected as failure kills calls on brief glitches.
    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onConnected?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onConnectionFailed?.call();
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _isVideo,
    });
    await _peerConnection!.setLocalDescription(offer);
    SocketService.emit('webrtc_offer', {
      'callId': _callId!,
      'sdp': offer.toMap(),
    });
  }

  void _setupSignalingListeners() {
    // Host (receiver): waits for offer → creates answer
    if (!_isCaller) {
      _offerCb = (data) async {
        if (data['callId'] != _callId) return;
        final sdp = data['sdp'] as Map<String, dynamic>;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
        );
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        SocketService.emit('webrtc_answer', {
          'callId': _callId!,
          'sdp': answer.toMap(),
        });
      };
      SocketService.on('webrtc_offer', _offerCb!);
    }

    // Caller: waits for answer → sets remote description
    if (_isCaller) {
      _answerCb = (data) async {
        if (data['callId'] != _callId) return;
        final sdp = data['sdp'] as Map<String, dynamic>;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
        );
      };
      SocketService.on('webrtc_answer', _answerCb!);
    }

    // Both: add ICE candidates from the other party
    _iceCb = (data) async {
      if (data['callId'] != _callId) return;
      if (_peerConnection == null) return; // already disposed
      final c = data['candidate'] as Map<String, dynamic>?;
      if (c == null) return;
      // null/empty candidate = end-of-candidates signal — safe to ignore
      final candidateStr = c['candidate'] as String?;
      if (candidateStr == null || candidateStr.isEmpty) return;
      try {
        await _peerConnection!.addCandidate(RTCIceCandidate(
          candidateStr,
          c['sdpMid'] as String?,
          (c['sdpMLineIndex'] as num?)?.toInt(),
        ));
      } catch (_) {
        // Ignore stale candidates (peer connection may have been closed)
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
    if (_offerCb != null) SocketService.off('webrtc_offer', _offerCb);
    if (_answerCb != null) SocketService.off('webrtc_answer', _answerCb);
    if (_iceCb != null) SocketService.off('webrtc_ice_candidate', _iceCb);

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    await remoteRenderer.dispose();

    _localStream = null;
    _peerConnection = null;
  }
}
