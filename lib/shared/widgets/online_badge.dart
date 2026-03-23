import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class OnlineBadge extends StatefulWidget {
  final bool isOnline;
  final bool showLabel;

  const OnlineBadge({super.key, required this.isOnline, this.showLabel = false});

  @override
  State<OnlineBadge> createState() => _OnlineBadgeState();
}

class _OnlineBadgeState extends State<OnlineBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.isOnline) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(OnlineBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isOnline && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.offline,
              shape: BoxShape.circle,
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(width: 4),
            Text('Offline',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.offline)),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple ring
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => Container(
                  width: 14 * _pulse.value,
                  height: 14 * _pulse.value,
                  decoration: BoxDecoration(
                    color: AppColors.online
                        .withValues(alpha: (1 - _pulse.value) * 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Core dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.online.withValues(alpha: 0.7),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 4),
          Text('Online',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.online)),
        ],
      ],
    );
  }
}
