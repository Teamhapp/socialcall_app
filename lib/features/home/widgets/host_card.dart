import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';
import '../../../shared/widgets/online_badge.dart';

class HostCard extends StatelessWidget {
  final HostModel host;
  const HostCard({super.key, required this.host});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/host/${host.id}', extra: host),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.card,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Avatar image
            Positioned.fill(
              child: host.avatar != null
                  ? Image.network(
                      host.avatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.cardLight,
                        child: const Icon(Icons.person_rounded,
                            size: 60, color: AppColors.textHint),
                      ),
                    )
                  : Container(
                      color: AppColors.cardLight,
                      child: const Icon(Icons.person_rounded,
                          size: 60, color: AppColors.textHint),
                    ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.hostCardGradient,
                ),
              ),
            ),

            // Verified badge
            if (host.isVerified)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: Colors.white, size: 12),
                ),
              ),

            // Online badge
            Positioned(
              top: 10,
              left: 10,
              child: OnlineBadge(isOnline: host.isOnline),
            ),

            // Info at bottom
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      host.name,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.gold, size: 12),
                        const SizedBox(width: 2),
                        Text(host.rating.toStringAsFixed(1),
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.gold)),
                        const Spacer(),
                        Text('₹${host.audioRatePerMin.toInt()}/min',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primaryLight)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Language chips
                    Wrap(
                      spacing: 4,
                      children: host.languages.take(2).map((lang) =>
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(lang,
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 9)),
                        ),
                      ).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Quick call button
            Positioned(
              right: 8, bottom: 48,
              child: GestureDetector(
                onTap: () => context.push('/host/${host.id}', extra: host),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
