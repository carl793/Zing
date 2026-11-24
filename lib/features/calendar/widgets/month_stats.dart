import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_panel.dart';

/// Three numbers: days together this month, since the last time, and until the
/// next.
class MonthStats extends StatelessWidget {
  final int daysTogether;
  final int? daysSince;
  final int? daysUntil;

  const MonthStats({
    super.key,
    required this.daysTogether,
    required this.daysSince,
    required this.daysUntil,
  });

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stat(PixelIcons.heart, AppColors.coral, '$daysTogether',
                'TOGETHER\nTHIS MONTH'),
            const SizedBox(width: AppSpacing.sm),
            _stat(PixelIcons.clock, AppColors.cyan, _days(daysSince),
                daysSince == 0 ? 'MET\nTODAY' : 'DAYS\nSINCE'),
            const SizedBox(width: AppSpacing.sm),
            _stat(PixelIcons.star, AppColors.yellow, _days(daysUntil),
                daysUntil == 0 ? 'IT IS\nTODAY!' : 'DAYS\nTO GO'),
          ],
        ),
      ),
    );
  }

  static String _days(int? days) => days == null ? '--' : '$days';

  Widget _stat(PixelIcons icon, Color color, String value, String label) =>
      Expanded(
        child: PixelWell(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            children: [
              PixelIcon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTextStyles.header.copyWith(color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      );
}
