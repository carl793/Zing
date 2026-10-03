import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/sprite_select_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/pairing/screens/pairing_screen.dart';
import '../../features/pairing/screens/pairing_success_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const welcome = '/welcome';
  static const spriteSelect = '/sprite-select';
  static const forgotPassword = '/forgot-password';
  static const pairing = '/pairing';
  static const pairingSuccess = '/pairing-success';
  static const dashboard = '/dashboard';
  static const calendar = '/calendar';
  static const vault = '/vault'; // wired once dashboard is built
}

class AppRouter {
  AppRouter._();

  /// Smart entry point: called from app.dart on launch.
  /// Returns the correct initial route based on auth + profile + couple state.
  static Future<String> resolveInitialRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return AppRoutes.welcome;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return AppRoutes.welcome;

    final data = doc.data()!;
    final displayName = data['displayName'] as String? ?? '';
    final coupleId = data['coupleId'] as String?;

    if (displayName.isEmpty) return AppRoutes.spriteSelect;
    if (coupleId == null || coupleId.isEmpty) return AppRoutes.pairing;
    return AppRoutes
        .dashboard; // will show placeholder until dashboard is built
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case AppRoutes.spriteSelect:
        return MaterialPageRoute(builder: (_) => const SpriteSelectScreen());
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case AppRoutes.pairing:
        return MaterialPageRoute(builder: (_) => const PairingScreen());
      case AppRoutes.pairingSuccess:
        return MaterialPageRoute(builder: (_) => const PairingSuccessScreen());
      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());

      case AppRoutes.calendar:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF1B1B2F),
            body: Center(
              child: Text(
                'CALENDAR COMING SOON',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ),
          ),
        );

      case AppRoutes.vault:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF1B1B2F),
            body: Center(
              child: Text(
                'VAULT COMING SOON',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              Scaffold(body: Center(child: Text('No route: ${settings.name}'))),
        );
    }
  }
}
