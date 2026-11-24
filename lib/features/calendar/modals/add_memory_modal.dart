import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/tag_categories.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/permissions/permission_flows.dart';
import '../../../core/photos/photo_viewer.dart';
import '../../../core/photos/pixel_photo.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_dialog.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/pixel_pressable.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/tag_picker.dart';

/// Create a memory for [date]. When [existing] is given the modal edits it
/// (or converts an own plan into a memory) instead.
class AddMemoryModal extends StatefulWidget {
  final DateTime date;
  final MemoryModel? existing;

  const AddMemoryModal({super.key, required this.date, this.existing});

  @override
  State<AddMemoryModal> createState() => _AddMemoryModalState();
}

class _AddMemoryModalState extends State<AddMemoryModal> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _story = TextEditingController();
  final List<PhotoItem> _photos = [];

  late String _tag;
  bool _changedOther = false;
  bool _saving = false;
  bool _titleMissing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _tag = (existing != null && existing.tagCategory.isNotEmpty)
        ? existing.tagCategory
        : TagCategories.defaultTag;

    if (existing != null) {
      _title.text = existing.title;
      _story.text = existing.story;
      _location.text = existing.locationPin?.name ?? '';
      _photos.addAll(existing.photoUrls.map(PhotoItem.url));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _story.dispose();
    super.dispose();
  }

  bool _hasUnsavedWork() {
    final existing = widget.existing;
    return _changedOther ||
        _title.text != (existing?.title ?? '') ||
        _story.text != (existing?.story ?? '') ||
        _location.text != (existing?.locationPin?.name ?? '');
  }

  Future<void> _addPhotos() async {
    FocusScope.of(context).unfocus();
    final picked = await pickPhotos(
      context,
      settings: context.read<LocationService>(),
      limit: CalendarController.maxPhotos - _photos.length,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _photos.addAll(picked.map(PhotoItem.bytes));
      _changedOther = true;
    });
  }

  void _removePhoto(int index) => setState(() {
        _photos.removeAt(index);
        _changedOther = true;
      });

  Future<void> _selectTag() async {
    FocusScope.of(context).unfocus();
    final picked = await showTagPicker(context, current: _tag);
    if (picked == null || picked == _tag || !mounted) return;
    setState(() {
      _tag = picked;
      _changedOther = true;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleMissing = true;
        _error = 'GIVE YOUR MEMORY A TITLE.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final ctrl = context.read<CalendarController>();
    final newPhotos = [for (final p in _photos) ?p.bytes];
    final keptUrls = [for (final p in _photos) ?p.url];

    final String? error = widget.existing == null
        ? await ctrl.createMemory(
            date: widget.date,
            title: title,
            story: _story.text.trim(),
            tag: _tag,
            locationName: _location.text,
            photos: newPhotos,
          )
        : await ctrl.updateMemory(
            original: widget.existing!,
            title: title,
            story: _story.text.trim(),
            tag: _tag,
            locationName: _location.text,
            keptPhotoUrls: keptUrls,
            newPhotos: newPhotos,
          );

    if (!mounted) return;
    if (error != null) {
      AudioService.instance.playSfx(AppSfx.error);
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    AudioService.instance.playSfx(AppSfx.save);
    Navigator.of(context).pop(true);
  }

  /// For a plan whose day has passed without it happening.
  Future<void> _deletePlan() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'DELETE PLAN?',
      message: '"${widget.existing!.title}" will be gone for both of you.',
      confirmLabel: 'DELETE',
      confirmIcon: PixelIcons.trash,
      cancelLabel: 'KEEP IT',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final error =
        await context.read<CalendarController>().deleteMemory(widget.existing!);
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

  Widget _photoTile(int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => PhotoViewer.open(
            context,
            photos: _photos,
            initialIndex: index,
          ),
          child: Container(
            decoration: const PixelInset(),
            clipBehavior: Clip.hardEdge,
            child: PixelPhoto(_photos[index]),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: PixelPressable(
            onPressed: _saving ? null : () => _removePhoto(index),
            semanticLabel: 'Remove photo ${index + 1}',
            builder: (_, pressed) => Container(
              width: 30,
              height: 30,
              alignment: Alignment.topRight,
              child: Container(
                width: 24,
                height: 24,
                decoration: PixelRaised(
                  tone: PixelTone.danger,
                  depth: 2,
                  shadow: 0,
                  pressed: pressed,
                ),
                child: Center(
                  child: PixelIcon(
                    PixelIcons.close,
                    color: PixelTone.danger.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile() => PixelPressable(
        onPressed: _saving ? null : _addPhotos,
        semanticLabel: 'Add photos',
        builder: (_, pressed) => Container(
          decoration: PixelRaised(
            tone: PixelTone.neutral,
            pressed: pressed,
            shadow: 2,
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PixelIcon(PixelIcons.photo, size: 24, color: AppColors.yellow),
              SizedBox(height: 4),
              Text('ADD', style: AppTextStyles.caption),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final type = widget.existing?.entryType;
    final isEditing = type == MemoryEntryType.memory;

    return PixelModalShell(
      title: isEditing ? 'EDIT MEMORY' : 'LOG A MEMORY',
      icon: PixelIcons.heart,
      titleColor: AppColors.coral,
      busy: _saving,
      hasUnsavedWork: _hasUnsavedWork,
      footer: Row(
        children: [
          if (type == MemoryEntryType.plan) ...[
            PixelIconButton(
              icon: PixelIcons.trash,
              label: 'Delete plan',
              tone: PixelTone.danger,
              size: 54,
              onPressed: _saving ? null : _deletePlan,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: PixelButton(
              label: _saving
                  ? 'SAVING'
                  : isEditing
                      ? 'SAVE CHANGES'
                      : 'SAVE MEMORY',
              icon: PixelIcons.check,
              style: PixelButtonStyle.coral,
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
          PixelLabel(
            'PHOTOS',
            trailing: '${_photos.length}/${CalendarController.maxPhotos}',
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < _photos.length; i++) _photoTile(i),
              if (_photos.length < CalendarController.maxPhotos) _addTile(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelField(
            label: 'TITLE',
            hint: 'Sunset coffee at the bay',
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
            label: 'STORY',
            hint: 'What happened, and what do you want to remember?',
            controller: _story,
            maxLines: 5,
            maxLength: 600,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelField(
            label: 'PLACE',
            hint: 'Seaside Blvd, Manila',
            controller: _location,
            icon: PixelIcons.pin,
            maxLength: 60,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelValueBox(
            label: 'TAG',
            text: _tag,
            icon: PixelIcons.tag,
            textColor: AppColors.cyan,
            onTap: _saving ? null : _selectTag,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelValueBox(
            label: 'DAY',
            text: ZingDateUtils.shortLabel(widget.date),
            icon: PixelIcons.calendar,
            textColor: AppColors.gray,
          ),
        ],
      ),
    );
  }
}
