import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pixel_panel.dart';

/// Days, hours and minutes on three carved counters.
class CountdownDigits extends StatelessWidget {
  final Duration left;
  const CountdownDigits(this.left, {super.key});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Semantics(
      label: '${left.inDays} days, ${left.inHours % 24} hours and '
          '${left.inMinutes % 60} minutes left',
      child: ExcludeSemantics(
        child: Row(
          children: [
            _digits('${left.inDays}', 'DAYS'),
            const SizedBox(width: AppSpacing.sm),
            _digits(two(left.inHours % 24), 'HOURS'),
            const SizedBox(width: AppSpacing.sm),
            _digits(two(left.inMinutes % 60), 'MINS'),
          ],
        ),
      ),
    );
  }

  Widget _digits(String value, String unit) => Expanded(
        child: PixelWell(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: AppTextStyles.display),
              ),
              const SizedBox(height: 4),
              Text(unit, style: AppTextStyles.caption),
            ],
          ),
        ),
      );
}
