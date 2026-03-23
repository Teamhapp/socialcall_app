import 'package:flutter/material.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../services/admin_api.dart';

class AdminWalletBonusScreen extends StatefulWidget {
  const AdminWalletBonusScreen({super.key});

  @override
  State<AdminWalletBonusScreen> createState() => _AdminWalletBonusScreenState();
}

class _AdminWalletBonusScreenState extends State<AdminWalletBonusScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _filter = 'all';
  bool _sending = false;

  static const _filters = [
    (value: 'all', label: 'All Users', icon: Icons.people_rounded,
     desc: 'All active users (excluding hosts)'),
    (value: 'active_week', label: 'Active This Week', icon: Icons.trending_up_rounded,
     desc: 'Users seen in the last 7 days'),
    (value: 'all_including_hosts', label: 'Everyone', icon: Icons.public_rounded,
     desc: 'All active users including hosts'),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppSnackBar.error(context, 'Enter a valid positive amount');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Confirm Bonus', style: AppTextStyles.headingSmall),
        content: Text(
          'Credit ₹${amount.toStringAsFixed(0)} to all matched users?\n\nFilter: $_filter',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Bonus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final res = await AdminApi.post(
        ApiEndpoints.adminWalletBonus,
        data: {
          'amount': amount,
          'note': _noteCtrl.text.trim().isEmpty
              ? null
              : _noteCtrl.text.trim(),
          'filter': _filter,
        },
      );
      final msg = res.data['message'] as String? ??
          'Bonus sent to ${res.data['count']} users';
      if (mounted) {
        AppSnackBar.success(context, msg);
        _amountCtrl.clear();
        _noteCtrl.clear();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, AdminApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Bonus'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFFFF4D79)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💰', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text('Bulk Wallet Bonus',
                    style: AppTextStyles.headingMedium
                        .copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  'Credit free coins to users matching a filter',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Target filter
          Text('Target Users', style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          ..._filters.map((f) => GestureDetector(
                onTap: () => setState(() => _filter = f.value),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _filter == f.value
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _filter == f.value
                          ? AppColors.primary
                          : AppColors.border,
                      width: _filter == f.value ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(f.icon,
                          color: _filter == f.value
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.label,
                                style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _filter == f.value
                                        ? AppColors.primary
                                        : AppColors.textPrimary)),
                            Text(f.desc,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      if (_filter == f.value)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 20),

          // Amount
          Text('Amount (₹)', style: AppTextStyles.headingSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.headingMedium
                .copyWith(color: AppColors.callGreen),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: AppTextStyles.headingMedium
                  .copyWith(color: AppColors.textHint),
              prefixText: '₹ ',
              prefixStyle: AppTextStyles.headingMedium
                  .copyWith(color: AppColors.callGreen),
            ),
          ),

          const SizedBox(height: 16),

          // Note
          Text('Note (optional)', style: AppTextStyles.headingSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Holi celebration bonus!',
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textHint),
            ),
          ),

          const SizedBox(height: 28),

          GradientButton(
            label: 'Send Bonus',
            height: 56,
            isLoading: _sending,
            icon: _sending
                ? null
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
            onTap: _sending ? null : _send,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
