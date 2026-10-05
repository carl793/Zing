import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_dashed_border.dart';

class RecapStatsCard extends StatelessWidget {
  final int daysTogether;
  final int? daysSinceLastMeetup;
  final DateTime? nextMeetupDate;
  final int? daysUntilNextMeetup;

  const RecapStatsCard({
    super.key,
    required this.daysTogether,
    required this.daysSinceLastMeetup,
    required this.nextMeetupDate,
    required this.daysUntilNextMeetup,
  });

  String get _daysTogetherText =>
      'DAYS TOGETHER THIS MONTH: ${daysTogether.toString().padLeft(2, '0')} '
      '${daysTogether == 1 ? 'DAY' : 'DAYS'}';

  String get _lastMetUpText {
    final days = daysSinceLastMeetup;
    if (days == null) return 'LAST MET UP: --';
    if (days == 0) return 'LAST MET UP: TODAY';
    return 'LAST MET UP: $days ${days == 1 ? 'DAY' : 'DAYS'} AGO';
  }

  String get _nextMeetupText {
    final date = nextMeetupDate;
    final left = daysUntilNextMeetup;
    if (date == null || left == null) return 'NEXT MEETUP: NONE SCHEDULED';
    final label =
        '${ZingDateUtils.monthAbbr(date.month)} ${date.day.toString().padLeft(2, '0')}';
    if (left == 0) return 'NEXT MEETUP: $label (TODAY)';
    return 'NEXT MEETUP: $label ($left ${left == 1 ? 'DAY' : 'DAYS'} LEFT)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY RECAP STATS',
            style: AppTextStyles.label.copyWith(color: AppColors.cyan, fontSize: 9),
          ),
          const SizedBox(height: AppSpacing.md),
          if (daysTogether == 0) _buildEmpty() else ..._buildStats(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const Icon(Icons.calendar_month, size: 26, color: AppColors.gray),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'NO MEMORIES LOGGED\nYET THIS MONTH.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.gray, height: 1.8),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStats() {
    return [
      _StatLine(icon: Icons.favorite, color: AppColors.coral, text: _daysTogetherText),
      const SizedBox(height: AppSpacing.sm),
      _StatLine(icon: Icons.history, color: AppColors.cyan, text: _lastMetUpText),
      const SizedBox(height: AppSpacing.sm),
      _StatLine(icon: Icons.star, color: AppColors.yellow, text: _nextMeetupText),
      const SizedBox(height: AppSpacing.md),
      const _DashedDivider(),
      const SizedBox(height: AppSpacing.sm),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _LegendItem(label: '= MET UP', dashed: false),
          _LegendItem(label: '= NEXT VISIT', dashed: true),
        ],
      ),
    ];
  }
}

class _StatLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatLine({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body
                .copyWith(fontSize: 7, color: Colors.white, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final bool dashed;
  const _LegendItem({required this.label, required this.dashed});

  @override
  Widget build(BuildContext context) {
    final swatch = dashed
        ? const PixelDashedBorder(
            strokeWidth: 1.5,
            dashLength: 2,
            gapLength: 2,
            child: SizedBox(width: 9, height: 9),
          )
        : Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: AppColors.coral,
              border: Border.all(color: Colors.black, width: 1),
            ),
          );

    return Row(
      children: [
        swatch,
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 5)),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 4, height: 2, color: Colors.white24),
          ),
        );
      },
    );
  }
}