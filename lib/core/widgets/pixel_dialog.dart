import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pixel_button.dart';
import 'pixel_icon.dart';
import 'pixel_panel.dart';

/// Asks before doing something that can't be taken back. True only when the
/// player confirms.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'CANCEL',
  PixelIcons icon = PixelIcons.warning,
  PixelIcons? confirmIcon,
}) async {
  AudioService.instance.playSfx(AppSfx.open);
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: const Color(0xCC08081A),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (_, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack)
          .drive(Tween(begin: 0.85, end: 1)),
      child: FadeTransition(opacity: animation, child: child),
    ),
    pageBuilder: (dialogContext, _, _) => SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              type: MaterialType.transparency,
              child: PixelPanel(
                title: title,
                icon: icon,
                titleColor: AppColors.amber,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(message, style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.xl),
                    PixelButton(
                      label: confirmLabel,
                      icon: confirmIcon,
                      style: PixelButtonStyle.danger,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PixelButton(
                      label: cancelLabel,
                      style: PixelButtonStyle.neutral,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
