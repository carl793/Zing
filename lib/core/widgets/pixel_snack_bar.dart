import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shows a short pixel-styled message at the bottom of the screen, replacing
/// any message already showing.
void showPixelSnackBar(
  BuildContext context,
  String message, {
  Color color = AppColors.yellow,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.purple,
        duration: const Duration(seconds: 2),
        content: Text(
          message,
          style: AppTextStyles.caption.copyWith(color: color, height: 1.6),
        ),
      ),
    );
}
