import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/dashboard_controller.dart';

class ReviewQuestModal extends StatefulWidget {
  const ReviewQuestModal({super.key});

  @override
  State<ReviewQuestModal> createState() => _ReviewQuestModalState();
}

class _ReviewQuestModalState extends State<ReviewQuestModal> {
  bool _submitting = false;
  String? _error;

  Future<void> _respond(
    Future<String?> Function(DashboardController ctrl) action, {
    required bool accepted,
  }) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await action(context.read<DashboardController>());
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    if (accepted) AudioService.instance.playSfx(AppSfx.unlock);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quest = context.watch<DashboardController>().couple?.reunionQuest;
    final date = quest?.targetDate;
    final notes = quest?.notes?.trim() ?? '';

    return PixelModalShell(
      title: 'REVIEW QUEST',
      icon: PixelIcons.flag,
      titleColor: AppColors.yellow,
      busy: _submitting,
      footer: Column(
        children: [
          PixelButton(
            label: 'ACCEPT QUEST',
            icon: PixelIcons.check,
            busy: _submitting,
            onPressed: () =>
                _respond((ctrl) => ctrl.acceptQuest(), accepted: true),
          ),
          const SizedBox(height: AppSpacing.md),
          PixelButton(
            label: 'DECLINE',
            style: PixelButtonStyle.neutral,
            onPressed: _submitting
                ? null
                : () =>
                    _respond((ctrl) => ctrl.cancelQuest(), accepted: false),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            PixelNote.error(_error!),
            const SizedBox(height: AppSpacing.lg),
          ],
          PixelValueBox(
            label: 'DESTINATION',
            icon: PixelIcons.pin,
            text: quest?.destination ?? '---',
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelValueBox(
            label: 'DATE',
            icon: PixelIcons.calendar,
            text: date == null
                ? '---'
                : ZingDateUtils.shortLabel(ZingDateUtils.fromLocal(date)),
            textColor: AppColors.yellow,
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const PixelLabel('NOTES'),
            PixelWell(child: Text(notes, style: AppTextStyles.body)),
          ],
        ],
      ),
    );
  }
}
