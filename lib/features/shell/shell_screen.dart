import 'package:flutter/material.dart';
import '../../core/widgets/pixel_nav_bar.dart';
import '../calendar/screens/calendar_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../vault/screens/vault_screen.dart';

class ShellScreen extends StatefulWidget {
  final int initialIndex;
  const ShellScreen({super.key, this.initialIndex = 0});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  static const List<Widget> _screens = [
    DashboardScreen(),
    CalendarScreen(),
    VaultScreen(),
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