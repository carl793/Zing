import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
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

  void _stepYear(int delta) {
    final next = _year + delta;
    if (next < _minYear || next > _maxYear) return;
    setState(() => _year = next);
  }

  @override
  Widget build(BuildContext context) {
    return PixelModalShell(
      title: 'JUMP TO MONTH',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _YearArrow(icon: Icons.chevron_left, onTap: () => _stepYear(-1)),
              const SizedBox(width: AppSpacing.lg),
              Text(
                '$_year',
                style: AppTextStyles.header.copyWith(
                  color: AppColors.yellow,
                  fontSize: 14,
                  shadows: const [
                    Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              _YearArrow(icon: Icons.chevron_right, onTap: () => _stepYear(1)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.1,
            children: List.generate(12, (i) {
              final month = i + 1;
              final active =
                  _year == widget.initial.year && month == widget.initial.month;
              return _MonthChip(
                label: ZingDateUtils.monthAbbr(month),
                active: active,
                onTap: () =>
                    Navigator.of(context).pop(ZingDateUtils.day(_year, month, 1)),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _YearArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _YearArrow({required this.icon, required this.onTap});

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

class _MonthChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _MonthChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.yellow : AppColors.charcoal,
          border: Border.all(
            color: active ? Colors.black : AppColors.cyan,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: 8,
            color: active ? Colors.black : AppColors.cyan,
          ),
        ),
      ),
    );
  }
}