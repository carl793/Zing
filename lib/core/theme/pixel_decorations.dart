import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The size of one "pixel" of the artwork: outlines, bevels, corner notches.
const double kPixel = 2;

const double _notch = kPixel * 1.5;

/// Fills [rect] with each corner cut out by [notch]. The three strips never
/// overlap, so translucent colours stay even.
void paintNotched(Canvas canvas, Rect rect, double notch, Paint paint) {
  if (rect.width <= 0 || rect.height <= 0) return;
  final n = notch.clamp(0.0, rect.shortestSide / 2);
  canvas
    ..drawRect(
        Rect.fromLTRB(rect.left + n, rect.top, rect.right - n, rect.top + n),
        paint)
    ..drawRect(
        Rect.fromLTRB(rect.left, rect.top + n, rect.right, rect.bottom - n),
        paint)
    ..drawRect(
        Rect.fromLTRB(
            rect.left + n, rect.bottom - n, rect.right - n, rect.bottom),
        paint);
}

Path _notchedPath(Rect r, double n) => Path()
  ..moveTo(r.left + n, r.top)
  ..lineTo(r.right - n, r.top)
  ..lineTo(r.right - n, r.top + n)
  ..lineTo(r.right, r.top + n)
  ..lineTo(r.right, r.bottom - n)
  ..lineTo(r.right - n, r.bottom - n)
  ..lineTo(r.right - n, r.bottom)
  ..lineTo(r.left + n, r.bottom)
  ..lineTo(r.left + n, r.bottom - n)
  ..lineTo(r.left, r.bottom - n)
  ..lineTo(r.left, r.top + n)
  ..lineTo(r.left + n, r.top + n)
  ..close();

Paint _fill(Color color) => Paint()
  ..color = color
  ..isAntiAlias = false;

/// A solid block standing out of the screen: lit top edge, shaded lip below,
/// hard shadow behind. [pressed] pushes it down onto its lip; the space it
/// takes never changes, so nothing around it moves.
class PixelRaised extends Decoration {
  final PixelTone tone;
  final double depth;
  final bool pressed;

  /// Replaces the dark outline, e.g. to mark a selection.
  final Color outline;
  final double shadow;

  const PixelRaised({
    this.tone = PixelTone.panel,
    this.depth = 4,
    this.pressed = false,
    this.outline = AppColors.ink,
    this.shadow = 3,
  });

  @override
  EdgeInsetsGeometry get padding => pressed
      ? EdgeInsets.fromLTRB(kPixel, kPixel + depth, kPixel, kPixel)
      : EdgeInsets.fromLTRB(kPixel, kPixel, kPixel, kPixel + depth);

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) =>
      _notchedPath(rect, _notch);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _RaisedPainter(this);

  @override
  bool operator ==(Object other) =>
      other is PixelRaised &&
      other.tone == tone &&
      other.depth == depth &&
      other.pressed == pressed &&
      other.outline == outline &&
      other.shadow == shadow;

  @override
  int get hashCode => Object.hash(tone, depth, pressed, outline, shadow);
}

class _RaisedPainter extends BoxPainter {
  final PixelRaised style;
  _RaisedPainter(this.style);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final full = offset & configuration.size!;
    final depth = style.pressed ? 0.0 : style.depth;
    final block = Rect.fromLTRB(
      full.left,
      full.top + (style.depth - depth),
      full.right,
      full.bottom,
    );
    final tone = style.tone;

    if (style.shadow > 0 && !style.pressed) {
      paintNotched(
        canvas,
        block.shift(Offset(style.shadow, style.shadow)),
        _notch,
        _fill(AppColors.ink.withValues(alpha: 0.55)),
      );
    }
    paintNotched(canvas, block, _notch, _fill(style.outline));

    final inner = block.deflate(kPixel);
    if (depth > 0) paintNotched(canvas, inner, _notch, _fill(tone.shade));
    final face = Rect.fromLTRB(
        inner.left, inner.top, inner.right, inner.bottom - depth);
    if (face.height <= _notch * 2 || face.width <= _notch * 2) return;
    paintNotched(canvas, face, _notch, _fill(tone.face));

    // Light from the top left.
    canvas
      ..drawRect(
          Rect.fromLTWH(face.left + _notch, face.top, face.width - _notch * 2,
              kPixel),
          _fill(tone.light))
      ..drawRect(
          Rect.fromLTWH(face.left, face.top + _notch, kPixel,
              face.height - _notch * 2),
          _fill(tone.light.withValues(alpha: 0.45)))
      ..drawRect(
          Rect.fromLTWH(face.right - kPixel, face.top + _notch, kPixel,
              face.height - _notch * 2),
          _fill(tone.shade.withValues(alpha: 0.55)));
  }
}

/// A hole carved into a panel: shadow under its top edge, light on its lower
/// lip.
class PixelInset extends Decoration {
  final Color color;
  final Color outline;

  const PixelInset({
    this.color = AppColors.charcoal,
    this.outline = AppColors.ink,
  });

  static const Color _lip = Color(0xFF56529B);

  @override
  EdgeInsetsGeometry get padding =>
      const EdgeInsets.fromLTRB(kPixel, kPixel, kPixel, kPixel * 2);

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) =>
      _notchedPath(rect, _notch);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _InsetPainter(this);

  @override
  bool operator ==(Object other) =>
      other is PixelInset && other.color == color && other.outline == outline;

  @override
  int get hashCode => Object.hash(color, outline);
}

class _InsetPainter extends BoxPainter {
  final PixelInset style;
  _InsetPainter(this.style);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final full = offset & configuration.size!;
    final hole =
        Rect.fromLTRB(full.left, full.top, full.right, full.bottom - kPixel);
    paintNotched(canvas, hole.shift(const Offset(0, kPixel)), _notch,
        _fill(PixelInset._lip));
    paintNotched(canvas, hole, _notch, _fill(style.outline));
    final inner = hole.deflate(kPixel);
    if (inner.height <= _notch * 2 || inner.width <= _notch * 2) return;
    paintNotched(canvas, inner, _notch, _fill(style.color));
    final shade = _fill(AppColors.ink.withValues(alpha: 0.6));
    canvas
      ..drawRect(
          Rect.fromLTWH(inner.left + _notch, inner.top,
              inner.width - _notch * 2, kPixel * 2),
          shade)
      ..drawRect(
          Rect.fromLTWH(inner.left, inner.top + _notch, kPixel,
              inner.height - _notch * 2),
          shade);
  }
}

/// A thin frame with notched corners, for tags and notes that lie flat.
class PixelOutline extends Decoration {
  final Color color;
  final Color? fill;
  const PixelOutline({required this.color, this.fill = AppColors.charcoal});

  @override
  EdgeInsetsGeometry get padding => const EdgeInsets.all(kPixel);

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) =>
      _notchedPath(rect, kPixel);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _OutlinePainter(this);

  @override
  bool operator ==(Object other) =>
      other is PixelOutline && other.color == color && other.fill == fill;

  @override
  int get hashCode => Object.hash(color, fill);
}

class _OutlinePainter extends BoxPainter {
  final PixelOutline style;
  _OutlinePainter(this.style);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final r = offset & configuration.size!;
    const n = kPixel;
    final fill = style.fill;
    if (fill != null) canvas.drawRect(r.deflate(n), _fill(fill));
    final line = _fill(style.color);
    canvas
      ..drawRect(Rect.fromLTRB(r.left + n, r.top, r.right - n, r.top + n), line)
      ..drawRect(
          Rect.fromLTRB(r.left + n, r.bottom - n, r.right - n, r.bottom), line)
      ..drawRect(
          Rect.fromLTRB(r.left, r.top + n, r.left + n, r.bottom - n), line)
      ..drawRect(
          Rect.fromLTRB(r.right - n, r.top + n, r.right, r.bottom - n), line);
  }
}
