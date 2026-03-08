import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../providers/incoming_call_provider.dart';
import '../router/app_router.dart';
import '../socket/socket_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../models/host_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IncomingCallOverlay
//
// Wrap your entire widget tree with this.  It watches [incomingCallProvider]
// and renders a full-screen dismissable overlay whenever an incoming call
// arrives — regardless of which screen the user is currently on.
// ─────────────────────────────────────────────────────────────────────────────

class IncomingCallOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const IncomingCallOverlay({super.key, required this.child});

  @override
  ConsumerState<IncomingCallOverlay> createState() =>
      _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  // Pulsing ring animation
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.16).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Accept ─────────────────────────────────────────────────────────────────

  Future<void> _accept(IncomingCallState cs) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      final resp =
          await ApiClient.dio.post(ApiEndpoints.callAccept(cs.callId!));
      final data = ApiClient.parseData(resp) as Map<String, dynamic>;
      final host =
          HostModel.fromJson(data['host'] as Map<String, dynamic>);

      ref.read(incomingCallProvider.notifier).dismiss();

      // Navigate to the call screen using the GoRouter instance directly
      // so navigation works from any screen without needing a BuildContext.
      AppRouter.router.go('/call', extra: {
        'host': host,
        'isVideo': cs.isVideo,
        'callId': cs.callId,
        'isCaller': false,
      });
    } on DioException catch (e) {
      // If accept fails (e.g. caller already hung up), just dismiss
      final msg = ApiClient.errorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
      ref.read(incomingCallProvider.notifier).dismiss();
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  // ── Decline ────────────────────────────────────────────────────────────────

  void _decline(IncomingCallState cs) {
    SocketService.emit('call_declined', {'callId': cs.callId});
    ref.read(incomingCallProvider.notifier).dismiss();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(incomingCallProvider);

    return Stack(
      children: [
        widget.child,
        // Slide-and-fade transition for the overlay
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: cs.hasCall
              ? _OverlaySheet(
                  key: const ValueKey('ic-active'),
                  cs: cs,
                  pulseAnim: _pulseAnim,
                  isAccepting: _isAccepting,
                  onAccept: () => _accept(cs),
                  onDecline: () => _decline(cs),
                )
              : const SizedBox.shrink(key: ValueKey('ic-idle')),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay Sheet UI
// ─────────────────────────────────────────────────────────────────────────────

class _OverlaySheet extends StatelessWidget {
  final IncomingCallState cs;
  final Animation<double> pulseAnim;
  final bool isAccepting;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OverlaySheet({
    super.key,
    required this.cs,
    required this.pulseAnim,
    required this.isAccepting,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.78),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.45),
                    blurRadius: 70,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Pulsing Avatar ──────────────────────────────────────
                  ScaleTransition(
                    scale: pulseAnim,
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.55),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 32,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundImage: cs.callerAvatar != null
                            ? NetworkImage(cs.callerAvatar!)
                            : null,
                        backgroundColor: AppColors.card,
                        child: cs.callerAvatar == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 52,
                                color: AppColors.textHint,
                              )
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Labels ─────────────────────────────────────────────
                  Text(
                    'INCOMING CALL',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cs.callerName,
                    style: AppTextStyles.headingLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cs.isVideo
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cs.isVideo ? 'Video Call' : 'Audio Call',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // ── Action buttons ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionBtn(
                        icon: Icons.call_end_rounded,
                        color: AppColors.callRed,
                        label: 'Decline',
                        onTap: onDecline,
                      ),
                      _ActionBtn(
                        icon: cs.isVideo
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: AppColors.callGreen,
                        label: isAccepting ? 'Connecting…' : 'Accept',
                        onTap: isAccepting ? null : onAccept,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: active ? color : color.withOpacity(0.35),
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: active
                ? Icon(icon, color: Colors.white, size: 30)
                : const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
