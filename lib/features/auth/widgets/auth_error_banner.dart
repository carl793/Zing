import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/auth_controller.dart';

class AuthErrorBanner extends StatelessWidget {
  final AuthErrorType errorType;
  const AuthErrorBanner({super.key, required this.errorType});

  @override
  Widget build(BuildContext context) {
    if (errorType == AuthErrorType.none) return const SizedBox.shrink();

    final (message, color) = switch (errorType) {
      AuthErrorType.wrongCredentials => ('✕ INCORRECT EMAIL OR PASSWORD. TRY AGAIN.', AppColors.coral),
      AuthErrorType.tooManyAttempts => ('⚠ TOO MANY ATTEMPTS. TRY AGAIN LATER.', AppColors.amber),
      AuthErrorType.network => ('⚠ NO CONNECTION. CHECK YOUR INTERNET.', AppColors.gray),
      _ => ('⚠ SOMETHING WENT WRONG. TRY AGAIN.', AppColors.coral),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.charcoal, border: Border.all(color: color, width: 2)),
      child: Text(message, textAlign: TextAlign.center, style: AppTextStyles.error.copyWith(color: color)),
    );
  }
}