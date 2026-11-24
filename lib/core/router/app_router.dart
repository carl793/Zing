import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/pairing_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/sprite_select_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/pairing/screens/pairing_screen.dart';
import '../../features/pairing/screens/pairing_success_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../services/auth_service.dart';
import '../widgets/splash_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const launch = '/';
  static const welcome = '/welcome';
  static const spriteSelect = '/sprite-select';
  static const forgotPassword = '/forgot-password';
  static const pairing = '/pairing';
  static const pairingSuccess = '/pairing-success';
  static const shell = '/shell';
}

class AppRouter {
  AppRouter._();

  /// Where the current account should land: welcome when signed out,
  /// onboarding until it has a display name, pairing until it belongs to an
  /// active couple, otherwise the main shell.
  ///
  /// Used at launch, after signing in and after onboarding, so they can't
  /// disagree. Throws when the profile can't be loaded.
  static Future<String> resolveDestination(BuildContext context) async {
    final user = context.read<AuthService>().currentUser;
    final users = context.read<UserRepository>();
    final pairing = context.read<PairingRepository>();
    if (user == null) return AppRoutes.welcome;

    final profile =
        await users.fetch(user.uid).timeout(const Duration(seconds: 15));
    if (profile == null || profile.displayName.isEmpty) {
      return AppRoutes.spriteSelect;
    }
    final coupleId = await pairing.resolveActiveCouple(
      user.uid,
      stored: profile.coupleId,
    );
    return coupleId == null ? AppRoutes.pairing : AppRoutes.shell;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => switch (settings.name) {
        AppRoutes.welcome => const WelcomeScreen(),
        AppRoutes.spriteSelect => const SpriteSelectScreen(),
        AppRoutes.forgotPassword => const ForgotPasswordScreen(),
        AppRoutes.pairing => const PairingScreen(),
        AppRoutes.pairingSuccess => const PairingSuccessScreen(),
        AppRoutes.shell => const ShellScreen(),
        _ => const SplashScreen(resolveRoute: resolveDestination),
      },
    );
  }
}
