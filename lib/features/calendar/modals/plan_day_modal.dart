import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/tag_categories.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/pixel_inset_field.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/tag_picker_dialog.dart';

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

  Future<void> _selectTag() async {
    final picked = await showTagPickerDialog(context, current: _tag);
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

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await context.read<CalendarController>().savePlan(
          date: widget.date,
          title: title,
          notes: _notes.text.trim(),
          tag: _tag,
          existing: widget.existing,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ctrl = context.read<CalendarController>();
    final confirmed = await showConfirmDialog(
      context: context,
      message: 'DELETE THE PLAN\n"${widget.existing!.title.toUpperCase()}"?',
      confirmLabel: '[ YES, DELETE PLAN ]',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ctrl.deleteMemory(widget.existing!);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<CalendarController>();
    final readOnly = _isEditing && widget.existing!.authorUid != ctrl.myUid;
    final canEdit = !readOnly && !_saving;

    return PixelModalShell(
      title: readOnly
          ? 'PARTNER PLAN'
          : (_isEditing ? 'EDIT PLAN' : 'PLAN THIS DAY'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelInsetBox(
            label: 'DATE',
            text: ZingDateUtils.isoDate(widget.date),
            textColor: AppColors.yellow,
          ),
          const SizedBox(height: AppSpacing.md),
          PixelInsetField(
            label: 'PLAN TITLE',
            hint: 'e.g. VIDEO CALL DATE NIGHT',
            controller: _title,
            maxLength: 60,
            enabled: canEdit,
            hasError: _titleMissing,
            onChanged: (_) {
              if (_titleMissing) setState(() => _titleMissing = false);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          PixelInsetBox(
            label: 'TAG',
            text: '[ $_tag ]',
            textColor: AppColors.yellow,
            trailingIcon: canEdit ? Icons.arrow_drop_down : null,
            onTap: canEdit ? _selectTag : null,
          ),
          const SizedBox(height: AppSpacing.md),
          PixelInsetField(
            label: 'NOTES (OPTIONAL)',
            hint: "Don't forget to book the restaurant...",
            controller: _notes,
            maxLines: 3,
            maxLength: 200,
            enabled: canEdit,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            PixelErrorBox(message: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (readOnly)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 9, color: AppColors.gray),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "THIS IS ${ctrl.partnerName}'S PLAN - VIEW ONLY",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.gray),
                  ),
                ),
              ],
            )
          else ...[
            PixelButton(
              label: _saving ? 'SAVING...' : '[ SAVE PLAN ]',
              style: PixelButtonStyle.cyan,
              onPressed: _saving ? null : _save,
            ),
            if (_isEditing) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: GestureDetector(
                  onTap: _saving ? null : _delete,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      '[ DELETE PLAN ]',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.coral, fontSize: 7),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}