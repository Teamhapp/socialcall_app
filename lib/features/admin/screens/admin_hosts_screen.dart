import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/admin_models.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';
import '../widgets/admin_empty_state.dart';

class AdminHostsScreen extends StatefulWidget {
  const AdminHostsScreen({super.key});

  @override
  State<AdminHostsScreen> createState() => _AdminHostsScreenState();
}

class _AdminHostsScreenState extends State<AdminHostsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<AdminHost> _hosts = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _filter = 'all'; // all | verified | unverified | online

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _hosts = [];
    }
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{
        'page': _page,
        'limit': 20,
        if (_searchCtrl.text.trim().isNotEmpty) 'search': _searchCtrl.text.trim(),
        if (_filter == 'verified') 'verified': 'true',
        if (_filter == 'unverified') 'verified': 'false',
        if (_filter == 'online') 'online': 'true',
      };
      final raw = await AdminApi.get(ApiEndpoints.adminHosts, queryParameters: params);
      final data = AdminApi.parseData(raw);
      final list = (data['hosts'] as List)
          .map((e) => AdminHost.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _hosts = reset ? list : [..._hosts, ...list];
        _hasMore = list.length == 20;
        _page++;
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: AppTextStyles.bodyMedium,
            onChanged: (_) => _load(reset: true),
            decoration: InputDecoration(
              hintText: 'Search hosts…',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textHint, size: 20),
              filled: true,
              fillColor: AppColors.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['all', 'verified', 'unverified', 'online'].map((f) {
              final selected = _filter == f;
              return GestureDetector(
                onTap: () {
                  setState(() => _filter = f);
                  _load(reset: true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.primaryGradient : null,
                    color: selected ? null : AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? Colors.transparent : AppColors.border),
                  ),
                  child: Text(
                    f[0].toUpperCase() + f.substring(1),
                    style: AppTextStyles.labelLarge.copyWith(
                        color: selected ? Colors.white : AppColors.textHint),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _load(reset: true),
            child: _hosts.isEmpty && !_hasMore
                ? const AdminEmptyState(
                    icon: Icons.headset_mic_outlined,
                    message: 'No hosts match this filter',
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _hosts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _hosts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2)),
                        );
                      }
                      final h = _hosts[i];
                      return GestureDetector(
                        onTap: () => _showActions(h),
                        child: _HostTile(host: h),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showActions(AdminHost host) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _HostActionsSheet(
        host: host,
        onRefresh: () => _load(reset: true),
      ),
    );
  }
}

class _HostTile extends StatelessWidget {
  final AdminHost host;
  const _HostTile({required this.host});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.cardLight,
                backgroundImage:
                    host.avatar != null ? NetworkImage(host.avatar!) : null,
                child: host.avatar == null
                    ? Text(host.name.isNotEmpty ? host.name[0].toUpperCase() : '?',
                        style: AppTextStyles.labelLarge)
                    : null,
              ),
              if (host.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(host.name,
                          style: AppTextStyles.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (host.isVerified)
                      const Icon(Icons.verified_rounded,
                          color: AppColors.primary, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.gold, size: 13),
                    const SizedBox(width: 3),
                    Text(host.rating.toStringAsFixed(1),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint)),
                    const SizedBox(width: 10),
                    Text('${host.totalCalls} calls',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${host.totalEarnings.toStringAsFixed(0)}',
                  style:
                      AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kycColor(host.kycStatus).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(host.kycStatus.replaceAll('_', ' '),
                    style: AppTextStyles.caption
                        .copyWith(color: _kycColor(host.kycStatus))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _kycColor(String s) {
    switch (s) {
      case 'approved':
        return AppColors.online;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.callRed;
      default:
        return AppColors.textHint;
    }
  }
}

// ── Host actions sheet ───────────────────────────────────────────────────────

class _HostActionsSheet extends StatefulWidget {
  final AdminHost host;
  final VoidCallback onRefresh;
  const _HostActionsSheet({required this.host, required this.onRefresh});

  @override
  State<_HostActionsSheet> createState() => _HostActionsSheetState();
}

class _HostActionsSheetState extends State<_HostActionsSheet> {
  bool _loading = false;
  final _daysCtrl = TextEditingController();

  @override
  void dispose() {
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleVerify() async {
    if (widget.host.isVerified) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Remove Verification', style: AppTextStyles.headingSmall),
          content: Text(
            'Remove verification badge from ${widget.host.name}?',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textHint))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Remove',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.callRed))),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() => _loading = true);
    try {
      await AdminApi.patch(
        ApiEndpoints.adminHostVerify(widget.host.id),
        data: {'is_verified': !widget.host.isVerified},
      );
      if (mounted) {
        AppSnackBar.success(
          context,
          widget.host.isVerified ? 'Host unverified' : 'Host verified',
        );
        Navigator.pop(context);
        widget.onRefresh();
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _promote() async {
    final days = int.tryParse(_daysCtrl.text.trim());
    if (days == null || days < 1) {
      AppSnackBar.error(context, 'Enter valid number of days');
      return;
    }
    setState(() => _loading = true);
    try {
      await AdminApi.patch(
        ApiEndpoints.adminHostPromote(widget.host.id),
        data: {'days': days},
      );
      if (mounted) {
        AppSnackBar.success(context, 'Host promoted for $days days');
        Navigator.pop(context);
        widget.onRefresh();
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _demote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove Promotion', style: AppTextStyles.headingSmall),
        content: Text(
          'Remove promotion from ${widget.host.name}? This takes effect immediately.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.warning))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await AdminApi.patch(ApiEndpoints.adminHostDemote(widget.host.id));
      if (mounted) {
        AppSnackBar.success(context, 'Host promotion removed');
        Navigator.pop(context);
        widget.onRefresh();
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(widget.host.name, style: AppTextStyles.headingSmall),
          Text(
            '${widget.host.totalCalls} calls · ₹${widget.host.totalEarnings.toStringAsFixed(0)} earned',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 20),
          _SheetBtn(
            icon: widget.host.isVerified
                ? Icons.remove_circle_outline_rounded
                : Icons.verified_rounded,
            label: widget.host.isVerified ? 'Remove Verification' : 'Verify Host',
            color: widget.host.isVerified ? AppColors.textHint : AppColors.primary,
            loading: _loading,
            onTap: _toggleVerify,
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          Text('Promote Host', style: AppTextStyles.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [7, 30, 90].map((d) => GestureDetector(
              onTap: () =>
                  setState(() => _daysCtrl.text = d.toString()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$d days',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Number of days',
                    hintStyle: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _loading ? null : _promote,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Promote',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SheetBtn(
            icon: Icons.trending_down_rounded,
            label: 'Remove Promotion',
            color: AppColors.warning,
            loading: _loading,
            onTap: _demote,
          ),
        ],
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _SheetBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: AppTextStyles.labelLarge.copyWith(color: color)),
            const Spacer(),
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
