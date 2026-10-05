import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/sprite_select_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/pairing/screens/pairing_screen.dart';
import '../../features/pairing/screens/pairing_success_screen.dart';
import '../../features/shell/shell_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const welcome = '/welcome';
  static const spriteSelect = '/sprite-select';
  static const forgotPassword = '/forgot-password';
  static const pairing = '/pairing';
  static const pairingSuccess = '/pairing-success';
  static const shell = '/shell';

  // Convenience getters — push these to deep-link into a specific tab
  static const dashboard = '/shell';     // index 0
  static const calendar = '/calendar';   // handled by shell tab 1
  static const vault = '/vault';         // handled by shell tab 2
  static const settings = '/settings';   // handled by shell tab 3
}

class AppRouter {
  AppRouter._();

  /// Resolves the correct initial route on app launch.
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
    final coupleId = data['coupleId'] as String?;

    if (displayName.isEmpty) return AppRoutes.spriteSelect;
    if (coupleId == null || coupleId.isEmpty) return AppRoutes.pairing;
    return AppRoutes.shell;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );

      case AppRoutes.spriteSelect:
        return MaterialPageRoute(
          builder: (_) => const SpriteSelectScreen(),
        );

      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
        );

      case AppRoutes.pairing:
        return MaterialPageRoute(
          builder: (_) => const PairingScreen(),
        );

      case AppRoutes.pairingSuccess:
        return MaterialPageRoute(
          builder: (_) => const PairingSuccessScreen(),
        );

      case AppRoutes.shell:
        return MaterialPageRoute(
          builder: (_) => const ShellScreen(initialIndex: 0),
        );

      // Deep-link into specific tabs via named routes
      case AppRoutes.calendar:
        return MaterialPageRoute(
          builder: (_) => const ShellScreen(initialIndex: 1),
        );

      case AppRoutes.vault:
        return MaterialPageRoute(
          builder: (_) => const ShellScreen(initialIndex: 2),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const ShellScreen(initialIndex: 3),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF1B1B2F),
            body: Center(
              child: Text(
                'NO ROUTE: ${settings.name}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ),
          ),
        );
    }
  }
}