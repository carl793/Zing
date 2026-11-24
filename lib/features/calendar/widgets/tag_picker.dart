import 'package:flutter/material.dart';

import '../../../core/constants/tag_categories.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';

/// Lets the user pick a preset tag or type a custom one.
/// Resolves to the chosen tag (uppercase), or null if dismissed.
Future<String?> showTagPicker(BuildContext context, {required String current}) =>
    showPixelSheet<String>(
      context: context,
      builder: (_) => _TagPicker(current: current),
    );

class _TagPicker extends StatefulWidget {
  final String current;
  const _TagPicker({required this.current});

  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    _custom.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _useCustom() {
    final tag = _custom.text.trim();
    if (tag.isNotEmpty) Navigator.of(context).pop(tag.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final isPreset = TagCategories.presets.contains(widget.current);
    return PixelModalShell(
      title: 'CHOOSE A TAG',
      icon: PixelIcons.tag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in [
                if (!isPreset) widget.current,
                ...TagCategories.presets,
              ])
                PixelChip(
                  label: tag,
                  selected: tag == widget.current,
                  onTap: () => Navigator.of(context).pop(tag),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          PixelField(
            label: 'OR MAKE YOUR OWN',
            hint: 'CONCERT',
            controller: _custom,
            maxLength: 16,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _useCustom(),
          ),
          const SizedBox(height: AppSpacing.md),
          PixelButton(
            label: 'USE THIS TAG',
            onPressed: _custom.text.trim().isEmpty ? null : _useCustom,
          ),
        ],
      ),
    );
  }
}
