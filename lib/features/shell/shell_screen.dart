import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pixel_nav_bar.dart';
import '../calendar/screens/calendar_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../vault/screens/vault_screen.dart';
import 'shell_tabs.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  static const List<Widget> _screens = [
    DashboardScreen(),
    CalendarScreen(),
    VaultScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ShellTabs(),
      child: Consumer<ShellTabs>(
        builder: (context, tabs, _) => PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: AppColors.navy,
            body: IndexedStack(index: tabs.value.index, children: _screens),
            bottomNavigationBar: PixelNavBar(
              currentIndex: tabs.value.index,
              onTap: (i) => tabs.open(ShellTab.values[i]),
            ),
          ),
        ),
      ),
    );
  }
}
