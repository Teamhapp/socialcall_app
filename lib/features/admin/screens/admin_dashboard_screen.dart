import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/admin_models.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await AdminApi.get(ApiEndpoints.adminStats);
      final data = AdminApi.parseData(raw) as Map<String, dynamic>;
      setState(() { _stats = AdminStats.fromJson(data); _loading = false; });
    } on DioException catch (e) {
      setState(() { _error = AdminApi.errorMessage(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.callRed, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _load,
                          child: Text('Retry',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: AppColors.primary))),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Overview', style: AppTextStyles.headingMedium),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _StatCard(
                          label: 'Total Users',
                          value: _stats!.totalUsers.toString(),
                          icon: Icons.people_rounded,
                          gradient: AppColors.primaryGradient,
                        ),
                        _StatCard(
                          label: 'Hosts Online',
                          value: _stats!.hostsOnline.toString(),
                          icon: Icons.headset_mic_rounded,
                          color: AppColors.online,
                        ),
                        _StatCard(
                          label: 'Calls Today',
                          value: _stats!.callsToday.toString(),
                          icon: Icons.call_rounded,
                          color: AppColors.accent,
                        ),
                        _StatCard(
                          label: 'Revenue Today',
                          value: '₹${_stats!.revenueToday.toStringAsFixed(0)}',
                          icon: Icons.currency_rupee_rounded,
                          color: AppColors.gold,
                        ),
                        _StatCard(
                          label: 'Pending Payouts',
                          value: _stats!.pendingPayouts.toString(),
                          icon: Icons.payments_rounded,
                          color: _stats!.pendingPayouts > 0
                              ? AppColors.warning
                              : AppColors.textHint,
                        ),
                        _StatCard(
                          label: 'Pending KYC',
                          value: _stats!.pendingKyc.toString(),
                          icon: Icons.verified_user_rounded,
                          color: _stats!.pendingKyc > 0
                              ? AppColors.callRed
                              : AppColors.textHint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Platform Stats', style: AppTextStyles.headingMedium),
                    const SizedBox(height: 12),
                    _InfoRow('Total Hosts', _stats!.totalHosts.toString()),
                    _InfoRow('Total Calls', _stats!.totalCalls.toString()),
                    _InfoRow('Total Revenue',
                        '₹${_stats!.totalRevenue.toStringAsFixed(2)}'),
                    _InfoRow('Active Promos', _stats!.activePromos.toString()),
                    _InfoRow('Unverified Hosts',
                        _stats!.unverifiedHosts.toString()),
                    if (_stats!.pendingKyc > 0 ||
                        _stats!.pendingPayouts > 0) ...[
                      const SizedBox(height: 24),
                      Text('Needs Attention',
                          style: AppTextStyles.headingMedium),
                      const SizedBox(height: 12),
                      if (_stats!.pendingKyc > 0)
                        _ActionRow(
                          icon: Icons.verified_user_rounded,
                          color: AppColors.callRed,
                          label: 'KYC Reviews',
                          count: _stats!.pendingKyc,
                        ),
                      if (_stats!.pendingPayouts > 0)
                        _ActionRow(
                          icon: Icons.payments_rounded,
                          color: AppColors.warning,
                          label: 'Pending Payouts',
                          count: _stats!.pendingPayouts,
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient? gradient;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.gradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? color!.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 18,
                color: gradient != null ? Colors.white : (color ?? AppColors.primary)),
          ),
          const Spacer(),
          Text(value,
              style: AppTextStyles.headingMedium
                  .copyWith(color: color ?? AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          const Spacer(),
          Text(value,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _ActionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
