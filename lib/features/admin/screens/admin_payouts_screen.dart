import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/admin_models.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';
import '../widgets/admin_empty_state.dart';

class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _statuses = ['pending', 'processing', 'completed', 'failed'];

  final _lists = <String, List<AdminPayout>>{};
  final _loading = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
    for (final s in _statuses) {
      _load(s);
    }
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        final s = _statuses[_tabs.index];
        if (_lists[s] == null) _load(s);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load(String status) async {
    setState(() => _loading[status] = true);
    try {
      final raw = await AdminApi.get(ApiEndpoints.adminPayouts,
          queryParameters: {'status': status});
      final data = AdminApi.parseData(raw);
      final payouts = (data['payouts'] as List? ?? data as List? ?? [])
          .map((e) => AdminPayout.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _lists[status] = payouts;
        _loading[status] = false;
      });
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
      setState(() => _loading[status] = false);
    }
  }

  Future<void> _approve(AdminPayout p) async {
    final refCtrl = TextEditingController();
    final ref = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Approve Payout', style: AppTextStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₹${p.amount.toStringAsFixed(2)}',
                style: AppTextStyles.bodyMedium),
            Text('To: ${p.hostName}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textHint)),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Reference ID (optional)',
                hintStyle: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, refCtrl.text.trim()),
              child: Text('Approve',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.online))),
        ],
      ),
    );
    if (ref == null || !mounted) return;
    try {
      await AdminApi.patch(
        ApiEndpoints.adminPayout(p.id),
        data: {
          'status': 'completed',
          if (ref.isNotEmpty) 'reference_id': ref,
        },
      );
      if (mounted) {
        AppSnackBar.success(context, 'Payout approved');
        _load('pending');
        _load('completed');
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    }
  }

  Future<void> _reject(AdminPayout p) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Reject Payout', style: AppTextStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ₹${p.amount.toStringAsFixed(2)} for ${p.hostName}?',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              style: AppTextStyles.bodyMedium,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Rejection reason',
                hintStyle: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Reject',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.callRed))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (notesCtrl.text.trim().isEmpty) {
      AppSnackBar.error(context, 'Please provide a rejection reason');
      return;
    }
    try {
      await AdminApi.patch(
        ApiEndpoints.adminPayout(p.id),
        data: {
          'status': 'failed',
          'notes': notesCtrl.text.trim(),
        },
      );
      if (mounted) {
        AppSnackBar.success(context, 'Payout rejected');
        _load('pending');
        _load('failed');
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    }
  }

  Widget _buildTabSkeleton() => Shimmer.fromColors(
        baseColor: AppColors.card,
        highlightColor: AppColors.cardLight,
        child: ListView.builder(
          itemCount: 4,
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, _) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: AppTextStyles.labelLarge,
          unselectedLabelStyle:
              AppTextStyles.labelLarge.copyWith(color: AppColors.textHint),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppColors.border,
          tabs: _statuses
              .map((s) => Tab(text: s[0].toUpperCase() + s.substring(1)))
              .toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) {
              if (_loading[s] == true) {
                return _buildTabSkeleton();
              }
              final list = _lists[s] ?? [];
              if (list.isEmpty) {
                return AdminEmptyState(
                    icon: Icons.payments_outlined,
                    message: 'No $s payouts');
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => _load(s),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _PayoutCard(
                    payout: list[i],
                    onApprove: s == 'pending' ? () => _approve(list[i]) : null,
                    onReject: s == 'pending' ? () => _reject(list[i]) : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PayoutCard extends StatelessWidget {
  final AdminPayout payout;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _PayoutCard({
    required this.payout,
    this.onApprove,
    this.onReject,
  });

  Color get _statusColor {
    switch (payout.status) {
      case 'completed':
        return AppColors.online;
      case 'pending':
        return AppColors.warning;
      case 'failed':
        return AppColors.callRed;
      default:
        return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(payout.hostName,
                    style: AppTextStyles.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(payout.status,
                    style: AppTextStyles.caption
                        .copyWith(color: _statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.currency_rupee_rounded,
                  color: AppColors.gold, size: 16),
              Text(payout.amount.toStringAsFixed(2),
                  style: AppTextStyles.headingSmall
                      .copyWith(color: AppColors.gold)),
            ],
          ),
          if (payout.upiId != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(payout.upiId!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _formatDate(payout.requestedAt),
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
          if (payout.notes != null) ...[
            const SizedBox(height: 4),
            Text(payout.notes!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onReject != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: onReject,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              AppColors.callRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.callRed
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text('Reject',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: AppColors.callRed)),
                        ),
                      ),
                    ),
                  ),
                if (onApprove != null && onReject != null)
                  const SizedBox(width: 10),
                if (onApprove != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: onApprove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('Approve',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
