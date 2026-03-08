import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final double height;
  final Widget? icon;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.height = 54,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Text(label, style: AppTextStyles.button),
                  ],
                ),
        ),
      ),
    );
  }
}
