import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class OnlineBadge extends StatelessWidget {
  final bool isOnline;
  final bool showLabel;

  const OnlineBadge({super.key, required this.isOnline, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? AppColors.online : AppColors.offline,
            shape: BoxShape.circle,
            boxShadow: isOnline
                ? [BoxShadow(color: AppColors.online.withOpacity(0.5), blurRadius: 4)]
                : null,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: AppTextStyles.caption.copyWith(
              color: isOnline ? AppColors.online : AppColors.offline,
            ),
          ),
        ],
      ],
    );
  }
}
