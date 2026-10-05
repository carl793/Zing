import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_dashed_border.dart';
import '../controllers/calendar_controller.dart';

/// One calendar tile. Appearance is driven entirely by [visual].
class DayCell extends StatelessWidget {
  static const Color _memoryText = Color(0xFF3A0016);
  static const Color _memoryAccent = Color(0xFF7A0030);

  final int dayNumber;
  final DayVisual visual;
  final String? label;
  final int entryCount;
  final VoidCallback onTap;

  const DayCell({
    super.key,
    required this.dayNumber,
    required this.visual,
    required this.onTap,
    this.label,
    this.entryCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isMemory = visual == DayVisual.memory;

    final Color? dashedColor = switch (visual) {
      DayVisual.planned || DayVisual.nextVisit => AppColors.yellow,
      DayVisual.unloggedPlan => AppColors.gray,
      _ => null,
    };

    final Color borderColor = dashedColor != null
        ? Colors.transparent
        : (visual == DayVisual.today ? AppColors.cyan : Colors.black);

    Widget cell = Container(
      decoration: BoxDecoration(
        color: isMemory ? AppColors.coral : AppColors.purple,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$dayNumber',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 9,
                    color: isMemory ? _memoryText : Colors.white,
                  ),
                ),
                if (isMemory && label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 4, color: _memoryAccent),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(top: 2, right: 2, child: _badge()),
        ],
      ),
    );

    if (dashedColor != null) {
      cell = PixelDashedBorder(color: dashedColor, child: cell);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: cell,
    );
  }

  Widget _badge() {
    switch (visual) {
      case DayVisual.memory:
        return entryCount >= 2
            ? Text('x2',
                style: AppTextStyles.caption
                    .copyWith(fontSize: 5, color: _memoryAccent))
            : const Icon(Icons.favorite, size: 7, color: _memoryAccent);
      case DayVisual.nextVisit:
        return const Icon(Icons.star, size: 8, color: AppColors.yellow);
      case DayVisual.planned:
        return const Icon(Icons.schedule, size: 7, color: AppColors.yellow);
      case DayVisual.unloggedPlan:
        return const Icon(Icons.schedule, size: 7, color: AppColors.gray);
      case DayVisual.today:
      case DayVisual.normal:
        return const SizedBox.shrink();
    }
  }
}