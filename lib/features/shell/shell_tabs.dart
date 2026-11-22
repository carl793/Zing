import 'package:flutter/foundation.dart';

/// The shell's tabs, in nav-bar order.
enum ShellTab { overworld, calendar, vault, config }

/// The selected shell tab. Screens inside the shell switch tabs through this
/// (e.g. the dashboard's LOG MEMORY button) instead of pushing routes, so
/// each tab, and the controller behind it, exists exactly once.
class ShellTabs extends ValueNotifier<ShellTab> {
  ShellTabs([super.value = ShellTab.overworld]);

  void open(ShellTab tab) => value = tab;
}
