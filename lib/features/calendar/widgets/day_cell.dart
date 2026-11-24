import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_pressable.dart';
import '../controllers/calendar_controller.dart';

/// One calendar tile. Days that hold something stand out of the grid; the rest
/// lie flat in it.
class DayCell extends StatelessWidget {
  final int dayNumber;
  final DayVisual visual;
  final bool isToday;
  final int entryCount;
  final VoidCallback onTap;

  const DayCell({
    super.key,
    required this.dayNumber,
    required this.visual,
    required this.onTap,
    this.isToday = false,
    this.entryCount = 0,
  });

  /// How a kind of day looks: its block, or null to lie flat, and its mark.
  static (PixelTone?, PixelIcons?, Color) styleOf(DayVisual visual) =>
      switch (visual) {
        DayVisual.memory => (
            PixelTone.coral,
            PixelIcons.heart,
            PixelTone.coral.shade,
          ),
        DayVisual.nextVisit => (
            PixelTone.yellow,
            PixelIcons.star,
            PixelTone.yellow.shade,
          ),
        DayVisual.planned => (
            PixelTone.neutral,
            PixelIcons.clock,
            AppColors.yellow,
          ),
        DayVisual.unloggedPlan => (null, PixelIcons.clock, AppColors.faint),
        DayVisual.today || DayVisual.normal => (null, null, AppColors.gray),
      };

  @override
  Widget build(BuildContext context) {
    final (tone, icon, mark) = styleOf(visual);
    final number = tone?.text ?? (isToday ? AppColors.cyan : AppColors.gray);

    return PixelPressable(
      onPressed: onTap,
      semanticLabel: _spoken,
      builder: (_, pressed) => Container(
        decoration: tone == null
            ? PixelOutline(
                color: pressed
                    ? AppColors.yellow
                    : isToday
                        ? AppColors.cyan
                        : AppColors.ink,
                fill: const Color(0xFF232149),
              )
            : PixelRaised(
                tone: tone,
                depth: 3,
                shadow: 2,
                pressed: pressed,
                outline: isToday ? AppColors.cyan : AppColors.ink,
              ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: AppTextStyles.button.copyWith(
                    color: number,
                    height: 1.1,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PixelIcon(icon, color: mark, size: 10),
                      if (entryCount > 1) ...[
                        const SizedBox(width: 2),
                        PixelIcon(icon, color: mark, size: 10),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _spoken {
    final what = switch (visual) {
      DayVisual.memory => entryCount == 1 ? 'a memory' : '$entryCount memories',
      DayVisual.nextVisit => 'next visit',
      DayVisual.planned => 'planned',
      DayVisual.unloggedPlan => 'plan not logged',
      DayVisual.today || DayVisual.normal => null,
    };
    return [
      '$dayNumber',
      if (isToday) 'today',
      ?what,
    ].join(', ');
  }
}
