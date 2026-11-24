import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/photos/photo_carousel.dart';
import '../../../core/photos/pixel_photo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_dialog.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/comments_section.dart';

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
  late final List<PhotoItem> _photos = [
    for (final url in widget.memory.photoUrls) PhotoItem.url(url),
  ];
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final ctrl = context.read<CalendarController>();
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'DELETE MEMORY?',
      message: '"${widget.memory.title}" and its photos, story and tag will be '
          'gone for both of you.',
      confirmLabel: 'DELETE',
      confirmIcon: PixelIcons.trash,
      cancelLabel: 'KEEP IT',
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
    final isOwn = ctrl.isMine(memory.authorUid);
    final date = ZingDateUtils.fromStored(memory.date);
    final location = memory.locationPin?.name ?? '';

    return PixelModalShell(
      title: 'STAGE CLEAR',
      icon: PixelIcons.star,
      titleColor: AppColors.yellow,
      busy: _busy,
      footer: !isOwn
          ? null
          : Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: 'EDIT',
                    icon: PixelIcons.edit,
                    style: PixelButtonStyle.neutral,
                    onPressed: _busy
                        ? null
                        : () =>
                            Navigator.of(context).pop(ViewMemoryAction.edit),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PixelButton(
                    label: 'DELETE',
                    icon: PixelIcons.trash,
                    style: PixelButtonStyle.danger,
                    busy: _busy,
                    onPressed: _delete,
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
          if (_photos.isNotEmpty) ...[
            PhotoCarousel(photos: _photos, title: memory.title),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(memory.title, style: AppTextStyles.subHeader),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PixelTag(
                ZingDateUtils.shortLabel(date),
                icon: PixelIcons.calendar,
                color: AppColors.yellow,
              ),
              PixelTag.owner(isOwn ? 'YOU' : ctrl.partnerName, isMe: isOwn),
              if (memory.tagCategory.isNotEmpty)
                PixelTag(
                  memory.tagCategory,
                  icon: PixelIcons.tag,
                  color: AppColors.gray,
                ),
              if (location.isNotEmpty)
                PixelTag(location, icon: PixelIcons.pin, color: AppColors.gray),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (memory.story.isNotEmpty) ...[
            SelectableText(memory.story, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.xl),
          ],
          CommentsSection(memory: memory, canComment: !isOwn),
        ],
      ),
    );
  }
}
