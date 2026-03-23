import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'admin_kyc_screen.dart';
import 'admin_offers_screen.dart';
import 'admin_promos_screen.dart';
import 'admin_reviews_screen.dart';
import 'admin_push_screen.dart';
import 'admin_wallet_bonus_screen.dart';

class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  static const _items = [
    (
      icon: Icons.verified_user_rounded,
      label: 'KYC Review',
      subtitle: 'Approve or reject identity documents',
      color: AppColors.primary,
    ),
    (
      icon: Icons.local_offer_rounded,
      label: 'Promo Codes',
      subtitle: 'Create and manage discount codes',
      color: AppColors.accent,
    ),
    (
      icon: Icons.star_rounded,
      label: 'Reviews',
      subtitle: 'Moderate host reviews',
      color: AppColors.gold,
    ),
    (
      icon: Icons.notifications_active_rounded,
      label: 'Push Notifications',
      subtitle: 'Broadcast to users',
      color: AppColors.online,
    ),
    (
      icon: Icons.campaign_rounded,
      label: 'Offers & Deals',
      subtitle: 'Create time-limited deal banners',
      color: Color(0xFFFF9500),
    ),
    (
      icon: Icons.account_balance_wallet_rounded,
      label: 'Wallet Bonus',
      subtitle: 'Credit free coins to users',
      color: Color(0xFF7B61FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tools', style: AppTextStyles.headingMedium),
        const SizedBox(height: 16),
        ..._items.asMap().entries.map((e) {
          final item = e.value;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _screenFor(e.key)),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: AppTextStyles.bodyLarge),
                        const SizedBox(height: 2),
                        Text(item.subtitle,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textHint)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textHint, size: 22),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _screenFor(int index) {
    switch (index) {
      case 0:
        return const AdminKycScreen();
      case 1:
        return const AdminPromosScreen();
      case 2:
        return const AdminReviewsScreen();
      case 3:
        return const AdminPushScreen();
      case 4:
        return const AdminOffersScreen();
      case 5:
        return const AdminWalletBonusScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
