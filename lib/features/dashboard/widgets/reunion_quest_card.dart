import 'package:flutter/material.dart';

import '../../../core/models/couple_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/countdown_digits.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_dialog.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/pixel_toast.dart';
import '../controllers/dashboard_controller.dart';

/// The next time the couple will meet: proposed, answered, counted down to.
class ReunionQuestCard extends StatelessWidget {
  final DashboardController controller;
  final VoidCallback onPropose;
  final VoidCallback onReview;

  const ReunionQuestCard({
    super.key,
    required this.controller,
    required this.onPropose,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      title: 'REUNION QUEST',
      icon: PixelIcons.flag,
      titleColor: AppColors.yellow,
      child: switch (controller.questState) {
        QuestState.none => _Empty(onPropose: onPropose),
        QuestState.pending => _Pending(controller, onReview: onReview),
        QuestState.accepted => controller.questIsDue
            ? _Due(controller)
            : _Countdown(controller),
      },
    );
  }
}

Future<void> _clear(
  BuildContext context,
  DashboardController controller, {
  String? done,
}) async {
  final error = await controller.cancelQuest();
  if (!context.mounted) return;
  if (error != null) {
    showPixelToast(context, error, color: AppColors.coral);
  } else if (done != null) {
    AudioService.instance.playSfx(AppSfx.unlock);
    showPixelToast(context, done);
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onPropose;
  const _Empty({required this.onPropose});

  @override
  Widget build(BuildContext context) => PixelEmpty(
        art: const PixelIcon(
          PixelIcons.flag,
          size: 36,
          color: AppColors.yellow,
          shadow: true,
        ),
        title: 'NO QUEST YET',
        message: 'Pick where and when you meet next, and count down to it '
            'together.',
        action: PixelButton(
          label: 'PROPOSE A QUEST',
          icon: PixelIcons.plus,
          onPressed: onPropose,
        ),
      );
}

/// Where and when.
class _Details extends StatelessWidget {
  final ReunionQuest? quest;
  const _Details(this.quest);

  @override
  Widget build(BuildContext context) {
    final date = quest?.targetDate;
    return PixelWell(
      child: Column(
        children: [
          _line(PixelIcons.pin, quest?.destination ?? '---', AppColors.white),
          const SizedBox(height: AppSpacing.sm),
          _line(
            PixelIcons.calendar,
            date == null
                ? '---'
                : ZingDateUtils.shortLabel(ZingDateUtils.fromLocal(date)),
            AppColors.yellow,
          ),
        ],
      ),
    );
  }

  Widget _line(PixelIcons icon, String text, Color color) => Row(
        children: [
          PixelIcon(icon, color: AppColors.cyan),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.button.copyWith(color: color),
            ),
          ),
        ],
      );
}

class _Pending extends StatelessWidget {
  final DashboardController controller;
  final VoidCallback onReview;
  const _Pending(this.controller, {required this.onReview});

  @override
  Widget build(BuildContext context) {
    final mine = controller.isQuestProposer;
    final partner = controller.session.partnerName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          mine ? 'WAITING FOR $partner' : '$partner PROPOSED A QUEST!',
          style: AppTextStyles.button.copyWith(
            color: mine ? AppColors.gray : AppColors.yellow,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Details(controller.couple?.reunionQuest),
        const SizedBox(height: AppSpacing.md),
        if (mine)
          PixelButton(
            label: 'WITHDRAW',
            style: PixelButtonStyle.neutral,
            small: true,
            onPressed: () => _clear(context, controller),
          )
        else
          PixelButton(
            label: 'REVIEW QUEST',
            icon: PixelIcons.eye,
            onPressed: onReview,
          ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  final DashboardController controller;
  const _Countdown(this.controller);

  Future<void> _cancel(BuildContext context) async {
    final sure = await showConfirmDialog(
      context: context,
      title: 'CANCEL QUEST?',
      message: 'The countdown ends for both of you. You can always propose a '
          'new one.',
      confirmLabel: 'CANCEL QUEST',
      cancelLabel: 'KEEP IT',
    );
    if (sure && context.mounted) await _clear(context, controller);
  }

  @override
  Widget build(BuildContext context) {
    final left = controller.questRemaining;
    final percent = (controller.questProgress * 100).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Details(controller.couple?.reunionQuest),
        const SizedBox(height: AppSpacing.md),
        CountdownDigits(left),
        const SizedBox(height: AppSpacing.md),
        PixelProgressBar(value: controller.questProgress),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text('$percent% THERE', style: AppTextStyles.caption),
            ),
            PixelLink(
              label: 'CANCEL',
              color: AppColors.gray,
              onPressed: () => _cancel(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _Due extends StatelessWidget {
  final DashboardController controller;
  const _Due(this.controller);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "IT'S THE DAY!",
            textAlign: TextAlign.center,
            style: AppTextStyles.display.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),
          _Details(controller.couple?.reunionQuest),
          const SizedBox(height: AppSpacing.md),
          const PixelProgressBar(value: 1),
          const SizedBox(height: AppSpacing.md),
          PixelButton(
            label: 'QUEST COMPLETE',
            icon: PixelIcons.star,
            onPressed: () => _clear(
              context,
              controller,
              done: 'QUEST COMPLETE! LOG THE MEMORY NEXT.',
            ),
          ),
        ],
      );
}
