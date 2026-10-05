import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';

/// ‹ SEPTEMBER 2026 ▾ › — arrows step one month, centre opens the jump picker.
class MonthNavBar extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLabelTap;

  const MonthNavBar({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onLabelTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          _ArrowButton(icon: Icons.chevron_left, onTap: onPrevious),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLabelTap,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ZingDateUtils.monthYearLabel(month),
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.yellow, fontSize: 9),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.yellow,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _ArrowButton(icon: Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Icon(icon, color: AppColors.cyan, size: 24),
      ),
    );
  }
}