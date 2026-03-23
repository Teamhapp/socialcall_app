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

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _statuses = ['pending', 'approved', 'rejected'];

  final _lists = <String, List<AdminKyc>>{};
  final _loading = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
    _load('pending');
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
      final raw = await AdminApi.get(ApiEndpoints.adminKyc,
          queryParameters: {'status': status});
      final data = AdminApi.parseData(raw);
      final list = (data['kyc'] as List? ?? data as List? ?? [])
          .map((e) => AdminKyc.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _lists[status] = list;
        _loading[status] = false;
      });
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
      setState(() => _loading[status] = false);
    }
  }

  Future<void> _approve(AdminKyc kyc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Approve KYC', style: AppTextStyles.headingSmall),
        content: Text('Approve KYC for ${kyc.hostName}?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Approve',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.online))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await AdminApi.patch(ApiEndpoints.adminKycApprove(kyc.id));
      if (mounted) {
        AppSnackBar.success(context, 'KYC approved');
        _load('pending');
        _load('approved');
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    }
  }

  Future<void> _reject(AdminKyc kyc) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Reject KYC', style: AppTextStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject KYC for ${kyc.hostName}?',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
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
    try {
      await AdminApi.patch(
        ApiEndpoints.adminKycReject(kyc.id),
        data: {'reason': reasonCtrl.text.trim()},
      );
      if (mounted) {
        AppSnackBar.success(context, 'KYC rejected');
        _load('pending');
        _load('rejected');
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    }
  }

  void _viewImages(AdminKyc kyc) {
    final images = [
      if (kyc.frontUrl != null) ('Front', kyc.frontUrl!),
      if (kyc.backUrl != null) ('Back', kyc.backUrl!),
      if (kyc.selfieUrl != null) ('Selfie', kyc.selfieUrl!),
    ];
    if (images.isEmpty) {
      AppSnackBar.info(context, 'No images available');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('${kyc.hostName} — ${kyc.documentType}',
                style: AppTextStyles.headingSmall),
            const SizedBox(height: 16),
            ...images.map((img) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(img.$1,
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.textHint)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () =>
                          _openFullScreen(context, img.$2, img.$1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          img.$2,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Container(
                            height: 120,
                            color: AppColors.card,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  color: AppColors.textHint),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext ctx, String url, String label) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(label),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('KYC Review', style: AppTextStyles.headingSmall),
        bottom: TabBar(
          controller: _tabs,
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
      ),
      body: TabBarView(
        controller: _tabs,
        children: _statuses.map((s) {
          if (_loading[s] == true) {
            return _buildTabSkeleton();
          }
          final list = _lists[s] ?? [];
          if (list.isEmpty) {
            return AdminEmptyState(
                icon: Icons.verified_user_outlined,
                message: 'No $s KYC submissions');
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _load(s),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final kyc = list[i];
                return _KycCard(
                  kyc: kyc,
                  onViewImages: () => _viewImages(kyc),
                  onApprove: s == 'pending' ? () => _approve(kyc) : null,
                  onReject: s == 'pending' ? () => _reject(kyc) : null,
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _KycCard extends StatelessWidget {
  final AdminKyc kyc;
  final VoidCallback onViewImages;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _KycCard({
    required this.kyc,
    required this.onViewImages,
    this.onApprove,
    this.onReject,
  });

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
                child: Text(kyc.hostName,
                    style: AppTextStyles.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              TextButton.icon(
                onPressed: onViewImages,
                icon: const Icon(Icons.image_search_rounded,
                    size: 16, color: AppColors.primary),
                label: Text('View Docs',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(kyc.documentType,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: 8),
              Text(_formatDate(kyc.submittedAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint)),
            ],
          ),
          if (kyc.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text('Reason: ${kyc.rejectionReason}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.callRed)),
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
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.callRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.callRed.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                            child: Text('Reject',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.callRed))),
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
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                            child: Text('Approve',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: Colors.white))),
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
