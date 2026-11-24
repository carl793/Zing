import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/session_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pixel_icon.dart';
import '../../core/widgets/pixel_nav_bar.dart';
import '../../core/widgets/pixel_page.dart';
import '../../core/widgets/pixel_toast.dart';
import '../../data/repositories/capsule_repository.dart';
import '../../data/repositories/couple_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../calendar/screens/calendar_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../vault/controllers/vault_controller.dart';
import '../vault/screens/vault_screen.dart';
import 'shell_tabs.dart';

/// The main app for a linked player: the shared session and the four tabs.
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => SessionController(
            uid: ctx.read<AuthService>().currentUser!.uid,
            users: ctx.read<UserRepository>(),
            couples: ctx.read<CoupleRepository>(),
          ),
        ),
        // Not lazy: chests must open on time even if the Vault is never shown.
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) => VaultController(
            ctx.read<SessionController>(),
            ctx.read<CapsuleRepository>(),
            ctx.read<StorageService>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ShellTabs()),
      ],
      child: const _ShellView(),
    );
  }
}

class _ShellView extends StatefulWidget {
  const _ShellView();

  @override
  State<_ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<_ShellView> {
  static const List<Widget> _screens = [
    DashboardScreen(),
    CalendarScreen(),
    VaultScreen(),
    SettingsScreen(),
  ];

  /// Tabs opened so far. A tab is built the first time it's opened, so launch
  /// only loads the dashboard, and is then kept alive.
  final Set<ShellTab> _opened = {};

  late final SessionController _session;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionController>()..addListener(_onSession);
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    super.dispose();
  }

  /// Returns to pairing once the couple is unlinked, from either phone.
  void _onSession() {
    final end = _session.end;
    if (end == null || _leaving || !mounted) return;
    _leaving = true;
    if (end == SessionEnd.unlinkedByPartner) {
      showPixelToast(
        context,
        'YOUR PARTNER UNLINKED THE ROOM.',
        color: AppColors.coral,
      );
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.pairing, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<ShellTabs>();
    final chestWaiting =
        context.select<VaultController, bool>((v) => v.needsMyTap);
    _opened.add(tabs.value);

    return PopScope(
      // Back returns to the first tab, then leaves the app.
      canPop: tabs.value == ShellTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) tabs.open(ShellTab.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: PixelBackdrop(
          child: IndexedStack(
            index: tabs.value.index,
            children: [
              for (final tab in ShellTab.values)
                // Tabs out of sight stay loaded, but stop moving.
                TickerMode(
                  enabled: tab == tabs.value,
                  child: _opened.contains(tab)
                      ? _screens[tab.index]
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        bottomNavigationBar: PixelNavBar(
          items: [
            const PixelNavItem(PixelIcons.home, 'HOME'),
            const PixelNavItem(PixelIcons.calendar, 'CALENDAR'),
            PixelNavItem(PixelIcons.chest, 'VAULT', dot: chestWaiting),
            const PixelNavItem(PixelIcons.gear, 'CONFIG'),
          ],
          currentIndex: tabs.value.index,
          onTap: (i) => tabs.open(ShellTab.values[i]),
        ),
      ),
    );
  }
}
