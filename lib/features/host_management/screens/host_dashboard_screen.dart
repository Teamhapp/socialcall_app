import 'dart:convert';
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
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoading = true;
  bool _isTogglingStatus = false;

  // PostgreSQL DECIMAL columns come back as strings from node-postgres.
  // This helper safely parses both String and num values.
  static double _d(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _hasPendingPayout =>
      _payouts.any((p) => p['status'] == 'pending');

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiClient.dio.get(ApiEndpoints.hostDashboard),
        ApiClient.dio.get(ApiEndpoints.callHistoryHost,
            queryParameters: {'limit': 10}),
        ApiClient.dio
            .get(ApiEndpoints.hostPayouts)
            .catchError((_) => null),
      ]);

      if (mounted) {
        setState(() {
          _host =
              ApiClient.parseData(results[0]) as Map<String, dynamic>?;
          final rawCalls = ApiClient.parseData(results[1]);
          _recentCalls = (rawCalls as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          if (results[2] != null) {
            final rawPayouts = ApiClient.parseData(results[2]);
            _payouts = (rawPayouts as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }
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
        text: _d(_host?['audio_rate_per_min'], 15).toInt().toString());
    final videoCtrl = TextEditingController(
        text: _d(_host?['video_rate_per_min'], 40).toInt().toString());

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
                              rating: _d(_host?['rating']),
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
                              '₹${_d(_host?['total_earnings']).toStringAsFixed(2)}',
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
                                  '₹${_d(_host?['pending_earnings']).toStringAsFixed(2)}',
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
                                    '₹${_d(_host?['audio_rate_per_min']).toInt()}/min',
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
                                    '₹${_d(_host?['video_rate_per_min']).toInt()}/min',
                                    style: AppTextStyles.labelLarge
                                        .copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _hasPendingPayout
                                  ? null
                                  : () => _showPayoutDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasPendingPayout
                                    ? Colors.white12
                                    : Colors.white24,
                                foregroundColor: Colors.white,
                                disabledForegroundColor:
                                    Colors.white54,
                                disabledBackgroundColor:
                                    Colors.white12,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                              icon: Icon(
                                _hasPendingPayout
                                    ? Icons.hourglass_top_rounded
                                    : Icons.upload_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _hasPendingPayout
                                    ? 'Pending'
                                    : 'Payout',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600),
                              ),
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
                        onPressed: () => context.push('/call-history'),
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

                  // ── Payout History ────────────────────────────────────
                  if (_payouts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Payout History',
                        style: AppTextStyles.headingSmall),
                    const SizedBox(height: 10),
                    ..._payouts.take(5).map(
                          (p) => _PayoutHistoryTile(payout: p),
                        ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  void _showPayoutDialog() {
    final pendingAmount = _d(_host?['pending_earnings']);
    final isVerified = _host?['is_verified'] as bool? ?? false;
    final kycStatus = _host?['kyc_status'] as String? ?? 'not_submitted';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PayoutBottomSheet(
        pendingAmount: pendingAmount,
        isVerified: isVerified,
        kycStatus: kycStatus,
        onSubmit: (method, details) async {
          final resp = await ApiClient.dio.post(
            ApiEndpoints.hostPayout,
            data: {'paymentMethod': method, 'paymentDetails': details},
          );
          final msg = (resp.data as Map<String, dynamic>)['message'] as String? ??
              'Payout request submitted!';
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
          await _load();
        },
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
    // host_earnings is DECIMAL in PostgreSQL → comes back as String from node-postgres
    final earningsVal = call['host_earnings'];
    final earnings = earningsVal == null
        ? '0.00'
        : (earningsVal is num ? earningsVal : double.tryParse(earningsVal.toString()) ?? 0.0)
            .toStringAsFixed(2);
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

// ── Payout Bottom Sheet ───────────────────────────────────────────────────────

class _PayoutBottomSheet extends StatefulWidget {
  final double pendingAmount;
  final bool isVerified;
  final String kycStatus;
  final Future<void> Function(String method, Map<String, String> details) onSubmit;

  const _PayoutBottomSheet({
    required this.pendingAmount,
    required this.isVerified,
    required this.kycStatus,
    required this.onSubmit,
  });

  @override
  State<_PayoutBottomSheet> createState() => _PayoutBottomSheetState();
}

class _PayoutBottomSheetState extends State<_PayoutBottomSheet> {
  String _method = 'upi';
  final _upiCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _upiCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    Map<String, String> details;
    if (_method == 'upi') {
      final upi = _upiCtrl.text.trim();
      if (upi.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please enter your UPI ID')));
        return;
      }
      details = {'upiId': upi};
    } else {
      final acc = _accountCtrl.text.trim();
      final ifsc = _ifscCtrl.text.trim().toUpperCase();
      final holder = _holderCtrl.text.trim();
      if (acc.isEmpty || ifsc.isEmpty || holder.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill all bank details')));
        return;
      }
      details = {'accountNumber': acc, 'ifsc': ifsc, 'accountHolder': holder};
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(_method, details);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Request Payout', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          Text(
            'Pending balance: ₹${widget.pendingAmount.toStringAsFixed(2)}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 20),

          // ── KYC not verified ──────────────────────────────────────────────
          if (!widget.isVerified) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.callRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.callRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      color: AppColors.callRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KYC Required',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.callRed)),
                        const SizedBox(height: 2),
                        Text(
                          widget.kycStatus == 'pending'
                              ? 'Your KYC is under review. Payouts unlock once approved.'
                              : 'Complete KYC verification to unlock payouts.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: widget.kycStatus == 'pending'
                  ? 'Check KYC Status'
                  : 'Complete KYC',
              height: 50,
              onTap: () {
                Navigator.pop(context);
                context.push('/kyc');
              },
            ),

          // ── Balance too low ───────────────────────────────────────────────
          ] else if (widget.pendingAmount < 500) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Minimum payout is ₹500. Keep earning to unlock withdrawal!',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

          // ── Payout form ───────────────────────────────────────────────────
          ] else ...[
            // Payment method selector
            Text('Payment Method', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                _MethodChip(
                  label: 'UPI',
                  icon: Icons.account_balance_wallet_rounded,
                  selected: _method == 'upi',
                  onTap: () => setState(() => _method = 'upi'),
                ),
                const SizedBox(width: 10),
                _MethodChip(
                  label: 'Bank Transfer',
                  icon: Icons.account_balance_rounded,
                  selected: _method == 'bank',
                  onTap: () => setState(() => _method = 'bank'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // UPI fields
            if (_method == 'upi') ...[
              Text('UPI ID', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              TextField(
                controller: _upiCtrl,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'yourname@upi',
                  prefixIcon:
                      Icon(Icons.alternate_email_rounded, size: 18),
                ),
              ),
            ],

            // Bank fields
            if (_method == 'bank') ...[
              Text('Account Holder Name', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              TextField(
                controller: _holderCtrl,
                style: AppTextStyles.bodyLarge,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(hintText: 'Full name as per bank'),
              ),
              const SizedBox(height: 12),
              Text('Account Number', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              TextField(
                controller: _accountCtrl,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyLarge,
                decoration:
                    const InputDecoration(hintText: 'Enter account number'),
              ),
              const SizedBox(height: 12),
              Text('IFSC Code', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              TextField(
                controller: _ifscCtrl,
                style: AppTextStyles.bodyLarge,
                textCapitalization: TextCapitalization.characters,
                decoration:
                    const InputDecoration(hintText: 'e.g. SBIN0001234'),
              ),
            ],

            const SizedBox(height: 8),
            Text('Processed within 3–5 business days.',
                style: AppTextStyles.caption),
            const SizedBox(height: 20),
            GradientButton(
              label:
                  'Request ₹${widget.pendingAmount.toStringAsFixed(2)}',
              height: 50,
              isLoading: _isSubmitting,
              onTap: _submit,
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payout History Tile ───────────────────────────────────────────────────────

class _PayoutHistoryTile extends StatelessWidget {
  final Map<String, dynamic> payout;
  const _PayoutHistoryTile({required this.payout});

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final status = payout['status'] as String? ?? 'pending';
    final amount = _d(payout['amount']);
    final requestedAt = payout['requested_at'] != null
        ? DateTime.tryParse(payout['requested_at'] as String)
        : null;
    final processedAt = payout['processed_at'] != null
        ? DateTime.tryParse(payout['processed_at'] as String)
        : null;
    final refId = payout['reference_id'] as String?;

    // Parse payment method from notes JSON string
    String paymentLabel = '';
    try {
      final raw = payout['notes'];
      final notes = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : (raw as Map<String, dynamic>? ?? {});
      if (notes['paymentMethod'] == 'upi') {
        paymentLabel = notes['upiId'] as String? ?? 'UPI';
      } else if (notes['paymentMethod'] == 'bank') {
        paymentLabel = notes['accountNumber'] as String? ?? 'Bank';
      }
    } catch (_) {}

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = AppColors.callGreen;
        statusIcon = Icons.check_circle_rounded;
      case 'rejected':
        statusColor = AppColors.callRed;
        statusIcon = Icons.cancel_rounded;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top_rounded;
    }

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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  paymentLabel.isNotEmpty ? paymentLabel : 'Payout',
                  style: AppTextStyles.caption,
                ),
                if (requestedAt != null)
                  Text(
                    'Requested ${DateFormat('dd MMM yyyy').format(requestedAt)}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (refId != null && refId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Ref: $refId',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint),
                ),
              ] else if (processedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM').format(processedAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint),
                ),
              ],
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
