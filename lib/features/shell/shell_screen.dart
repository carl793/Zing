import 'package:flutter/material.dart';
import '../../core/widgets/pixel_nav_bar.dart';
import '../calendar/screens/calendar_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../settings/screens/settings_screen.dart';

class ShellScreen extends StatefulWidget {
  final int initialIndex;
  const ShellScreen({super.key, this.initialIndex = 0});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int _currentIndex;

  // Vault is still a placeholder until its module is built.
  static const _vaultStub = _StubScreen(
    label: 'TREASURE VAULT',
    icon: Icons.lock,
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  List<Widget> get _screens => const [
        DashboardScreen(),
        CalendarScreen(),
        _vaultStub,
        SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1B1B2F),
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: PixelNavBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

class _StubScreen extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StubScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF6B6B8C)),
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: Color(0xFF6B6B8C),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'COMING SOON',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: Color(0xFF4A4A6A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}