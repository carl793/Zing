import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/sprite_select_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/pairing/screens/pairing_screen.dart';
import '../../features/pairing/screens/pairing_success_screen.dart';
import '../../features/shell/shell_screen.dart';
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
  static const dashboard     = '/shell';
  static const calendar      = '/calendar';
  static const vault         = '/vault';
  static const settings      = '/settings';
}

class AppRouter {
  AppRouter._();

  static Future<String> resolveInitialRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return AppRoutes.welcome;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return AppRoutes.welcome;
    final data = doc.data()!;
    final displayName = (data['displayName'] as String?) ?? '';
    final coupleId    = data['coupleId']    as String?;
    if (displayName.isEmpty) return AppRoutes.spriteSelect;
    if (coupleId == null || coupleId.isEmpty) return AppRoutes.pairing;
    return AppRoutes.shell;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.launch:
        return _page(SplashScreen(resolveRoute: resolveInitialRoute));
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
        return _page(const ShellScreen(initialIndex: 0));
      case AppRoutes.calendar:
        return _page(const ShellScreen(initialIndex: 1));
      case AppRoutes.vault:
        return _page(const ShellScreen(initialIndex: 2));
      case AppRoutes.settings:
        return _page(const ShellScreen(initialIndex: 3));
      default:
        return _page(SplashScreen(resolveRoute: resolveInitialRoute));
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);
}
