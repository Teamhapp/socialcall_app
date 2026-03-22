import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// A row of 3 tappable gender tiles: Male / Female / Other.
/// Tapping the already-selected tile deselects it (calls onChanged with null).
class GenderPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const GenderPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _options = [
    (value: 'male',   label: 'Male',   emoji: '👨'),
    (value: 'female', label: 'Female', emoji: '👩'),
    (value: 'other',  label: 'Other',  emoji: '⚧'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final isSelected = selected == opt.value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(isSelected ? null : opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(opt.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    opt.label,
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
