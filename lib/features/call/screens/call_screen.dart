import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/webrtc_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';
import '../../../core/providers/auth_provider.dart';

class CallScreen extends ConsumerStatefulWidget {
  final HostModel host;
  final bool isVideo;
  final String callId;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.host,
    required this.isVideo,
    required this.callId,
    required this.isCaller,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  CallStatus _status = CallStatus.connecting;
  int _seconds = 0;
  Timer? _callTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _webrtc = WebRTCService();
  MessageCallback? _callConnectedCb;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController);

    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _webrtc.initialize();

    _webrtc.onConnected = () {
      if (!mounted) return;
      setState(() => _status = CallStatus.connected);
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    };

    _webrtc.onConnectionFailed = () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection failed')),
      );
      context.go('/home');
    };

    _webrtc.onRemoteStreamReady = () {
      if (mounted) setState(() {});
    };

    if (widget.isCaller) {
      // Caller: wait for host to accept → call_connected event
      _callConnectedCb = (data) async {
        if (data['callId'] != widget.callId) return;
        await _webrtc.start(
          callId: widget.callId,
          isCaller: true,
          isVideo: widget.isVideo,
        );
        if (mounted) setState(() {});
      };
      SocketService.on('call_connected', _callConnectedCb!);
    } else {
      // Host (receiver): start WebRTC immediately
      await _webrtc.start(
        callId: widget.callId,
        isCaller: false,
        isVideo: widget.isVideo,
      );
      if (mounted) setState(() {});
    }
  }

  String get _timeDisplay {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _cost =>
      (_seconds / 60) *
      (widget.isVideo
          ? widget.host.videoRatePerMin
          : widget.host.audioRatePerMin);

  void _endCall() {
    _callTimer?.cancel();
    SocketService.emit('call_ended', {'callId': widget.callId});

    // Refresh wallet balance after call
    ref.read(authProvider.notifier).refreshBalance();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Call Summary', style: AppTextStyles.headingMedium),
            const SizedBox(height: 20),
            _SummaryRow('Duration', _timeDisplay),
            _SummaryRow(
              'Rate',
              '₹${(widget.isVideo ? widget.host.videoRatePerMin : widget.host.audioRatePerMin).toInt()}/min',
            ),
            _SummaryRow(
              'Total Charged',
              '₹${_cost.toStringAsFixed(2)}',
              highlight: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/home');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _pulseController.dispose();
    if (_callConnectedCb != null) {
      SocketService.off('call_connected', _callConnectedCb);
    }
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.isVideo ? _buildVideoUI() : _buildAudioUI(),
    );
  }

  // ── Video UI ────────────────────────────────────────────────────────────────

  Widget _buildVideoUI() {
    return Stack(
      children: [
        // Remote stream (fullscreen background)
        Positioned.fill(
          child: _status == CallStatus.connected
              ? RTCVideoView(
                  _webrtc.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
        ),

        // Local stream (picture-in-picture, top-right)
        if (_status == CallStatus.connected && !_isCameraOff)
          Positioned(
            top: 60,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100,
                height: 140,
                child: RTCVideoView(
                  _webrtc.localRenderer,
                  mirror: _isFrontCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

        // Connecting overlay
        if (_status == CallStatus.connecting)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: widget.host.avatar != null
                        ? NetworkImage(widget.host.avatar!)
                        : null,
                    backgroundColor: AppColors.card,
                    child: widget.host.avatar == null
                        ? const Icon(Icons.person_rounded,
                            size: 50, color: AppColors.textHint)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(widget.host.name, style: AppTextStyles.headingLarge),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Connecting...', style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Controls overlay (bottom)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Column(
              children: [
                // Timer
                if (_status == CallStatus.connected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_timeDisplay  •  ₹${_cost.toStringAsFixed(2)}',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: Colors.white),
                    ),
                  ),

                // Buttons row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: _isMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        isActive: _isMuted,
                        onTap: () {
                          _webrtc.setMuted(!_isMuted);
                          setState(() => _isMuted = !_isMuted);
                        },
                      ),
                      _ControlButton(
                        icon: _isCameraOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        label: 'Camera',
                        isActive: _isCameraOff,
                        onTap: () {
                          _webrtc.setCameraEnabled(_isCameraOff);
                          setState(() => _isCameraOff = !_isCameraOff);
                        },
                      ),
                      _ControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Flip',
                        isActive: false,
                        onTap: () async {
                          await _webrtc.switchCamera();
                          setState(
                              () => _isFrontCamera = !_isFrontCamera);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // End call
                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: AppColors.callRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.callRed,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.call_end_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Audio UI ────────────────────────────────────────────────────────────────

  Widget _buildAudioUI() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F0F1A),
            AppColors.primary.withOpacity(0.3),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Call type label
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Audio Call',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Host avatar with pulse
            ScaleTransition(
              scale: _status == CallStatus.connecting
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: widget.host.avatar != null
                      ? NetworkImage(widget.host.avatar!)
                      : null,
                  backgroundColor: AppColors.card,
                  child: widget.host.avatar == null
                      ? const Icon(Icons.person_rounded,
                          size: 60, color: AppColors.textHint)
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(widget.host.name, style: AppTextStyles.headingLarge),
            const SizedBox(height: 8),

            // Status / Timer
            if (_status == CallStatus.connecting)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Connecting...', style: AppTextStyles.bodyMedium),
                ],
              )
            else ...[
              Text(
                _timeDisplay,
                style: AppTextStyles.headingLarge
                    .copyWith(color: AppColors.online),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${_cost.toStringAsFixed(2)} charged  •  ₹${widget.host.audioRatePerMin.toInt()}/min',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],

            const Spacer(),

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    isActive: _isMuted,
                    onTap: () {
                      _webrtc.setMuted(!_isMuted);
                      setState(() => _isMuted = !_isMuted);
                    },
                  ),
                  _ControlButton(
                    icon: _isSpeakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    label: 'Speaker',
                    isActive: !_isSpeakerOn,
                    onTap: () {
                      _webrtc.setSpeaker(!_isSpeakerOn);
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // End call
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: AppColors.callRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.callRed,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.call_end_rounded,
                    color: Colors.white, size: 30),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primary : Colors.white24,
              ),
            ),
            child: Icon(icon,
                color: isActive ? AppColors.primary : Colors.white,
                size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(
            value,
            style: highlight
                ? AppTextStyles.headingSmall
                    .copyWith(color: AppColors.primary)
                : AppTextStyles.labelLarge,
          ),
        ],
      ),
    );
  }
}

enum CallStatus { connecting, connected }
