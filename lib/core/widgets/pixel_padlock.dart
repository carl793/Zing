import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Pixel-art padlock drawn with basic shapes — no image asset needed.
class PixelPadlock extends StatelessWidget {
  final double size;
  const PixelPadlock({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(painter: _PadlockPainter()),
    );
  }
}

class _PadlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final yellow = Paint()..color = AppColors.yellow;
    final black = Paint()..color = Colors.black;
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final w = size.width;
    final h = size.height;

    // Shackle (top arc)
    final shackleRect = Rect.fromLTWH(w * 0.28, 0, w * 0.44, h * 0.48);
    canvas.drawArc(shackleRect, 3.14, 3.14, false,
        Paint()
          ..color = AppColors.yellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.12);
    canvas.drawArc(shackleRect, 3.14, 3.14, false, stroke..strokeWidth = 2);

    // Body
    final body = Rect.fromLTWH(w * 0.08, h * 0.42, w * 0.84, h * 0.52);
    canvas.drawRect(body, yellow);
    canvas.drawRect(body, stroke..strokeWidth = 2);

    // Keyhole
    final kx = w / 2;
    final ky = h * 0.66;
    canvas.drawCircle(Offset(kx, ky), w * 0.08, black);
    canvas.drawRect(
      Rect.fromLTWH(kx - w * 0.04, ky, w * 0.08, h * 0.14),
      black,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}