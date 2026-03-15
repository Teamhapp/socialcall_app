import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/services/call_notification_service.dart';
import '../../../core/services/webrtc_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/gift_picker_sheet.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── UI state ─────────────────────────────────────────────────────────────────
  bool _isMuted       = false;
  bool _isSpeakerOn   = true;
  bool _isCameraOff   = false;
  bool _isFrontCamera = true;
  bool _lowBalance    = false;  // show warning banner when < 1 min left
  CallStatus _status  = CallStatus.connecting;

  // ── Timers ───────────────────────────────────────────────────────────────────
  int    _seconds   = 0;
  Timer? _callTimer;   // per-second billing ticker
  Timer? _ringTimer;   // 45-s ringing timeout → auto-cancel if no answer

  // ── Wallet ───────────────────────────────────────────────────────────────────
  double _initialWalletBalance = 0;

  // ── Call lifecycle guard ─────────────────────────────────────────────────────
  /// Prevents double-ending the call (e.g. our own call_ended + backend echo).
  bool _callEndedByUs = false;

  // ── Gift overlay ─────────────────────────────────────────────────────────────
  /// Shown when the caller sends a gift during the call (host sees this).
  String? _giftOverlayText;
  Timer? _giftOverlayTimer;

  // ── WebRTC & socket callbacks ─────────────────────────────────────────────────
  final _webrtc = WebRTCService();
  MessageCallback? _callConnectedCb;
  MessageCallback? _callRejectedCb;
  MessageCallback? _callSummaryCb;
  MessageCallback? _walletWarnCb;   // server-side low-balance warning
  MessageCallback? _giftReceivedCb; // real-time gift notification

  // ── Animations ───────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  // ── Helpers ──────────────────────────────────────────────────────────────────
  double get _ratePerMin =>
      widget.isVideo ? widget.host.videoRatePerMin : widget.host.audioRatePerMin;

  double get _cost => (_seconds / 60) * _ratePerMin;

  String get _timeDisplay => _formatSeconds(_seconds);

  static String _formatSeconds(int s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Register lifecycle observer so we can handle background → foreground.
    WidgetsBinding.instance.addObserver(this);

    // Keep screen on during call (WAKE_LOCK permission required in manifest).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Snapshot wallet balance at call start for depletion checks.
    _initialWalletBalance =
        ref.read(authProvider).user?.walletBalance ?? 0.0;

    // Pulse animation used while connecting.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController);

    // Auto-cancel the call if the host never answers within 45 seconds.
    _ringTimer = Timer(const Duration(seconds: 45), _onRingingTimeout);

    _initWebRTC();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — make sure socket is live.
      if (!SocketService.isConnected) {
        SocketService.connect();
      }
      // Restore immersive mode (Android notification bar dismissal resets it).
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else if (state == AppLifecycleState.paused) {
      // App went to background — foreground service keeps process alive,
      // but restore normal UI mode so status bar shows in other apps.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _pulseController.dispose();
    CallNotificationService.dismiss(); // always clean up background notification
    if (_callConnectedCb != null) {
      SocketService.off('call_connected', _callConnectedCb);
    }
    if (_callRejectedCb != null) {
      SocketService.off('call_rejected', _callRejectedCb);
    }
    if (_callSummaryCb != null) {
      SocketService.off('call_summary', _callSummaryCb);
    }
    if (_walletWarnCb != null) {
      SocketService.off('wallet_low_warning', _walletWarnCb);
    }
    if (_giftReceivedCb != null) {
      SocketService.off('gift_received', _giftReceivedCb);
    }
    _giftOverlayTimer?.cancel();
    _webrtc.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Restore normal UI mode after leaving the call screen.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // WebRTC initialisation + socket event wiring
  // ─────────────────────────────────────────────────────────────────────────────

  /// Fetches ICE server list from backend (includes TURN if configured).
  /// Falls back to hardcoded defaults on any error so calls still work.
  Future<List<Map<String, dynamic>>?> _fetchIceServers() async {
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.iceServers);
      final raw = ApiClient.parseData(resp) as List?;
      debugPrint('[CallScreen] ICE servers from backend: $raw');
      return raw?.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[CallScreen] ICE server fetch failed: $e — using defaults');
      return null; // WebRTCService will use built-in defaults
    }
  }

  Future<void> _initWebRTC() async {
    debugPrint('[CallScreen] _initWebRTC() — isCaller=${widget.isCaller} callId=${widget.callId} isVideo=${widget.isVideo}');
    await _webrtc.initialize();
    debugPrint('[CallScreen] WebRTC renderers initialized');

    // ── P2P connection established ─────────────────────────────────────────────
    _webrtc.onConnected = () {
      if (!mounted) return;
      _ringTimer?.cancel(); // host answered — no more timeout needed
      setState(() => _status = CallStatus.connected);

      // Start per-second billing ticker with wallet check every 10 s.
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds % 10 == 0) _checkWallet();
      });

      // Show persistent background notification so the user can return.
      CallNotificationService.showOngoingCall(
        hostName: widget.host.name,
        isVideo:  widget.isVideo,
      );
    };

    // ── P2P connection failed ──────────────────────────────────────────────────
    _webrtc.onConnectionFailed = () {
      if (!mounted) return;
      _cleanupTimers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection failed')),
      );
      context.go('/home');
    };

    // ── Remote stream ready ────────────────────────────────────────────────────
    _webrtc.onRemoteStreamReady = () {
      if (mounted) setState(() {});
    };

    // Fetch ICE servers (STUN + TURN) from backend once for this call.
    debugPrint('[CallScreen] Fetching ICE servers...');
    final iceServers = await _fetchIceServers();
    debugPrint('[CallScreen] ICE servers: ${iceServers?.length ?? 'null (using defaults)'}');

    // ── Caller: wait for host acceptance → start WebRTC ───────────────────────
    if (widget.isCaller) {
      debugPrint('[CallScreen] CALLER — waiting for call_connected event');
      _callConnectedCb = (data) async {
        debugPrint('[CallScreen] CALLER received call_connected: $data');
        if (data['callId'] != widget.callId) {
          debugPrint('[CallScreen] CALLER call_connected ignored — wrong callId (got ${data['callId']}, expected ${widget.callId})');
          return;
        }
        debugPrint('[CallScreen] CALLER starting WebRTC...');
        await _webrtc.start(
          callId:     widget.callId,
          isCaller:   true,
          isVideo:    widget.isVideo,
          iceServers: iceServers,
        );
        debugPrint('[CallScreen] CALLER WebRTC started');
        if (mounted) setState(() {});
      };
      SocketService.on('call_connected', _callConnectedCb!);
    } else {
      // Host (receiver): start WebRTC immediately after accepting.
      debugPrint('[CallScreen] HOST — starting WebRTC immediately');
      await _webrtc.start(
        callId:     widget.callId,
        isCaller:   false,
        isVideo:    widget.isVideo,
        iceServers: iceServers,
      );
      debugPrint('[CallScreen] HOST WebRTC started, waiting for offer');
      if (mounted) setState(() {});
    }

    // ── Host rejected the call ────────────────────────────────────────────────
    _callRejectedCb = (data) {
      if ((data['callId'] as String?) != widget.callId) return;
      _cleanupTimers();
      CallNotificationService.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call was declined.')),
      );
      context.go('/home');
    };
    SocketService.on('call_rejected', _callRejectedCb!);

    // ── Server-side low-balance warning (authoritative — uses real DB balance) ─
    _walletWarnCb = (data) {
      if ((data['callId'] as String?) != widget.callId) return;
      if (mounted && !_lowBalance) setState(() => _lowBalance = true);
    };
    SocketService.on('wallet_low_warning', _walletWarnCb!);

    // ── Backend billing result — call ended by either party ───────────────────
    _callSummaryCb = (data) {
      if ((data['callId'] as String?) != widget.callId) return;
      // If we initiated the end, we already showed our own summary — ignore echo.
      if (_callEndedByUs) return;

      _cleanupTimers();
      CallNotificationService.dismiss();
      ref.read(authProvider.notifier).refreshBalance();

      final dSec     = data['durationSeconds'] as int?   ?? _seconds;
      final rawCharged = data['amountCharged'];
      final charged = rawCharged == null ? _cost
          : (rawCharged is num ? rawCharged.toDouble() : double.tryParse(rawCharged.toString()) ?? _cost);
      final autoEnded = data['autoEnded'] as bool? ?? false;

      if (mounted) {
        _showSummarySheet(
          duration:  _formatSeconds(dSec),
          cost:      charged,
          autoEnded: autoEnded,
        );
      }
    };
    SocketService.on('call_summary', _callSummaryCb!);

    // ── Gift received (shown to host during live call) ─────────────────────────
    _giftReceivedCb = (data) {
      final emoji  = (data['gift'] as Map?)?['emoji'] as String? ?? '🎁';
      final name   = (data['gift'] as Map?)?['name']  as String? ?? 'Gift';
      final sender = data['senderName'] as String?    ?? 'Someone';
      if (!mounted) return;
      _giftOverlayTimer?.cancel();
      setState(() => _giftOverlayText = '$emoji $name from $sender!');
      _giftOverlayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _giftOverlayText = null);
      });
    };
    SocketService.on('gift_received', _giftReceivedCb!);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Wallet depletion check (every 10 s while call is running)
  // ─────────────────────────────────────────────────────────────────────────────

  void _checkWallet() {
    if (!mounted || _callEndedByUs) return;
    final remaining = _initialWalletBalance - _cost;

    if (remaining <= 0) {
      _endCallInternal(reason: 'wallet_depleted');
    } else if (remaining < _ratePerMin && !_lowBalance) {
      // < 1 minute of funds left → show banner.
      setState(() => _lowBalance = true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Ringing timeout — fires at 45 s if host never answered
  // ─────────────────────────────────────────────────────────────────────────────

  void _onRingingTimeout() {
    if (_status != CallStatus.connecting || !mounted) return;
    // Emit call_ended: backend bills 0 (never connected) and notifies host
    // via call_cancelled so the incoming-call overlay dismisses.
    SocketService.emit('call_ended', {'callId': widget.callId});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No answer. Call cancelled.')),
      );
      context.go('/home');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // End-call paths
  // ─────────────────────────────────────────────────────────────────────────────

  /// User pressed the red button.
  void _endCall() => _endCallInternal();

  /// Shared termination logic — safe to call from any path exactly once.
  void _endCallInternal({String reason = ''}) {
    if (_callEndedByUs) return;
    _callEndedByUs = true;

    _cleanupTimers();
    CallNotificationService.dismiss();

    // Tell the backend: it bills and emits call_summary to both parties.
    // We'll ignore that echo because _callEndedByUs is now true.
    SocketService.emit('call_ended', {'callId': widget.callId});
    ref.read(authProvider.notifier).refreshBalance();

    if (mounted) {
      _showSummarySheet(
        duration:  _timeDisplay,
        cost:      _cost,
        autoEnded: reason == 'wallet_depleted',
      );
    }
  }

  void _cleanupTimers() {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _callTimer = null;
    _ringTimer = null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Call summary bottom sheet
  // ─────────────────────────────────────────────────────────────────────────────

  void _showSummarySheet({
    required String duration,
    required double cost,
    bool autoEnded = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isDismissible: false,
      enableDrag:    false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            if (autoEnded) ...[
              const Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.warning, size: 32),
              const SizedBox(height: 8),
              Text(
                'Balance depleted',
                style: AppTextStyles.headingSmall
                    .copyWith(color: AppColors.warning),
              ),
              const SizedBox(height: 12),
            ],

            Text('Call Summary', style: AppTextStyles.headingMedium),
            const SizedBox(height: 20),

            _SummaryRow('Duration', duration),
            _SummaryRow('Rate', '₹${_ratePerMin.toInt()}/min'),
            _SummaryRow(
              'Total Charged',
              '₹${cost.toStringAsFixed(2)}',
              highlight: true,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Show rating sheet for callers after a real call
                if (widget.isCaller && _seconds > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _showRatingSheet();
                  });
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) context.go('/home');
                  });
                }
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Post-call rating sheet (callers only)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showRatingSheet() {
    double rating = 0;
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.star_rounded,
                  color: AppColors.gold, size: 36),
              const SizedBox(height: 12),
              Text('Rate Your Call',
                  style: AppTextStyles.headingMedium),
              const SizedBox(height: 6),
              Text(
                'How was your call with ${widget.host.name}?',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding:
                    const EdgeInsets.symmetric(horizontal: 6),
                itemBuilder: (_, _) => const Icon(
                    Icons.star_rounded,
                    color: AppColors.gold),
                onRatingUpdate: (r) =>
                    setSheetState(() => rating = r),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: AppTextStyles.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Leave a comment (optional)...',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        if (mounted) context.go('/home');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: rating == 0
                          ? null
                          : () async {
                              Navigator.pop(sheetCtx);
                              try {
                                await ApiClient.dio.post(
                                  ApiEndpoints.callReview(
                                      widget.callId),
                                  data: {
                                    'rating': rating.toInt(),
                                    if (commentCtrl.text
                                        .trim()
                                        .isNotEmpty)
                                      'comment': commentCtrl.text
                                          .trim(),
                                  },
                                );
                              } catch (_) {
                                // rating is best-effort — never block navigation
                              }
                              if (mounted) context.go('/home');
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept the hardware/gesture back button during a call.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // While the call is still ringing or connecting, back = cancel.
        if (_status != CallStatus.connected) {
          _endCall();
          return;
        }
        // While connected, show a confirmation dialog.
        _showEndCallConfirm();
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.isVideo ? _buildVideoUI() : _buildAudioUI(),
            // Low-balance warning banner (floats above everything).
            if (_lowBalance) _buildLowBalanceBanner(),
            // Gift received floating toast (host sees this during call).
            if (_giftOverlayText != null) _buildGiftToast(),
          ],
        ),
      ),
    );
  }

  Future<void> _showEndCallConfirm() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('End Call?', style: AppTextStyles.headingSmall),
        content: Text(
          'Do you want to end the call with ${widget.host.name}?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.callRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('End Call'),
          ),
        ],
      ),
    );
    if (end == true) _endCall();
  }

  // ── Gift received toast ───────────────────────────────────────────────────

  Widget _buildGiftToast() {
    return Positioned(
      bottom: 120, left: 0, right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _giftOverlayText != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _giftOverlayText ?? '',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Low-balance banner ────────────────────────────────────────────────────

  Widget _buildLowBalanceBanner() {
    final remaining = _initialWalletBalance - _cost;
    final minsLeft  = remaining / _ratePerMin;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          color: AppColors.warning.withValues(alpha: 0.92),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Low balance! ~${minsLeft.clamp(0, 99).toStringAsFixed(1)} min remaining',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Video UI ──────────────────────────────────────────────────────────────

  Widget _buildVideoUI() {
    return Stack(
      children: [
        Positioned.fill(
          child: _status == CallStatus.connected
              ? RTCVideoView(
                  _webrtc.remoteRenderer,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                ),
        ),

        if (_status == CallStatus.connected && !_isCameraOff)
          Positioned(
            top: 60, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100, height: 140,
                child: RTCVideoView(
                  _webrtc.localRenderer,
                  mirror: _isFrontCamera,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

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
                  Text(widget.host.name,
                      style: AppTextStyles.headingLarge),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('Connecting...',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Column(
              children: [
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

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
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
                          setState(
                              () => _isCameraOff = !_isCameraOff);
                        },
                      ),
                      _ControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Flip',
                        isActive: false,
                        onTap: () async {
                          await _webrtc.switchCamera();
                          setState(() =>
                              _isFrontCamera = !_isFrontCamera);
                        },
                      ),
                      if (widget.isCaller)
                        _ControlButton(
                          icon: Icons.card_giftcard_rounded,
                          label: 'Gift',
                          isActive: false,
                          onTap: () => GiftPickerSheet.show(
                            context, ref,
                            hostId: widget.host.id,
                            hostName: widget.host.name,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 70, height: 70,
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

  // ── Audio UI ──────────────────────────────────────────────────────────────

  Widget _buildAudioUI() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F0F1A),
            AppColors.primary.withValues(alpha: 0.3),
          ],
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
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

            ScaleTransition(
              scale: _status == CallStatus.connecting
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
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

            if (_status == CallStatus.connecting)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text('Connecting...',
                      style: AppTextStyles.bodyMedium),
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
                '₹${_cost.toStringAsFixed(2)} charged  •  ₹${_ratePerMin.toInt()}/min',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],

            const Spacer(),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24),
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
                      setState(
                          () => _isSpeakerOn = !_isSpeakerOn);
                    },
                  ),
                  // Gift button — only callers send gifts to the host
                  if (widget.isCaller)
                    _ControlButton(
                      icon: Icons.card_giftcard_rounded,
                      label: 'Gift',
                      isActive: false,
                      onTap: () => GiftPickerSheet.show(
                        context, ref,
                        hostId: widget.host.id,
                        hostName: widget.host.name,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 70, height: 70,
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
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color:
                      isActive ? AppColors.primary : Colors.white24),
            ),
            child: Icon(icon,
                color:
                    isActive ? AppColors.primary : Colors.white,
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
