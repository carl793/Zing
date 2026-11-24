import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/auth_controller.dart';

class AuthErrorBanner extends StatelessWidget {
  final AuthErrorType errorType;
  const AuthErrorBanner({super.key, required this.errorType});

  @override
  Widget build(BuildContext context) {
    if (errorType == AuthErrorType.none) return const SizedBox.shrink();

    final (message, color) = switch (errorType) {
      AuthErrorType.wrongCredentials => (
          'INCORRECT EMAIL OR PASSCODE. TRY AGAIN.',
          AppColors.coral,
        ),
      AuthErrorType.emailInUse => (
          'THAT EMAIL ALREADY HAS AN ACCOUNT. TRY LOGGING IN.',
          AppColors.coral,
        ),
      AuthErrorType.weakPassword => (
          'PASSCODE TOO WEAK. USE AT LEAST 6 CHARACTERS.',
          AppColors.coral,
        ),
      AuthErrorType.invalidEmail => (
          'THAT EMAIL ADDRESS LOOKS INVALID.',
          AppColors.coral,
        ),
      AuthErrorType.tooManyAttempts => (
          'TOO MANY ATTEMPTS. TRY AGAIN LATER.',
          AppColors.amber,
        ),
      AuthErrorType.network => (
          'NO CONNECTION. CHECK YOUR INTERNET.',
          AppColors.amber,
        ),
      AuthErrorType.googleUnavailable => (
          "GOOGLE SIGN-IN ISN'T AVAILABLE ON THIS PHONE. USE YOUR EMAIL.",
          AppColors.amber,
        ),
      AuthErrorType.googleFailed => (
          'GOOGLE SIGN-IN FAILED. TRY AGAIN.',
          AppColors.coral,
        ),
      _ => ('SOMETHING WENT WRONG. TRY AGAIN.', AppColors.coral),
    };

    return PixelNote(message, color: color, icon: PixelIcons.warning);
  }
}
