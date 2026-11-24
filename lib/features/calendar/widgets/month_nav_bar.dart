import 'package:flutter/material.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_pressable.dart';

/// The arrows step one month; the name in the middle opens the jump picker.
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
    return Row(
      children: [
        PixelIconButton(
          icon: PixelIcons.left,
          label: 'Previous month',
          sfx: AppSfx.tick,
          onPressed: onPrevious,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: PixelPressable(
            onPressed: onLabelTap,
            builder: (_, pressed) => Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: PixelRaised(pressed: pressed, shadow: 2),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ZingDateUtils.monthYearLabel(month),
                        style: AppTextStyles.button
                            .copyWith(color: AppColors.yellow),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const PixelIcon(PixelIcons.down, color: AppColors.yellow),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PixelIconButton(
          icon: PixelIcons.right,
          label: 'Next month',
          sfx: AppSfx.tick,
          onPressed: onNext,
        ),
      ],
    );
  }
}
