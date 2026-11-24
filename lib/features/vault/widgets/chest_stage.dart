import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/widgets/pixel_clock.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/sprite_avatar.dart';

/// A chest on its pedestal. A locked one rattles when touched; an open one
/// floats in turning rays of light.
class ChestStage extends StatefulWidget {
  final bool open;
  final double size;
  const ChestStage({super.key, required this.open, this.size = 128});

  @override
  State<ChestStage> createState() => _ChestStageState();
}

class _ChestStageState extends State<ChestStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rattle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _rattle.dispose();
    super.dispose();
  }

  void _onTap() {
    AudioService.instance
      ..playSfx(AppSfx.error)
      ..knock(strong: true);
    _rattle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final chest = ChestImage(size: size);

    return SizedBox(
      height: size + 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.open)
            Positioned.fill(
              child: RepaintBoundary(
                child: PixelClock(
                  step: const Duration(milliseconds: 140),
                  builder: (_, tick) =>
                      CustomPaint(painter: _RaysPainter(tick)),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 1.15,
              height: 26,
              decoration: const PixelRaised(tone: PixelTone.neutral),
            ),
          ),
          Positioned(
            bottom: 14,
            child: widget.open
                ? SpriteIdle(child: chest)
                : GestureDetector(
                    onTap: _onTap,
                    child: AnimatedBuilder(
                      animation: _rattle,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(
                          _rattle.isAnimating
                              ? (math.sin(_rattle.value * math.pi * 8) * 3)
                                      .round() *
                                  2.0
                              : 0,
                          0,
                        ),
                        child: child,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          chest,
                          const Positioned(
                            right: 6,
                            bottom: 6,
                            child: PixelIcon(
                              PixelIcons.lock,
                              size: 36,
                              color: AppColors.yellow,
                              shadow: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final ValueListenable<int> tick;
  _RaysPainter(this.tick) : super(repaint: tick);

  /// Steps it takes one ray to reach the next.
  static const _steps = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..isAntiAlias = false
      ..color = AppColors.violet.withValues(alpha: 0.55);
    const rays = 10;
    final turn = tick.value % _steps / _steps * math.pi * 2 / rays;
    for (var i = 0; i < rays; i++) {
      final from = turn + i * math.pi * 2 / rays;
      final to = from + math.pi / rays;
      final reach = size.height * 0.5;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + math.cos(from) * reach,
              center.dy + math.sin(from) * reach)
          ..lineTo(
              center.dx + math.cos(to) * reach, center.dy + math.sin(to) * reach)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.tick != tick;
}
