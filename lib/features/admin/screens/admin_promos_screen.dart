import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../models/admin_models.dart';
import '../services/admin_api.dart';
import '../../../core/api/api_endpoints.dart';
import '../widgets/admin_empty_state.dart';

class AdminPromosScreen extends StatefulWidget {
  const AdminPromosScreen({super.key});

  @override
  State<AdminPromosScreen> createState() => _AdminPromosScreenState();
}

class _AdminPromosScreenState extends State<AdminPromosScreen> {
  List<AdminPromo> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await AdminApi.get(ApiEndpoints.adminPromos);
      final data = AdminApi.parseData(raw);
      final list = (data['codes'] as List? ?? data as List? ?? [])
          .map((e) => AdminPromo.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _promos = list; _loading = false; });
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
      setState(() => _loading = false);
    }
  }

  Future<void> _deactivate(AdminPromo promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Deactivate Code', style: AppTextStyles.headingSmall),
        content: Text('Deactivate "${promo.code}"?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Deactivate',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.callRed))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await AdminApi.patch(ApiEndpoints.adminPromoDeactivate(promo.id));
      if (mounted) {
        AppSnackBar.success(context, 'Promo deactivated');
        _load();
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    }
  }

  void _showCreateDialog() {
    final codeCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final maxUsesCtrl = TextEditingController();
    DateTime? expiresAt;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx2).viewInsets.bottom + 24),
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
              Text('Create Promo Code', style: AppTextStyles.headingSmall),
              const SizedBox(height: 20),
              _FieldLabel('Code'),
              _Input(ctrl: codeCtrl, hint: 'e.g. WELCOME50'),
              const SizedBox(height: 12),
              _FieldLabel('Amount (₹)'),
              _Input(ctrl: amountCtrl, hint: '50', numeric: true),
              const SizedBox(height: 12),
              _FieldLabel('Max Uses'),
              _Input(ctrl: maxUsesCtrl, hint: '100', numeric: true),
              const SizedBox(height: 12),
              _FieldLabel('Expires At (optional)'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx2,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx3, child) => Theme(
                      data: ThemeData.dark(),
                      child: child!,
                    ),
                  );
                  if (picked != null) setLocal(() => expiresAt = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.textHint, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        expiresAt != null
                            ? '${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'
                            : 'Pick a date',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: expiresAt != null
                                ? AppColors.textPrimary
                                : AppColors.textHint),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Create Code',
                onTap: () async {
                  final code = codeCtrl.text.trim();
                  final amount = double.tryParse(amountCtrl.text.trim());
                  final maxUses = int.tryParse(maxUsesCtrl.text.trim());
                  if (code.isEmpty || amount == null || maxUses == null) {
                    AppSnackBar.error(ctx2, 'Fill all required fields');
                    return;
                  }
                  try {
                    await AdminApi.post(
                      ApiEndpoints.adminPromos,
                      data: {
                        'code': code.toUpperCase(),
                        'amount': amount,
                        'max_uses': maxUses,
                        if (expiresAt != null)
                          'expires_at': expiresAt!.toIso8601String(),
                      },
                    );
                    if (ctx2.mounted) Navigator.pop(ctx2);
                    if (mounted) {
                      AppSnackBar.success(context, 'Promo code created');
                      _load();
                    }
                  } on DioException catch (e) {
                    if (ctx2.mounted) {
                      AppSnackBar.error(ctx2, AdminApi.errorMessage(e));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Promo Codes', style: AppTextStyles.headingSmall),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _promos.isEmpty
                  ? const AdminEmptyState(
                      icon: Icons.local_offer_outlined,
                      message: 'No promo codes yet.\nTap + to create one.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _promos.length,
                      itemBuilder: (_, i) {
                        final p = _promos[i];
                        return _PromoTile(
                          promo: p,
                          onDeactivate:
                              p.isActive ? () => _deactivate(p) : null,
                        );
                      },
                    ),
            ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  final AdminPromo promo;
  final VoidCallback? onDeactivate;
  const _PromoTile({required this.promo, this.onDeactivate});

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: promo.isActive
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(promo.code,
                style: AppTextStyles.labelLarge.copyWith(
                    color: promo.isActive
                        ? AppColors.primary
                        : AppColors.textHint,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${promo.amount.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.gold)),
                Text('${promo.usedCount}/${promo.maxUses} used',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint)),
                if (promo.expiresAt != null)
                  Text(
                    _formatDate(promo.expiresAt!),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint),
                  ),
              ],
            ),
          ),
          if (onDeactivate != null)
            IconButton(
              icon: const Icon(Icons.block_rounded,
                  color: AppColors.callRed, size: 20),
              onPressed: onDeactivate,
              tooltip: 'Deactivate',
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Inactive',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint)),
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return 'Expires ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                AppTextStyles.labelLarge.copyWith(color: AppColors.textHint)),
      );
}

class _Input extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool numeric;
  const _Input({required this.ctrl, required this.hint, this.numeric = false});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        style: AppTextStyles.bodyMedium,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
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
      );
}
