import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/sprite_select_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/pairing/screens/pairing_screen.dart';
import '../../features/pairing/screens/pairing_success_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/splash_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const launch         = '/';
  static const welcome       = '/welcome';
  static const spriteSelect  = '/sprite-select';
  static const forgotPassword= '/forgot-password';
  static const pairing       = '/pairing';
  static const pairingSuccess= '/pairing-success';
  static const shell         = '/shell';
}

class AppRouter {
  AppRouter._();

  /// Where the current account should land: welcome when signed out,
  /// onboarding until it has a display name, pairing until it belongs to an
  /// active couple, otherwise the main shell.
  ///
  /// Used both at launch and right after signing in, so the two can't
  /// disagree. Both recover a link made while this account was signed out,
  /// and drop a link to a couple that has been unlinked.
  static Future<String> resolveDestination({
    required AuthService auth,
    required FirestoreService firestore,
  }) async {
    final user = auth.currentUser;
    if (user == null) return AppRoutes.welcome;
    if (!await auth.hasCompletedProfile(user.uid)) return AppRoutes.spriteSelect;
    final coupleId = await firestore.recoverCoupleId(user.uid);
    return coupleId == null ? AppRoutes.pairing : AppRoutes.shell;
  }

  static Future<String> _resolveLaunchDestination(BuildContext context) =>
      resolveDestination(
        auth: context.read<AuthService>(),
        firestore: context.read<FirestoreService>(),
      );

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.launch:
        return _page(const SplashScreen(resolveRoute: _resolveLaunchDestination));
      case AppRoutes.welcome:
        return _page(const WelcomeScreen());
      case AppRoutes.spriteSelect:
        return _page(const SpriteSelectScreen());
      case AppRoutes.forgotPassword:
        return _page(const ForgotPasswordScreen());
      case AppRoutes.pairing:
        return _page(const PairingScreen());
      case AppRoutes.pairingSuccess:
        return _page(const PairingSuccessScreen());
      case AppRoutes.shell:
        return _page(const ShellScreen());
      default:
        return _page(const SplashScreen(resolveRoute: _resolveLaunchDestination));
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);
}
