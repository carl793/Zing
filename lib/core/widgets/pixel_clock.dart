import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Counts up in steps, like an old game's clock, so idle animations redraw a
/// few times a second instead of on every frame the phone can show.
///
/// Stops while it's out of sight: on a hidden tab, under another screen, or
/// with the app in the background. Also stops when the phone asks for less
/// motion.
class PixelClock extends StatefulWidget {
  final Duration step;
  final bool running;
  final Widget Function(BuildContext context, ValueListenable<int> tick) builder;

  const PixelClock({
    super.key,
    required this.step,
    required this.builder,
    this.running = true,
  });

  @override
  State<PixelClock> createState() => _PixelClockState();
}

class _PixelClockState extends State<PixelClock> {
  final _tick = ValueNotifier<int>(0);
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _setVisible(false),
      onShow: () => _setVisible(true),
    );
  }

  void _setVisible(bool visible) {
    _appVisible = visible;
    _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(PixelClock old) {
    super.didUpdateWidget(old);
    _update();
  }

  void _update() {
    final wanted = widget.running &&
        _appVisible &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (!wanted) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(widget.step, (_) => _tick.value++);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _tick);
}
