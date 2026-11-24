import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/tag_categories.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_dialog.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/tag_picker.dart';

/// Lightweight, unilateral plan for a future day (no photos, no approval).
/// With [existing]: edit/delete your own plan, or view your partner's.
class PlanDayModal extends StatefulWidget {
  final DateTime date;
  final MemoryModel? existing;

  const PlanDayModal({super.key, required this.date, this.existing});

  @override
  State<PlanDayModal> createState() => _PlanDayModalState();
}

class _PlanDayModalState extends State<PlanDayModal> {
  final _title = TextEditingController();
  final _notes = TextEditingController();

  late String _tag;
  late final String _originalTag;
  bool _saving = false;
  bool _titleMissing = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _tag = (existing != null && existing.tagCategory.isNotEmpty)
        ? existing.tagCategory
        : TagCategories.defaultTag;
    _originalTag = _tag;
    if (existing != null) {
      _title.text = existing.title;
      _notes.text = existing.story;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _hasUnsavedWork() =>
      _tag != _originalTag ||
      _title.text != (widget.existing?.title ?? '') ||
      _notes.text != (widget.existing?.story ?? '');

  Future<void> _selectTag() async {
    FocusScope.of(context).unfocus();
    final picked = await showTagPicker(context, current: _tag);
    if (picked != null && mounted) setState(() => _tag = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleMissing = true;
        _error = 'GIVE YOUR PLAN A TITLE.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    await _run(
      (ctrl) => ctrl.savePlan(
        date: widget.date,
        title: title,
        notes: _notes.text.trim(),
        tag: _tag,
        existing: widget.existing,
      ),
      AppSfx.save,
    );
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'DELETE PLAN?',
      message: '"${widget.existing!.title}" will be gone for both of you.',
      confirmLabel: 'DELETE',
      confirmIcon: PixelIcons.trash,
      cancelLabel: 'KEEP IT',
    );
    if (!confirmed || !mounted) return;
    await _run((ctrl) => ctrl.deleteMemory(widget.existing!), AppSfx.close);
  }

  /// Runs [action], then closes; or stays and shows what went wrong.
  Future<void> _run(
    Future<String?> Function(CalendarController ctrl) action,
    AppSfx done,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await action(context.read<CalendarController>());
    if (!mounted) return;
    if (error != null) {
      AudioService.instance.playSfx(AppSfx.error);
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    AudioService.instance.playSfx(done);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<CalendarController>();
    final existing = widget.existing;
    if (existing != null && !ctrl.isMine(existing.authorUid)) {
      return _PartnerPlan(plan: existing, partnerName: ctrl.partnerName);
    }

    return PixelModalShell(
      title: _isEditing ? 'EDIT PLAN' : 'PLAN THIS DAY',
      icon: PixelIcons.clock,
      titleColor: AppColors.yellow,
      busy: _saving,
      hasUnsavedWork: _hasUnsavedWork,
      footer: Row(
        children: [
          if (_isEditing) ...[
            PixelIconButton(
              icon: PixelIcons.trash,
              label: 'Delete plan',
              tone: PixelTone.danger,
              size: 54,
              onPressed: _saving ? null : _delete,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: PixelButton(
              label: _saving ? 'SAVING' : 'SAVE PLAN',
              icon: PixelIcons.check,
              busy: _saving,
              onPressed: _save,
            ),
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
            label: 'DAY',
            text: ZingDateUtils.shortLabel(widget.date),
            icon: PixelIcons.calendar,
            textColor: AppColors.yellow,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelField(
            label: 'PLAN',
            hint: 'Video call date night',
            controller: _title,
            maxLength: 60,
            enabled: !_saving,
            hasError: _titleMissing,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_titleMissing) setState(() => _titleMissing = false);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelField(
            label: 'NOTES (OPTIONAL)',
            hint: "Don't forget to book the restaurant...",
            controller: _notes,
            maxLines: 3,
            maxLength: 200,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelValueBox(
            label: 'TAG',
            text: _tag,
            icon: PixelIcons.tag,
            textColor: AppColors.cyan,
            onTap: _saving ? null : _selectTag,
          ),
        ],
      ),
    );
  }
}

class _PartnerPlan extends StatelessWidget {
  final MemoryModel plan;
  final String partnerName;
  const _PartnerPlan({required this.plan, required this.partnerName});

  @override
  Widget build(BuildContext context) => PixelModalShell(
        title: "$partnerName'S PLAN",
        icon: PixelIcons.clock,
        titleColor: AppColors.yellow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(plan.title, style: AppTextStyles.subHeader),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                PixelTag(
                  ZingDateUtils.shortLabel(plan.date),
                  icon: PixelIcons.calendar,
                  color: AppColors.yellow,
                ),
                if (plan.tagCategory.isNotEmpty)
                  PixelTag(
                    plan.tagCategory,
                    icon: PixelIcons.tag,
                    color: AppColors.gray,
                  ),
              ],
            ),
            if (plan.story.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(plan.story, style: AppTextStyles.body),
            ],
          ],
        ),
      );
}
