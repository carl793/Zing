import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';

/// Asks a chest's creator to confirm cancelling it. Resolves to true only
/// when they confirm.
Future<bool> showCancelChestDialog(BuildContext context, String chestName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _CancelChestDialog(chestName: chestName),
  );
  return confirmed ?? false;
}

class _CancelChestDialog extends StatelessWidget {
  final String chestName;
  const _CancelChestDialog({required this.chestName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.purple,
          border: Border.all(color: AppColors.coral, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.amber,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'CANCEL THIS\nCHEST?',
              textAlign: TextAlign.center,
              style: AppTextStyles.subHeader.copyWith(
                color: AppColors.coral,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '"$chestName" will be cancelled for both of you, along with '
              'everything sealed inside it.\nIt can\'t be reopened.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.gray,
                fontSize: 6,
                height: 1.8,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PixelButton(
              label: '[ KEEP SEALED ]',
              style: PixelButtonStyle.outline,
              backgroundColor: AppColors.charcoal,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.md),
            PixelButton(
              label: '[ YES, CANCEL CHEST ]',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
