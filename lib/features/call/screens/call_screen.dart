import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/services/call_notification_service.dart';
import '../../../core/services/agora_call_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/gift_picker_sheet.dart';
import '../../../models/host_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';

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
  bool _lowBalance    = false;
  CallStatus _status  = CallStatus.connecting;

  // ── Timers ───────────────────────────────────────────────────────────────────
  int    _seconds   = 0;
  Timer? _callTimer;
  Timer? _ringTimer;

  // ── Wallet ───────────────────────────────────────────────────────────────────
  double _initialWalletBalance = 0;

  // ── Call lifecycle guard ─────────────────────────────────────────────────────
  bool _callEndedByUs = false;

  // ── Gift overlay ─────────────────────────────────────────────────────────────
  String? _giftOverlayText;
  bool    _giftOverlayVisible = false;
  Timer?  _giftOverlayTimer;

  // ── Agora & socket callbacks ──────────────────────────────────────────────────
  final _agora = AgoraCallService();
  MessageCallback? _callConnectedCb;
  MessageCallback? _callRejectedCb;
  MessageCallback? _callSummaryCb;
  MessageCallback? _walletWarnCb;
  MessageCallback? _giftReceivedCb;

  // Completer resolves once Agora creds are fetched; the call_connected
  // listener (registered synchronously in initState) awaits this so it
  // never misses the event even if the host accepts before the API returns.
  final Completer<Map<String, dynamic>?> _agoraCredsCompleter = Completer();

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

    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initialWalletBalance =
        ref.read(authProvider).user?.walletBalance ?? 0.0;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController);

    _ringTimer = Timer(const Duration(seconds: 45), _onRingingTimeout);

    // Register call_connected SYNCHRONOUSLY so it is never missed even if
    // the host accepts before _initAgora() finishes fetching the token.
    if (widget.isCaller) {
      _callConnectedCb = (data) async {
        debugPrint('[CallScreen] call_connected received: $data');
        if (data['callId'] != widget.callId) return;
        final creds = await _agoraCredsCompleter.future;
        if (!mounted || creds == null) return;
        debugPrint('[CallScreen] CALLER joining Agora channel');
        try {
          await _agora.start(
            token:       creds['token'] as String,
            channelName: creds['channelName'] as String,
            uid:         (creds['uid'] as num).toInt(),
            isVideo:     widget.isVideo,
          );
        } catch (e) {
          debugPrint('[CallScreen] CALLER _agora.start() failed: $e');
          if (mounted) {
            AppSnackBar.error(context, 'Could not start call: $e');
            context.go('/home');
          }
          return;
        }
        if (mounted) setState(() {});
      };
      SocketService.on('call_connected', _callConnectedCb!);
    }

    _initAgora();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!SocketService.isConnected) SocketService.connect();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else if (state == AppLifecycleState.paused) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _pulseController.dispose();
    CallNotificationService.dismiss();
    if (_callConnectedCb != null) SocketService.off('call_connected', _callConnectedCb);
    if (_callRejectedCb  != null) SocketService.off('call_rejected',  _callRejectedCb);
    if (_callSummaryCb   != null) SocketService.off('call_summary',   _callSummaryCb);
    if (_walletWarnCb    != null) SocketService.off('wallet_low_warning', _walletWarnCb);
    if (_giftReceivedCb  != null) SocketService.off('gift_received',  _giftReceivedCb);
    _giftOverlayTimer?.cancel();
    _agora.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Agora initialisation
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _initAgora() async {
    debugPrint('[CallScreen] _initAgora() — isCaller=${widget.isCaller} callId=${widget.callId}');

    // ── Agora callbacks ────────────────────────────────────────────────────────
    _agora.onConnected = () {
      if (!mounted) return;
      _ringTimer?.cancel();
      setState(() => _status = CallStatus.connected);
      _agora.setSpeaker(_isSpeakerOn);
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds % 10 == 0) _checkWallet();
      });
      CallNotificationService.showOngoingCall(
        hostName: widget.host.name,
        isVideo:  widget.isVideo,
      );
    };

    _agora.onConnectionFailed = () {
      if (!mounted || _callEndedByUs) return;
      _callEndedByUs = true;
      _cleanupTimers();
      CallNotificationService.dismiss();
      SocketService.emit('call_ended', {'callId': widget.callId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection failed. Please check your network and try again.'),
            backgroundColor: AppColors.callRed,
          ),
        );
        context.go('/home');
      }
    };

    _agora.onRemoteStreamReady = () {
      if (mounted) setState(() {});
    };

    // ── Fetch Agora token ──────────────────────────────────────────────────────
    Map<String, dynamic>? creds;
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.callAgoraToken(widget.callId));
      creds = ApiClient.parseData(resp) as Map<String, dynamic>?;
      debugPrint('[CallScreen] Agora creds: channel=${creds?['channelName']} uid=${creds?['uid']}');
    } catch (e) {
      debugPrint('[CallScreen] Agora token fetch failed: $e');
      if (!_agoraCredsCompleter.isCompleted) _agoraCredsCompleter.complete(null);
      if (mounted) {
        AppSnackBar.error(context, 'Could not start call: $e');
        context.go('/home');
      }
      return;
    }

    if (creds == null) {
      if (!_agoraCredsCompleter.isCompleted) _agoraCredsCompleter.complete(null);
      if (mounted) context.go('/home');
      return;
    }

    // ── Initialize Agora engine ────────────────────────────────────────────────
    try {
      await _agora.initialize(creds['appId'] as String);
    } catch (e) {
      debugPrint('[CallScreen] Agora initialize failed: $e');
      if (!_agoraCredsCompleter.isCompleted) _agoraCredsCompleter.complete(null);
      if (mounted) {
        AppSnackBar.error(context, 'Could not start call: $e');
        context.go('/home');
      }
      return;
    }

    // Unblock the call_connected listener (caller side).
    if (!_agoraCredsCompleter.isCompleted) _agoraCredsCompleter.complete(creds);

    if (!widget.isCaller) {
      // Host: join channel immediately after accepting.
      debugPrint('[CallScreen] HOST joining Agora channel');
      try {
        await _agora.start(
          token:       creds['token'] as String,
          channelName: creds['channelName'] as String,
          uid:         (creds['uid'] as num).toInt(),
          isVideo:     widget.isVideo,
        );
      } catch (e) {
        debugPrint('[CallScreen] HOST _agora.start() failed: $e');
        if (mounted) {
          AppSnackBar.error(context, 'Could not start call: $e');
          context.go('/home');
        }
        return;
      }
      if (mounted) setState(() {});
    }

    // ── Remaining socket listeners ─────────────────────────────────────────────

    _callRejectedCb = (data) {
      if ((data['callId'] as String?) != widget.callId) return;
      _cleanupTimers();
      CallNotificationService.dismiss();
      if (!mounted) return;
      AppSnackBar.info(context, 'Call was declined.');
      context.go('/home');
    };
    SocketService.on('call_rejected', _callRejectedCb!);

    _walletWarnCb = (data) {
      if ((data['callId'] as String?) != widget.callId) return;
      if (mounted && !_lowBalance) setState(() => _lowBalance = true);
    };
    SocketService.on('wallet_low_warning', _walletWarnCb!);

    _callSummaryCb = (data) {
      if ((data['callId'] as String?) != widget.callId) return;
      if (_callEndedByUs) return;
      _cleanupTimers();
      CallNotificationService.dismiss();
      ref.read(authProvider.notifier).refreshBalance();
      final dSec       = data['durationSeconds'] as int? ?? _seconds;
      final rawCharged = data['amountCharged'];
      final charged    = rawCharged == null
          ? _cost
          : (rawCharged is num
              ? rawCharged.toDouble()
              : double.tryParse(rawCharged.toString()) ?? _cost);
      final autoEnded  = data['autoEnded'] as bool? ?? false;
      if (mounted) {
        _showSummarySheet(
          duration:  _formatSeconds(dSec),
          cost:      charged,
          autoEnded: autoEnded,
        );
      }
    };
    SocketService.on('call_summary', _callSummaryCb!);

    _giftReceivedCb = (data) {
      final emoji  = (data['gift'] as Map?)?['emoji'] as String? ?? '🎁';
      final name   = (data['gift'] as Map?)?['name']  as String? ?? 'Gift';
      final sender = data['senderName'] as String?    ?? 'Someone';
      if (!mounted) return;
      _giftOverlayTimer?.cancel();
      setState(() {
        _giftOverlayText    = '$emoji $name from $sender!';
        _giftOverlayVisible = true;
      });
      _giftOverlayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _giftOverlayVisible = false);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _giftOverlayText = null);
        });
      });
    };
    SocketService.on('gift_received', _giftReceivedCb!);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Wallet check
  // ─────────────────────────────────────────────────────────────────────────────

  void _checkWallet() {
    if (!mounted || _callEndedByUs) return;
    final remaining = _initialWalletBalance - _cost;
    if (remaining <= 0) {
      _endCallInternal(reason: 'wallet_depleted');
    } else if (remaining < _ratePerMin && !_lowBalance) {
      setState(() => _lowBalance = true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Ringing timeout
  // ─────────────────────────────────────────────────────────────────────────────

  void _onRingingTimeout() {
    if (_status != CallStatus.connecting || !mounted) return;
    SocketService.emit('call_ended', {'callId': widget.callId});
    if (mounted) {
      AppSnackBar.info(context, 'No answer. Call cancelled.');
      context.go('/home');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // End-call
  // ─────────────────────────────────────────────────────────────────────────────

  void _endCall() => _endCallInternal();

  void _endCallInternal({String reason = ''}) {
    if (_callEndedByUs) return;
    _callEndedByUs = true;
    _cleanupTimers();
    CallNotificationService.dismiss();
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
  // Summary + rating sheets
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
              Text('Balance depleted',
                  style: AppTextStyles.headingSmall.copyWith(color: AppColors.warning)),
              const SizedBox(height: 12),
            ],
            Text('Call Summary', style: AppTextStyles.headingMedium),
            const SizedBox(height: 20),
            _SummaryRow('Duration', duration),
            _SummaryRow('Rate', '₹${_ratePerMin.toInt()}/min'),
            _SummaryRow('Total Charged', '₹${cost.toStringAsFixed(2)}', highlight: true),
            const SizedBox(height: 24),
            GradientButton(
              label: widget.isCaller && _seconds > 0
                  ? 'Rate Your Call ⭐'
                  : 'Done',
              height: 50,
              onTap: () {
                Navigator.pop(context);
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
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingSheet() {
    double rating = 0;
    final commentCtrl = TextEditingController();

    // Label for each star count
    const labels = ['', 'Terrible 😤', 'Poor 😕', 'Okay 😐', 'Good 😊', 'Excellent 🤩'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 0, 24,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Host avatar
              CircleAvatar(
                radius: 36,
                backgroundImage: widget.host.avatar != null
                    ? NetworkImage(widget.host.avatar!)
                    : null,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: widget.host.avatar == null
                    ? const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 36)
                    : null,
              ),
              const SizedBox(height: 14),

              Text('Rate Your Call', style: AppTextStyles.headingMedium),
              const SizedBox(height: 4),
              Text(
                'How was your experience with ${widget.host.name}?',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Star bar — larger, spaced
              RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 48,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (_, i) => Icon(
                  rating > i ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.gold,
                ),
                onRatingUpdate: (r) => setSheetState(() => rating = r),
              ),

              // Dynamic label
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  rating > 0 ? labels[rating.toInt()] : 'Tap to rate',
                  key: ValueKey(rating.toInt()),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: rating > 0
                        ? AppColors.gold
                        : AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Comment field
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Add a comment (optional)…',
                  prefixIcon: const Icon(Icons.edit_note_rounded,
                      color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 20),

              // Buttons row
              Row(
                children: [
                  // Skip
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        if (mounted) context.go('/home');
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Skip',
                            style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textHint),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Submit — gradient
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      label: 'Submit ⭐',
                      height: 50,
                      onTap: rating == 0
                          ? null
                          : () async {
                              Navigator.pop(sheetCtx);
                              try {
                                await ApiClient.dio.post(
                                  ApiEndpoints.callReview(widget.callId),
                                  data: {
                                    'rating': rating.toInt(),
                                    if (commentCtrl.text.trim().isNotEmpty)
                                      'comment': commentCtrl.text.trim(),
                                  },
                                );
                                if (mounted) {
                                  AppSnackBar.success(
                                      context, 'Thanks for your feedback!');
                                }
                              } catch (_) {}
                              if (mounted) context.go('/home');
                            },
                    ),
                  ),
                ],
              ),
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
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_status != CallStatus.connected) {
          _endCall();
          return;
        }
        _showEndCallConfirm();
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.isVideo ? _buildVideoUI() : _buildAudioUI(),
            if (_lowBalance) _buildLowBalanceBanner(),
            _buildGiftToast(),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('End Call'),
          ),
        ],
      ),
    );
    if (end == true) _endCall();
  }

  Widget _buildGiftToast() {
    return Positioned(
      bottom: 120, left: 0, right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _giftOverlayVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
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
    final engine      = _agora.engine;
    final remoteUid   = _agora.remoteUid;
    final channelName = _agora.channelName;

    return Stack(
      children: [
        // Remote video (full-screen)
        Positioned.fill(
          child: _status == CallStatus.connected &&
                  engine != null &&
                  remoteUid != null &&
                  channelName != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: remoteUid),
                    connection: RtcConnection(channelId: channelName),
                  ),
                )
              : Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
        ),

        // Local preview (picture-in-picture)
        if (_status == CallStatus.connected && !_isCameraOff && engine != null)
          Positioned(
            top: 60, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100, height: 140,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: engine,
                    canvas: const VideoCanvas(uid: 0), // 0 = local
                  ),
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
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(width: 8),
                      Text('Connecting...'),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Column(
              children: [
                if (_status == CallStatus.connected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_timeDisplay  •  ₹${_cost.toStringAsFixed(2)}',
                      style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        isActive: _isMuted,
                        onTap: () {
                          _agora.setMuted(!_isMuted);
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
                          _agora.setCameraEnabled(_isCameraOff);
                          setState(() => _isCameraOff = !_isCameraOff);
                        },
                      ),
                      _ControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Flip',
                        isActive: false,
                        onTap: () async {
                          await _agora.switchCamera();
                          setState(() => _isFrontCamera = !_isFrontCamera);
                        },
                      ),
                      if (widget.isCaller)
                        _ControlButton(
                          icon: Icons.card_giftcard_rounded,
                          label: 'Gift',
                          isActive: false,
                          onTap: () => GiftPickerSheet.show(
                            context, ref,
                            hostId:   widget.host.id,
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
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Audio Call',
                      style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
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
                      color: AppColors.primary.withValues(alpha: 0.5), width: 3),
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8),
                  Text('Connecting...'),
                ],
              )
            else ...[
              Text(
                _timeDisplay,
                style: AppTextStyles.headingLarge.copyWith(color: AppColors.online),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${_cost.toStringAsFixed(2)} charged  •  ₹${_ratePerMin.toInt()}/min',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    isActive: _isMuted,
                    onTap: () {
                      _agora.setMuted(!_isMuted);
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
                      _agora.setSpeaker(!_isSpeakerOn);
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                    },
                  ),
                  if (widget.isCaller)
                    _ControlButton(
                      icon: Icons.card_giftcard_rounded,
                      label: 'Gift',
                      isActive: false,
                      onTap: () => GiftPickerSheet.show(
                        context, ref,
                        hostId:   widget.host.id,
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
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
                  color: isActive ? AppColors.primary : Colors.white24),
            ),
            child: Icon(icon,
                color: isActive ? AppColors.primary : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
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
                ? AppTextStyles.headingSmall.copyWith(color: AppColors.primary)
                : AppTextStyles.labelLarge,
          ),
        ],
      ),
    );
  }
}

enum CallStatus { connecting, connected }
