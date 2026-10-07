import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../controllers/dashboard_controller.dart';

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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'NEXT REUNION QUEST',
            style: AppTextStyles.label.copyWith(
              color: AppColors.cyan,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (controller.questState) {
      QuestState.none => _QuestEmpty(onPropose: onPropose),
      QuestState.pending => _QuestPending(
        controller: controller,
        onReview: onReview,
      ),
      QuestState.accepted => _QuestAccepted(controller: controller),
    };
  }
}

class _QuestEmpty extends StatelessWidget {
  final VoidCallback onPropose;
  const _QuestEmpty({required this.onPropose});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('🗺️', style: TextStyle(fontSize: 26)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'NO REUNION QUEST\nSCHEDULED YET.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.gray,
            height: 1.8,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PixelButton(
          label: '[ + PROPOSE QUEST ]',
          style: PixelButtonStyle.yellow,
          onPressed: onPropose,
        ),
      ],
    );
  }
}

class _QuestPending extends StatelessWidget {
  final DashboardController controller;
  final VoidCallback onReview;
  const _QuestPending({required this.controller, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final quest = controller.couple?.reunionQuest;
    final isProposer = controller.isQuestProposer;
    final partnerName = controller.partner?.displayName ?? 'PARTNER';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isProposer
              ? 'QUEST PROPOSED — AWAITING\n${partnerName.toUpperCase()}\'S RESPONSE'
              : '${(controller.me?.displayName ?? 'PARTNER').toUpperCase()} PROPOSED\nA QUEST!',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: AppColors.yellow,
            fontSize: 8,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: AppColors.charcoal,
          child: Column(
            children: [
              _questRow('📍', quest?.destination ?? '---'),
              const SizedBox(height: 4),
              _questRow(
                '📅',
                quest?.targetDate != null
                    ? '${quest!.targetDate!.year}-${quest.targetDate!.month.toString().padLeft(2, '0')}-${quest.targetDate!.day.toString().padLeft(2, '0')}'
                    : '---',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (isProposer)
          GestureDetector(
            onTap: controller.cancelQuest,
            child: Text(
              '[ CANCEL PROPOSAL ]',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.coral),
            ),
          )
        else
          PixelButton(
            label: '[ REVIEW QUEST ]',
            style: PixelButtonStyle.yellow,
            onPressed: onReview,
          ),
      ],
    );
  }

  Widget _questRow(String icon, String text) => Row(
    children: [
      Text(icon, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 8),
      Text(
        text,
        style: AppTextStyles.body.copyWith(color: AppColors.cyan, fontSize: 8),
      ),
    ],
  );
}

class _QuestAccepted extends StatelessWidget {
  final DashboardController controller;
  const _QuestAccepted({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Accepted chip
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            border: Border.all(color: AppColors.cyan, width: 1),
          ),
          child: Text(
            '✓ ACCEPTED BY BOTH',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.cyan,
              fontSize: 8,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Countdown
        Text(
          controller.questCountdown,
          textAlign: TextAlign.center,
          style: AppTextStyles.header.copyWith(
            color: AppColors.yellow,
            fontSize: 18,
            shadows: [
              const Shadow(
                color: Colors.black,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Progress bar
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: FractionallySizedBox(
            widthFactor: controller.questProgress,
            heightFactor: 1,
            alignment: Alignment.centerLeft,
            child: Container(color: AppColors.yellow),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${(controller.questProgress * 100).toStringAsFixed(0)}% JOURNEY COMPLETED',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.gray,
            fontSize: 7,
          ),
        ),
      ],
    );
  }
}
