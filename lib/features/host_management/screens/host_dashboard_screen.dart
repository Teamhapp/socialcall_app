import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/gradient_button.dart';
// ignore: unused_import
import 'kyc_screen.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  Map<String, dynamic>? _host;
  List<Map<String, dynamic>> _recentCalls = [];
  bool _isLoading = true;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final hostResp = await ApiClient.dio.get(ApiEndpoints.hostDashboard);
      final callsResp = await ApiClient.dio.get(
        ApiEndpoints.callHistoryHost,
        queryParameters: {'limit': 10},
      );
      if (mounted) {
        setState(() {
          _host = ApiClient.parseData(hostResp) as Map<String, dynamic>?;
          final rawCalls = ApiClient.parseData(callsResp);
          _recentCalls = (rawCalls as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnline() async {
    if (_host == null || _isTogglingStatus) return;
    final newStatus = !(_host!['is_online'] as bool? ?? false);
    setState(() => _isTogglingStatus = true);
    try {
      await ApiClient.dio.patch(
        ApiEndpoints.hostStatus,
        data: {'isOnline': newStatus},
      );
      setState(() {
        _host = {..._host!, 'is_online': newStatus};
      });
      // Emit socket event so home screen updates in real time
      if (newStatus) {
        SocketService.emit('host_went_online', {});
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  void _showEditProfileSheet() {
    final bioCtrl =
        TextEditingController(text: _host?['bio'] as String? ?? '');
    final audioCtrl = TextEditingController(
        text: (_host?['audio_rate_per_min'] as num?)?.toString() ?? '15');
    final videoCtrl = TextEditingController(
        text: (_host?['video_rate_per_min'] as num?)?.toString() ?? '40');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit Host Profile', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            Text('Bio', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(hintText: 'Tell callers about yourself...'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audio Rate (₹/min)', style: AppTextStyles.caption),
                      const SizedBox(height: 6),
                      TextField(
                        controller: audioCtrl,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.headingSmall
                            .copyWith(color: AppColors.primary),
                        decoration:
                            const InputDecoration(hintText: '15'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Video Rate (₹/min)', style: AppTextStyles.caption),
                      const SizedBox(height: 6),
                      TextField(
                        controller: videoCtrl,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.headingSmall
                            .copyWith(color: AppColors.primary),
                        decoration:
                            const InputDecoration(hintText: '40'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Save Changes',
              height: 50,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ApiClient.dio.put(
                    ApiEndpoints.hostProfile,
                    data: {
                      'bio': bioCtrl.text.trim(),
                      'audioRate': double.tryParse(audioCtrl.text) ?? 15,
                      'videoRate': double.tryParse(videoCtrl.text) ?? 40,
                    },
                  );
                  await _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to save')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
        ),
        title: Text('Host Dashboard', style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: _isLoading ? null : _showEditProfileSheet,
            color: AppColors.primary,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Profile header ───────────────────────────────────────
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: user?.avatar != null
                            ? NetworkImage(user!.avatar!) as ImageProvider
                            : null,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: user?.avatar == null
                            ? const Icon(Icons.person_rounded,
                                size: 36, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? 'Host',
                                style: AppTextStyles.headingMedium),
                            const SizedBox(height: 4),
                            RatingBarIndicator(
                              rating: (_host?['rating'] as num?)
                                      ?.toDouble() ??
                                  0,
                              itemSize: 14,
                              itemBuilder: (_, __) => const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.gold),
                            ),
                          ],
                        ),
                      ),
                      // Online toggle
                      _OnlineToggle(
                        isOnline:
                            _host?['is_online'] as bool? ?? false,
                        isLoading: _isTogglingStatus,
                        onToggle: _toggleOnline,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Stats row ────────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        label: 'Total Calls',
                        value:
                            '${_host?['total_calls'] ?? 0}',
                        icon: Icons.call_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Reviews',
                        value:
                            '${_host?['total_reviews'] ?? 0}',
                        icon: Icons.star_rounded,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Followers',
                        value:
                            '${_host?['followers_count'] ?? 0}',
                        icon: Icons.people_rounded,
                        color: AppColors.callGreen,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Earnings card ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.payments_rounded,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text('Your Earnings',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${(_host?['total_earnings'] as num? ?? 0).toStringAsFixed(2)}',
                              style: AppTextStyles.amount,
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Pending Payout',
                                    style: AppTextStyles.caption
                                        .copyWith(color: Colors.white60)),
                                Text(
                                  '₹${(_host?['pending_earnings'] as num? ?? 0).toStringAsFixed(2)}',
                                  style: AppTextStyles.labelLarge
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Audio Rate',
                                      style: AppTextStyles.caption
                                          .copyWith(color: Colors.white60)),
                                  Text(
                                    '₹${(_host?['audio_rate_per_min'] as num?)?.toInt() ?? 0}/min',
                                    style: AppTextStyles.labelLarge
                                        .copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Video Rate',
                                      style: AppTextStyles.caption
                                          .copyWith(color: Colors.white60)),
                                  Text(
                                    '₹${(_host?['video_rate_per_min'] as num?)?.toInt() ?? 0}/min',
                                    style: AppTextStyles.labelLarge
                                        .copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showPayoutDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.upload_rounded,
                                  size: 16),
                              label: const Text('Payout',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Recent calls ─────────────────────────────────────────
                  Row(
                    children: [
                      Text('Recent Calls', style: AppTextStyles.headingSmall),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/call-history'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_recentCalls.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No calls yet. Go online to start!',
                            style: AppTextStyles.bodyMedium),
                      ),
                    )
                  else
                    ..._recentCalls.take(5).map(
                          (call) => _HostCallTile(call: call),
                        ),

                  const SizedBox(height: 24),

                  // ── KYC Verification Banner ───────────────────────────
                  _KycBanner(
                    isVerified: _host?['is_verified'] as bool? ?? false,
                    kycStatus: _host?['kyc_status'] as String? ?? 'not_submitted',
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  void _showPayoutDialog() {
    final pendingAmount =
        (_host?['pending_earnings'] as num? ?? 0).toDouble();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Request Payout', style: AppTextStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pending: ₹${pendingAmount.toStringAsFixed(2)}',
              style: AppTextStyles.headingMedium
                  .copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'Payouts are processed within 3–5 business days. Minimum payout: ₹500.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final resp = await ApiClient.dio
                    .post(ApiEndpoints.hostPayout);
                final msg =
                    (resp.data as Map<String, dynamic>)['message']
                        as String? ??
                    'Payout request submitted!';
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
                await _load(); // refresh earnings display
              } on DioException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiClient.errorMessage(e))),
                  );
                }
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final bool isLoading;
  final VoidCallback onToggle;

  const _OnlineToggle({
    required this.isOnline,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOnline
              ? AppColors.callGreen.withOpacity(0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOnline
                ? AppColors.callGreen.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.callGreen),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppColors.callGreen
                          : AppColors.textHint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: AppTextStyles.caption.copyWith(
                      color: isOnline
                          ? AppColors.callGreen
                          : AppColors.textHint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.headingSmall.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _HostCallTile extends StatelessWidget {
  final Map<String, dynamic> call;
  const _HostCallTile({required this.call});

  @override
  Widget build(BuildContext context) {
    final isVideo = call['call_type'] == 'video';
    final duration = call['duration_seconds'] as int? ?? 0;
    final earnings =
        (call['host_earnings'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final callerName = call['caller_name'] as String? ?? 'Unknown';
    final callerAvatar = call['caller_avatar'] as String?;
    final createdAt = call['created_at'] != null
        ? DateTime.tryParse(call['created_at'] as String)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage:
                callerAvatar != null ? NetworkImage(callerAvatar) : null,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: callerAvatar == null
                ? const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(callerName, style: AppTextStyles.labelLarge),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      size: 13,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}',
                      style: AppTextStyles.bodySmall,
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM').format(createdAt),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+₹$earnings',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.callGreen),
              ),
              const SizedBox(height: 2),
              const Text('earned',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
                      fontFamily: 'Poppins')),
            ],
          ),
        ],
      ),
    );
  }
}

// ── KYC Banner ────────────────────────────────────────────────────────────────

class _KycBanner extends StatelessWidget {
  final bool isVerified;
  final String kycStatus;

  const _KycBanner({required this.isVerified, required this.kycStatus});

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.callGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.callGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.callGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Identity Verified',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.callGreen)),
                  Text('Your KYC is approved. Payouts are enabled.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Color bannerColor;
    IconData bannerIcon;
    String title;
    String subtitle;
    String buttonLabel;

    switch (kycStatus) {
      case 'pending':
        bannerColor = AppColors.warning;
        bannerIcon = Icons.hourglass_top_rounded;
        title = 'KYC Under Review';
        subtitle = 'Your documents are being reviewed. Usually done in 24h.';
        buttonLabel = 'Check Status';
      case 'rejected':
        bannerColor = AppColors.callRed;
        bannerIcon = Icons.cancel_rounded;
        title = 'KYC Rejected';
        subtitle = 'Your submission was rejected. Please resubmit with valid documents.';
        buttonLabel = 'Resubmit';
      default:
        bannerColor = AppColors.primary;
        bannerIcon = Icons.badge_rounded;
        title = 'Verify Your Identity';
        subtitle = 'Complete KYC to unlock payouts and get the verified badge.';
        buttonLabel = 'Start KYC';
    }

    return GestureDetector(
      onTap: () => context.push('/kyc'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(bannerIcon, color: bannerColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.labelLarge.copyWith(color: bannerColor)),
                  Text(subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                buttonLabel,
                style: AppTextStyles.caption.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
