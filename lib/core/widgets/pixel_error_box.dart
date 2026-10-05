import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Inline error message box used inside modals and forms.
class PixelErrorBox extends StatelessWidget {
  final String message;
  final Color color;

  const PixelErrorBox({
    super.key,
    required this.message,
    this.color = AppColors.coral,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.error.copyWith(color: color, height: 1.8),
      ),
    );
  }
}