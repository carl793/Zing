import 'package:flutter/foundation.dart';

/// A ChangeNotifier that ignores notifications after it is disposed, so async
/// work finishing late can't crash a screen that has already closed.
class SafeNotifier extends ChangeNotifier {
  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
