import 'dart:async';

import 'package:flutter/material.dart';

import '../services/audio_service.dart';

/// Anything that can be pressed: it goes down, clicks and knocks under the
/// finger, then comes back up. [builder] draws it in either position.
class PixelPressable extends StatefulWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget Function(BuildContext context, bool pressed) builder;
  final AppSfx sfx;

  /// What screen readers announce. Null keeps the text inside.
  final String? semanticLabel;
  final bool? selected;
  final bool? toggled;

  const PixelPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.onLongPress,
    this.sfx = AppSfx.tap,
    this.semanticLabel,
    this.selected,
    this.toggled,
  });

  @override
  State<PixelPressable> createState() => _PixelPressableState();
}

class _PixelPressableState extends State<PixelPressable> {
  /// Long enough for even the quickest tap to be seen going down.
  static const _minimumPress = Duration(milliseconds: 90);

  bool _pressed = false;
  DateTime _since = DateTime(0);
  Timer? _release;

  bool get _enabled => widget.onPressed != null;

  void _down() {
    _release?.cancel();
    _since = DateTime.now();
    AudioService.instance
      ..playSfx(widget.sfx)
      ..knock();
    setState(() => _pressed = true);
  }

  void _up() {
    final wait = _minimumPress - DateTime.now().difference(_since);
    _release?.cancel();
    if (wait <= Duration.zero) {
      if (mounted) setState(() => _pressed = false);
      return;
    }
    _release = Timer(wait, () {
      if (mounted) setState(() => _pressed = false);
    });
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.semanticLabel;
    final child = widget.builder(context, _pressed && _enabled);
    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _down() : null,
        onTapUp: _enabled ? (_) => _up() : null,
        onTapCancel: _enabled ? _up : null,
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                AudioService.instance.knock(strong: true);
                _up();
                widget.onLongPress!();
              },
        child: label == null ? child : ExcludeSemantics(child: child),
      ),
    );
  }
}
