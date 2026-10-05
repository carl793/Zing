import 'package:flutter/material.dart';
import '../../../core/constants/tag_categories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_inset_field.dart';

/// Lets the user pick a preset tag or type a custom one.
/// Resolves to the chosen tag (uppercase), or null if dismissed.
Future<String?> showTagPickerDialog(
  BuildContext context, {
  required String current,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _TagPickerDialog(current: current),
  );
}

class _TagPickerDialog extends StatefulWidget {
  final String current;
  const _TagPickerDialog({required this.current});

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customText = _custom.text.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.purple,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SELECT TAG',
                style: AppTextStyles.subHeader
                    .copyWith(color: AppColors.cyan, fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: TagCategories.presets
                    .map((tag) => _TagChip(
                          label: tag,
                          selected: tag == widget.current,
                          onTap: () => Navigator.of(context).pop(tag),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              PixelInsetField(
                label: 'OR TYPE A CUSTOM TAG',
                hint: 'e.g. CONCERT',
                controller: _custom,
                maxLength: 16,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              PixelButton(
                label: '[ USE CUSTOM TAG ]',
                style: PixelButtonStyle.yellow,
                onPressed: customText.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(customText.toUpperCase()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : AppColors.charcoal,
          border: Border.all(
            color: selected ? Colors.black : AppColors.cyan,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 6,
            color: selected ? Colors.black : AppColors.cyan,
          ),
        ),
      ),
    );
  }
}