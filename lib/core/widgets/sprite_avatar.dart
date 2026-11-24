import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/sprite_options.dart';
import '../services/audio_service.dart';
import 'pixel_clock.dart';

/// Displays the selected character art, retaining emoji support for older IDs.
class SpriteAvatar extends StatelessWidget {
  final String spriteId;
  final double size;

  const SpriteAvatar({super.key, required this.spriteId, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final option = SpriteOptions.resolve(spriteId);
    final path = option.assetPath;
    final emoji = Center(
      child: Text(
        option.emojiFallback,
        style: TextStyle(fontSize: size * 0.6, height: 1),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: path == null
          ? emoji
          : path.endsWith('.svg')
              ? SvgPicture.asset(path, placeholderBuilder: (_) => emoji)
              : PixelImage(path, size: size, onError: emoji),
    );
  }
}

/// A 96-pixel sprite, kept sharp when enlarged and smooth when shrunk.
class PixelImage extends StatelessWidget {
  final String asset;
  final double size;
  final Widget? onError;
  final String? semanticLabel;

  const PixelImage(
    this.asset, {
    super.key,
    required this.size,
    this.onError,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scale = size * MediaQuery.devicePixelRatioOf(context) / 96;
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: scale >= 1.75 ? FilterQuality.none : FilterQuality.medium,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, _, _) => onError ?? const SizedBox.shrink(),
    );
  }
}

/// The mystery box every chest is drawn with.
class ChestImage extends StatelessWidget {
  final double size;
  const ChestImage({super.key, required this.size});

  @override
  Widget build(BuildContext context) =>
      PixelImage('assets/sprites/mystery_box_96.png', size: size);
}

/// Moves [child] up and down in steps, like an idling sprite, and makes it hop
/// when touched.
class SpriteIdle extends StatefulWidget {
  final Widget child;

  /// Starts half a beat later, so two sprites don't move as one.
  final bool offBeat;
  final bool canHop;

  const SpriteIdle({
    super.key,
    required this.child,
    this.offBeat = false,
    this.canHop = true,
  });

  @override
  State<SpriteIdle> createState() => _SpriteIdleState();
}

class _SpriteIdleState extends State<SpriteIdle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  void _onTap() {
    AudioService.instance
      ..playSfx(AppSfx.hop)
      ..knock();
    _hop.forward(from: 0);
  }

  double _lift(int tick) {
    if (_hop.isAnimating) {
      final t = _hop.value * 2 - 1;
      return ((1 - t * t) * 8).floor() * 2.0;
    }
    return tick.isEven == widget.offBeat ? 2 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final moving = PixelClock(
      step: const Duration(milliseconds: 700),
      builder: (_, tick) => AnimatedBuilder(
        animation: Listenable.merge([tick, _hop]),
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -_lift(tick.value)),
          child: child,
        ),
        child: RepaintBoundary(child: widget.child),
      ),
    );
    if (!widget.canHop) return moving;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: moving,
    );
  }
}
