import 'package:flutter/foundation.dart';

/// The shell's tabs, in nav-bar order.
enum ShellTab { home, calendar, vault, config }

/// Something to start on the tab that opens.
enum ShellAction { logToday, newChest }

/// The selected shell tab. Screens inside the shell switch tabs through this
/// (e.g. the home screen's LOG MEMORY button) instead of pushing routes, so
/// each tab, and the controller behind it, exists exactly once.
class ShellTabs extends ValueNotifier<ShellTab> {
  ShellTabs([super.value = ShellTab.home]);

  ShellAction? _pending;

  void open(ShellTab tab, {ShellAction? then}) {
    _pending = then;
    if (value == tab) {
      notifyListeners();
    } else {
      value = tab;
    }
  }

  /// True once, for the tab that should start [action].
  bool take(ShellAction action) {
    if (_pending != action) return false;
    _pending = null;
    return true;
  }
}
