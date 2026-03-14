import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GiftPickerSheet
//
// A modal bottom sheet that:
//   1. Fetches the gift catalogue from GET /api/wallet/gifts
//   2. Displays emoji gift tiles with name + price
//   3. On selection: calls POST /api/wallet/gift, refreshes wallet balance
//
// Usage:
//   await GiftPickerSheet.show(context, ref, hostId: host.id);
// ─────────────────────────────────────────────────────────────────────────────

class GiftPickerSheet extends ConsumerStatefulWidget {
  final String hostId;
  final String hostName;

  const GiftPickerSheet({
    super.key,
    required this.hostId,
    required this.hostName,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String hostId,
    required String hostName,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GiftPickerSheet(hostId: hostId, hostName: hostName),
    );
  }

  @override
  ConsumerState<GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends ConsumerState<GiftPickerSheet> {
  List<Map<String, dynamic>> _gifts = [];
  bool _loading = true;
  String? _sendingGiftId;
  String? _lastSentGiftName;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final resp = await ApiClient.dio.get(ApiEndpoints.gifts);
      final raw = ApiClient.parseData(resp) as List? ?? [];
      if (mounted) {
        setState(() {
          _gifts = raw.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendGift(Map<String, dynamic> gift) async {
    if (_sendingGiftId != null) return;
    final giftId = gift['id'].toString();
    setState(() => _sendingGiftId = giftId);

    try {
      await ApiClient.dio.post(ApiEndpoints.sendGift, data: {
        'hostId': widget.hostId,
        'giftId': giftId,
      });

      // Refresh wallet balance so the UI immediately reflects the deduction.
      await ref.read(authProvider.notifier).refreshBalance();

      if (mounted) {
        setState(() {
          _sendingGiftId = null;
          _lastSentGiftName = '${gift['emoji'] ?? '🎁'} ${gift['name']}';
        });
        // Show brief success then dismiss.
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, gift);
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _sendingGiftId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(e)),
            backgroundColor: AppColors.callRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(authProvider).user?.walletBalance ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Send a gift to ${widget.hostName}',
                  style: AppTextStyles.headingSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹${balance.toStringAsFixed(0)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Host receives 65% of each gift',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Sent success indicator
          if (_lastSentGiftName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.callGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.callGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.callGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_lastSentGiftName sent!',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.callGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Gift grid
          _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _gifts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text('No gifts available',
                          style: AppTextStyles.bodyMedium),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _gifts.length,
                      itemBuilder: (_, i) {
                        final g = _gifts[i];
                        final price = double.tryParse(
                                g['price'].toString()) ??
                            0.0;
                        final isSending =
                            _sendingGiftId == g['id'].toString();
                        final canAfford = balance >= price;

                        return GestureDetector(
                          onTap: (canAfford && _sendingGiftId == null)
                              ? () => _sendGift(g)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: canAfford
                                  ? AppColors.card
                                  : AppColors.card
                                      .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSending
                                    ? AppColors.primary
                                    : AppColors.border
                                        .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                if (isSending)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                else
                                  Text(
                                    g['emoji'] ?? '🎁',
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  g['name'] ?? '',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: canAfford
                                        ? AppColors.textSecondary
                                        : AppColors.textHint,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '₹${price.toInt()}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: canAfford
                                        ? AppColors.primary
                                        : AppColors.textHint,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
