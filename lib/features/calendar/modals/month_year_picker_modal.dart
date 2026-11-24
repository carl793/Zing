import 'package:flutter/material.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';

/// "JUMP TO MONTH" — resolves to the first day (UTC) of the chosen month.
class MonthYearPickerModal extends StatefulWidget {
  final DateTime initial;
  const MonthYearPickerModal({super.key, required this.initial});

  @override
  State<MonthYearPickerModal> createState() => _MonthYearPickerModalState();
}

class _MonthYearPickerModalState extends State<MonthYearPickerModal> {
  static const int _minYear = 2000;
  static const int _maxYear = 2100;

  late int _year = widget.initial.year;

  Widget _arrow(PixelIcons icon, String label, int delta) {
    final next = _year + delta;
    return PixelIconButton(
      icon: icon,
      label: label,
      sfx: AppSfx.tick,
      onPressed: next < _minYear || next > _maxYear
          ? null
          : () => setState(() => _year = next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PixelModalShell(
      title: 'JUMP TO MONTH',
      icon: PixelIcons.calendar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _arrow(PixelIcons.left, 'Previous year', -1),
              Text('$_year', style: AppTextStyles.display),
              _arrow(PixelIcons.right, 'Next year', 1),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.9,
            children: [
              for (var month = 1; month <= 12; month++)
                PixelChip(
                  label: ZingDateUtils.monthAbbr(month),
                  selected: _year == widget.initial.year &&
                      month == widget.initial.month,
                  onTap: () => Navigator.of(context)
                      .pop(ZingDateUtils.day(_year, month, 1)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
