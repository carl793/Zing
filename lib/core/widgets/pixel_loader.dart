import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pixel_clock.dart';

/// Three blocks jumping in turn. Moves in steps, like a sprite.
class PixelLoader extends StatelessWidget {
  final double size;
  final Color color;
  const PixelLoader({super.key, this.size = 8, this.color = AppColors.yellow});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: RepaintBoundary(
          child: PixelClock(
            step: const Duration(milliseconds: 180),
            builder: (_, tick) => CustomPaint(
              size: Size(size * 5, size * 2),
              painter: _LoaderPainter(tick, size, color),
            ),
          ),
        ),
      );
}

class _LoaderPainter extends CustomPainter {
  final ValueListenable<int> tick;
  final double size;
  final Color color;
  _LoaderPainter(this.tick, this.size, this.color) : super(repaint: tick);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < 3; i++) {
      final up = tick.value % 3 == i;
      final rect = Rect.fromLTWH(
          i * size * 2, up ? 0 : canvasSize.height - size, size, size);
      if (size >= 6) {
        canvas.drawRect(rect.shift(const Offset(2, 2)),
            paint..color = AppColors.ink.withValues(alpha: 0.6));
      }
      canvas.drawRect(
          rect, paint..color = up ? color : color.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_LoaderPainter old) =>
      old.tick != tick || old.size != size || old.color != color;
}

/// The loader on its own, with an optional word under it.
class PixelLoading extends StatelessWidget {
  final String? label;
  const PixelLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelLoader(),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(label!, style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
      );
}
