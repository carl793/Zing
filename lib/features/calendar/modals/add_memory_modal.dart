import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/tag_categories.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_dashed_border.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/pixel_inset_field.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/tag_picker_dialog.dart';

/// A photo slot is either an already-uploaded photo (url) or a new local one.
class _PhotoSlot {
  final String? url;
  final Uint8List? bytes;
  const _PhotoSlot.remote(this.url) : bytes = null;
  const _PhotoSlot.local(this.bytes) : url = null;
}

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
  final _picker = ImagePicker();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _story = TextEditingController();
  final List<_PhotoSlot> _slots = [];

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
      _story.text = existing.story;
      _location.text = existing.locationPin?.name ?? '';
      _slots.addAll(existing.photoUrls.map(_PhotoSlot.remote));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_slots.length >= CalendarController.maxPhotos) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _slots.add(_PhotoSlot.local(bytes)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "COULDN'T OPEN YOUR GALLERY.");
    }
  }

  void _removeSlot(int index) => setState(() => _slots.removeAt(index));

  Future<void> _selectTag() async {
    final picked = await showTagPickerDialog(context, current: _tag);
    if (picked != null && mounted) setState(() => _tag = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleMissing = true;
        _error = 'GIVE YOUR QUEST A TITLE.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ctrl = context.read<CalendarController>();
    final newPhotos =
        _slots.where((s) => s.bytes != null).map((s) => s.bytes!).toList();
    final keptUrls =
        _slots.where((s) => s.url != null).map((s) => s.url!).toList();

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
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _photoTile(int index, double size) {
    final slot = _slots[index];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: slot.bytes != null
                  ? Image.memory(slot.bytes!, fit: BoxFit.cover)
                  : Image.network(
                      slot.url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: AppColors.gray),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: _saving ? null : () => _removeSlot(index),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Text(
                  'X',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.black, fontSize: 7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTile(double size) {
    return GestureDetector(
      onTap: _saving ? null : _pickPhoto,
      child: SizedBox(
        width: size,
        height: size,
        child: PixelDashedBorder(
          child: Container(
            color: AppColors.charcoal,
            alignment: Alignment.center,
            child: Text(
              '[ + ADD ]',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.yellow, fontSize: 6),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PixelModalShell(
      title: _isEditing ? 'EDIT MEMORY\nQUEST' : 'LOG MEMORY\nQUEST',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ATTACH PHOTOS (${_slots.length}/${CalendarController.maxPhotos})',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final size = (constraints.maxWidth - gap * 3) / 4;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (int i = 0; i < _slots.length; i++) _photoTile(i, size),
                  if (_slots.length < CalendarController.maxPhotos) _addTile(size),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: PixelInsetBox(
                  label: 'DATE',
                  text: ZingDateUtils.isoDate(widget.date),
                  textColor: AppColors.yellow,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: PixelInsetBox(
                  label: 'TAG',
                  text: _tag,
                  textColor: AppColors.cyan,
                  trailingIcon: Icons.arrow_drop_down,
                  onTap: _saving ? null : _selectTag,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PixelInsetField(
            label: 'QUEST TITLE',
            hint: 'SUNSET COFFEE AT THE BAY',
            controller: _title,
            maxLength: 60,
            enabled: !_saving,
            hasError: _titleMissing,
            onChanged: (_) {
              if (_titleMissing) setState(() => _titleMissing = false);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          PixelInsetField(
            label: 'LOCATION PIN',
            hint: 'e.g. SEASIDE BLVD, MANILA',
            controller: _location,
            prefixIcon: Icons.place,
            maxLength: 60,
            enabled: !_saving,
          ),
          const SizedBox(height: AppSpacing.md),
          PixelInsetField(
            label: 'STORY & MEMORIES',
            hint: 'We walked along the shore right before my flight back...',
            controller: _story,
            maxLines: 5,
            maxLength: 600,
            enabled: !_saving,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            PixelErrorBox(message: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          PixelButton(
            label: _saving
                ? 'SAVING...'
                : (_isEditing ? '[ SAVE CHANGES ]' : '[ SAVE TO CALENDAR FEED ]'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}