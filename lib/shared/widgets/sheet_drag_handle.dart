import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A reusable drag-handle pill shown at the top of every modal bottom sheet.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.textHint.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
