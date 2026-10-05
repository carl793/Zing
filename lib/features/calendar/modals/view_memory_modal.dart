import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/attribution_tag.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/comments_section.dart';
import '../widgets/photo_carousel.dart';

/// Returned to the calendar screen when the user asks to edit.
enum ViewMemoryAction { edit }

/// "STAGE CLEAR" view of one memory. The same widget serves both partners:
/// your own entry shows EDIT/DELETE; your partner's is view-only and open for
/// your comments.
class ViewMemoryModal extends StatefulWidget {
  final MemoryModel memory;
  const ViewMemoryModal({super.key, required this.memory});

  @override
  State<ViewMemoryModal> createState() => _ViewMemoryModalState();
}

class _ViewMemoryModalState extends State<ViewMemoryModal> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final ctrl = context.read<CalendarController>();
    final confirmed = await showConfirmDialog(
      context: context,
      message: 'DELETE "${widget.memory.title.toUpperCase()}"?\n'
          'THIS REMOVES THE PHOTOS, NOTE,\nAND TAG PERMANENTLY.',
      confirmLabel: '[ YES, DELETE MEMORY ]',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ctrl.deleteMemory(widget.memory);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<CalendarController>();
    final memory = widget.memory;
    final isOwn = memory.authorUid == ctrl.myUid;
    final date = ZingDateUtils.fromStored(memory.date);
    final location = memory.locationPin?.name;

    return PixelModalShell(
      title: 'STAGE CLEAR:\n${ZingDateUtils.shortLabel(date)}',
      titleColor: AppColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AttributionTag(
              label: isOwn ? 'YOU' : ctrl.partnerName,
              isMine: isOwn,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (memory.tagCategory.isNotEmpty)
                _Pill(text: memory.tagCategory, color: AppColors.coral),
              if (location != null && location.isNotEmpty)
                _Pill(text: location, color: AppColors.cyan, icon: Icons.place),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhotoCarousel(urls: memory.photoUrls),
          const SizedBox(height: AppSpacing.md),
          Text(
            memory.title,
            style: AppTextStyles.subHeader
                .copyWith(color: AppColors.cyan, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('STORY', style: AppTextStyles.label),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: AppShadows.insetField(),
            child: Text(
              memory.story.isEmpty ? 'NO CAPTION WRITTEN.' : memory.story,
              style: AppTextStyles.body.copyWith(
                fontSize: 7,
                height: 1.8,
                color: memory.story.isEmpty ? AppColors.gray : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isOwn)
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: '[ EDIT ]',
                    style: PixelButtonStyle.outline,
                    backgroundColor: AppColors.charcoal,
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(ViewMemoryAction.edit),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PixelButton(
                    label: '[ DELETE ]',
                    style: PixelButtonStyle.outlineDanger,
                    backgroundColor: AppColors.charcoal,
                    onPressed: _busy ? null : _delete,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 9, color: AppColors.gray),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "THIS IS ${ctrl.partnerName}'S ENTRY - VIEW ONLY",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.gray),
                  ),
                ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            PixelErrorBox(message: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          CommentsSection(memory: memory, canComment: !isOwn),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Pill({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: color, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: color, fontSize: 6),
            ),
          ),
        ],
      ),
    );
  }
}