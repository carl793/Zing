import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        scaffoldBackgroundColor: AppColors.navy,
        fontFamily: AppTextStyles.fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.coral,
          secondary: AppColors.cyan,
          surface: AppColors.purple,
        ),
        useMaterial3: true,
      );
}