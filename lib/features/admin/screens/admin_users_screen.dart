import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/admin_models.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';
import '../widgets/admin_empty_state.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<AdminUser> _users = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _status = 'all'; // all | active | blocked

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
      _users = [];
    }
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{
        'page': _page,
        'limit': 20,
        if (_searchCtrl.text.trim().isNotEmpty) 'search': _searchCtrl.text.trim(),
        if (_status != 'all') 'status': _status,
      };
      final raw = await AdminApi.get(ApiEndpoints.adminUsers, queryParameters: params);
      final data = AdminApi.parseData(raw);
      final list = (data['users'] as List)
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _users = reset ? list : [..._users, ...list];
        _hasMore = list.length == 20;
        _page++;
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
      setState(() => _loading = false);
    }
  }

  Future<void> _showActions(AdminUser user) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _UserActionsSheet(
        user: user,
        onRefresh: () => _load(reset: true),
      ),
    );
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
              hintText: 'Search by name or phone…',
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
        // Filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['all', 'active', 'blocked'].map((s) {
              final selected = _status == s;
              return GestureDetector(
                onTap: () {
                  setState(() => _status = s);
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
                        color:
                            selected ? Colors.transparent : AppColors.border),
                  ),
                  child: Text(
                    s[0].toUpperCase() + s.substring(1),
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
            child: _users.isEmpty && !_hasMore
                ? const AdminEmptyState(
                    icon: Icons.people_outline_rounded,
                    message: 'No users found',
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _users.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _users.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2)),
                        );
                      }
                      final u = _users[i];
                      return _UserTile(
                          user: u, onTap: () => _showActions(u));
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onTap,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.cardLight,
              backgroundImage:
                  user.avatar != null ? NetworkImage(user.avatar!) : null,
              child: user.avatar == null
                  ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: AppTextStyles.labelLarge)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(user.name,
                            style: AppTextStyles.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (user.isHost)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Host',
                              style: AppTextStyles.caption
                                  .copyWith(color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.phone,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${user.walletBalance.toStringAsFixed(0)}',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.gold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? AppColors.online.withValues(alpha: 0.15)
                        : AppColors.callRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.isActive ? 'Active' : 'Blocked',
                    style: AppTextStyles.caption.copyWith(
                        color:
                            user.isActive ? AppColors.online : AppColors.callRed),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Actions bottom sheet ─────────────────────────────────────────────────────

class _UserActionsSheet extends StatefulWidget {
  final AdminUser user;
  final VoidCallback onRefresh;
  const _UserActionsSheet({required this.user, required this.onRefresh});

  @override
  State<_UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends State<_UserActionsSheet> {
  bool _loading = false;
  final _walletCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _walletCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus() async {
    final isBlocking = widget.user.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isBlocking ? 'Block User' : 'Unblock User',
          style: AppTextStyles.headingSmall,
        ),
        content: Text(
          isBlocking
              ? 'Block ${widget.user.name}? They won\'t be able to log in.'
              : 'Unblock ${widget.user.name}?',
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
              child: Text(
                isBlocking ? 'Block' : 'Unblock',
                style: AppTextStyles.labelLarge.copyWith(
                  color:
                      isBlocking ? AppColors.callRed : AppColors.online,
                ),
              )),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await AdminApi.patch(
        ApiEndpoints.adminUserStatus(widget.user.id),
        data: {'is_active': !widget.user.isActive},
      );
      if (mounted) {
        AppSnackBar.success(
          context,
          widget.user.isActive ? 'User blocked' : 'User unblocked',
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

  Future<void> _adjustWallet() async {
    final amount = double.tryParse(_walletCtrl.text.trim());
    if (amount == null) {
      AppSnackBar.error(context, 'Enter a valid amount');
      return;
    }
    setState(() => _loading = true);
    try {
      await AdminApi.post(
        ApiEndpoints.adminUserWallet(widget.user.id),
        data: {
          'amount': amount,
          'note': _noteCtrl.text.trim().isNotEmpty
              ? _noteCtrl.text.trim()
              : 'Admin adjustment',
        },
      );
      if (mounted) {
        AppSnackBar.success(context, 'Wallet adjusted');
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
          Text(widget.user.name, style: AppTextStyles.headingSmall),
          Text(widget.user.phone,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 20),

          // Block / Unblock
          _SheetButton(
            icon: widget.user.isActive
                ? Icons.block_rounded
                : Icons.check_circle_rounded,
            label: widget.user.isActive ? 'Block User' : 'Unblock User',
            color: widget.user.isActive ? AppColors.callRed : AppColors.online,
            loading: _loading,
            onTap: _toggleStatus,
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          Text('Adjust Wallet Balance', style: AppTextStyles.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [50, 100, 500, -50].map((amt) => GestureDetector(
              onTap: () =>
                  setState(() => _walletCtrl.text = amt.toString()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: amt > 0
                      ? AppColors.online.withValues(alpha: 0.12)
                      : AppColors.callRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: amt > 0
                        ? AppColors.online.withValues(alpha: 0.3)
                        : AppColors.callRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${amt > 0 ? '+' : ''}₹$amt',
                  style: AppTextStyles.caption.copyWith(
                    color: amt > 0 ? AppColors.online : AppColors.callRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _walletCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                signed: true, decimal: true),
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Amount (negative to deduct)',
              hintStyle:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              hintStyle:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SheetButton(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Apply Wallet Adjustment',
            color: AppColors.primary,
            loading: _loading,
            onTap: _adjustWallet,
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _SheetButton({
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
