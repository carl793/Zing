import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pixel_button.dart';

/// Reusable destructive-confirm dialog (delete memory, cancel chest, etc.).
/// Resolves to true only when the user taps the confirm button.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String message,
  required String confirmLabel,
  String cancelLabel = '[ CANCEL ]',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.purple,
          border: Border.all(color: Colors.black, width: 2),
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
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body
                  .copyWith(color: Colors.white70, fontSize: 7, height: 1.8),
            ),
            const SizedBox(height: AppSpacing.lg),
            PixelButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
            const SizedBox(height: AppSpacing.md),
            PixelButton(
              label: cancelLabel,
              style: PixelButtonStyle.outline,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}