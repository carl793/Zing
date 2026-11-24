import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/widgets/pixel_clock.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/sprite_avatar.dart';

/// The two players in their world: on two islands while apart, with a heart
/// travelling between them, and on one island once they're together. The sky
/// follows this phone's time of day.
class OverworldScene extends StatelessWidget {
  final String? mySprite;
  final String? partnerSprite;
  final bool together;

  /// The distance, between the islands.
  final String value;
  final String caption;

  /// The hour the sky shows. Null is now.
  final int? hour;

  const OverworldScene({
    super.key,
    required this.mySprite,
    required this.partnerSprite,
    required this.together,
    required this.value,
    required this.caption,
    this.hour,
  });

  static const double height = 184;
  static const double _sprite = 72;

  /// Outlined text stays readable on any sky.
  static const List<Shadow> _outline = [
    Shadow(color: AppColors.ink, offset: Offset(2, 0)),
    Shadow(color: AppColors.ink, offset: Offset(-2, 0)),
    Shadow(color: AppColors.ink, offset: Offset(0, 2)),
    Shadow(color: AppColors.ink, offset: Offset(0, -2)),
    Shadow(color: AppColors.ink, offset: Offset(2, 2)),
    Shadow(color: AppColors.ink, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final edge = together ? width / 2 - _sprite - 2 : 12.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _LandscapePainter(
                    _Sky.at(hour ?? DateTime.now().hour),
                    together: together,
                  ),
                  isComplex: true,
                ),
              ),
              RepaintBoundary(
                child: _Hearts(together: together),
              ),
              Positioned(
                left: edge,
                bottom: 44,
                child: _hero(mySprite),
              ),
              Positioned(
                right: edge,
                bottom: 44,
                child: _hero(partnerSprite, flip: true),
              ),
              Positioned(
                left: together ? 0 : _sprite + 18,
                right: together ? 0 : _sprite + 18,
                top: together ? 14 : 62,
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: AppTextStyles.display.copyWith(
                          fontSize: together ? 16 : 24,
                          shadows: _outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        caption,
                        style: AppTextStyles.button.copyWith(shadows: _outline),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(String? sprite, {bool flip = false}) => sprite == null ||
          sprite.isEmpty
      ? const SizedBox.square(dimension: _sprite)
      : SpriteIdle(
          offBeat: flip,
          child: Transform.flip(
            flipX: flip,
            child: SpriteAvatar(spriteId: sprite, size: _sprite),
          ),
        );
}

/// The colours of one time of day, from the top of the sky to the horizon.
class _Sky {
  final List<Color> bands;
  final Color light;
  final bool stars;
  final bool sun;
  const _Sky(this.bands, {required this.light, required this.stars, required this.sun});

  static const night = _Sky(
    [Color(0xFF12103A), Color(0xFF1B1852), Color(0xFF26226A), Color(0xFF342E82)],
    light: Color(0xFFFFF3C4),
    stars: true,
    sun: false,
  );
  static const dawn = _Sky(
    [Color(0xFF2F2A70), Color(0xFF6A3F86), Color(0xFFB9607F), Color(0xFFF59A7E)],
    light: Color(0xFFFFD98A),
    stars: true,
    sun: true,
  );
  static const day = _Sky(
    [Color(0xFF2C63B8), Color(0xFF3F82CF), Color(0xFF5CA4E0), Color(0xFF8CCBEF)],
    light: Color(0xFFFFE27A),
    stars: false,
    sun: true,
  );
  static const dusk = _Sky(
    [Color(0xFF231B5C), Color(0xFF5B2C79), Color(0xFFA33F77), Color(0xFFEF7A62)],
    light: Color(0xFFFFC25E),
    stars: true,
    sun: true,
  );

  static _Sky at(int hour) => switch (hour) {
        >= 5 && < 8 => dawn,
        >= 8 && < 17 => day,
        >= 17 && < 19 => dusk,
        _ => night,
      };
}

class _LandscapePainter extends CustomPainter {
  final _Sky sky;
  final bool together;
  const _LandscapePainter(this.sky, {required this.together});

  static const _u = 4.0;
  static const _sea = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    void rect(double l, double t, double w, double h, Color color) =>
        canvas.drawRect(Rect.fromLTWH(l, t, w, h), paint..color = color);
    final horizon = size.height - _sea;

    // Sky, with a dithered row where two bands meet.
    final bands = sky.bands.length;
    for (var i = 0; i < bands; i++) {
      final top = (horizon * i / bands / _u).floor() * _u;
      rect(0, top, size.width, horizon - top, sky.bands[i]);
      if (i == 0) continue;
      for (var x = 0.0; x < size.width; x += _u * 2) {
        rect(x, top - _u, _u, _u, sky.bands[i]);
      }
    }

    final random = math.Random(5);
    if (sky.stars) {
      for (var i = 0; i < 26; i++) {
        rect(
          (random.nextDouble() * size.width / _u).floor() * _u,
          (random.nextDouble() * horizon * 0.6 / _u).floor() * _u,
          2,
          2,
          AppColors.white.withValues(alpha: 0.35 + random.nextDouble() * 0.5),
        );
      }
    }

    // Sun or moon.
    void disc(double cx, double cy, Color color) {
      rect(cx - 12, cy - 8, 24, 16, color);
      rect(cx - 8, cy - 12, 16, 24, color);
    }

    // Off to the side once the couple takes the middle.
    final cx = (size.width * (together ? 0.1 : 0.5) / _u).floor() * _u;
    disc(cx, together ? 64 : 24, sky.light);
    // A bite out of it makes a moon.
    if (!sky.sun && !together) disc(cx + 8, 24, sky.bands[0]);
    if (!sky.stars) {
      for (final (x, y) in [(0.12, 22.0), (0.74, 38.0)]) {
        final left = (size.width * x / _u).floor() * _u;
        const cloud = Color(0xE6FFFFFF);
        rect(left + 8, y, 20, _u, cloud);
        rect(left, y + _u, 40, _u, cloud);
        rect(left + 4, y + _u * 2, 32, _u, const Color(0x99FFFFFF));
      }
    }

    // Two ridges of mountains.
    final back = Color.lerp(sky.bands.last, AppColors.night, 0.35)!;
    final front = Color.lerp(sky.bands.last, AppColors.night, 0.6)!;
    for (final (color, base, rise, wave) in [
      (back, 30.0, 26.0, 70.0),
      (front, 14.0, 16.0, 43.0),
    ]) {
      for (var x = 0.0; x < size.width; x += _u) {
        final ridge = (math.sin(x / wave) + math.sin(x / (wave * 0.37) + 2)) / 2;
        final h = ((base + rise * ridge.abs()) / _u).floor() * _u;
        rect(x, horizon - h, _u, h, color);
      }
    }

    // Sea, with a few still waves.
    rect(0, horizon, size.width, _sea, const Color(0xFF1C3C78));
    rect(0, horizon, size.width, _u, const Color(0xFF2C5AA0));
    for (var i = 0; i < 16; i++) {
      rect(
        (random.nextDouble() * size.width / _u).floor() * _u,
        horizon + 8 + (random.nextInt(6)) * _u,
        random.nextBool() ? 12 : 20,
        2,
        const Color(0xFF3B6DB8),
      );
    }

    // Islands.
    if (together) {
      _island(rect, size.width / 2 - 92, horizon, 184);
    } else {
      _island(rect, -8, horizon, 112);
      _island(rect, size.width - 104, horizon, 112);
    }
  }

  static void _island(
    void Function(double, double, double, double, Color) rect,
    double left,
    double horizon,
    double width,
  ) {
    final top = horizon - 10;
    const grass = Color(0xFF5FC96B);
    const grassDark = Color(0xFF3B9454);
    const earth = Color(0xFF8A5A44);
    const earthDark = Color(0xFF5E3A35);
    rect(left + 4, top - 2, width - 8, 2, AppColors.ink);
    rect(left + 4, top, width - 8, 6, grass);
    rect(left, top + 4, width, 6, grass);
    rect(left, top + 10, width, 4, grassDark);
    for (var x = left + 6; x < left + width - 8; x += 16) {
      rect(x, top + 14, 8, 4, grassDark);
    }
    rect(left + 4, top + 14, width - 8, 12, earth);
    for (var x = left + 6; x < left + width - 12; x += 16) {
      rect(x, top + 14, 8, 4, grassDark);
      rect(x + 10, top + 20, 4, 4, earthDark);
    }
    rect(left + 12, top + 26, width - 24, 6, earthDark);
  }

  @override
  bool shouldRepaint(_LandscapePainter old) =>
      old.sky != sky || old.together != together;
}

/// A heart flying between the islands, or hearts rising from the couple.
class _Hearts extends StatelessWidget {
  final bool together;
  const _Hearts({required this.together});

  @override
  Widget build(BuildContext context) => PixelClock(
        step: const Duration(milliseconds: 90),
        builder: (_, tick) =>
            CustomPaint(painter: _HeartPainter(tick, together)),
      );
}

class _HeartPainter extends CustomPainter {
  final ValueListenable<int> tick;
  final bool together;
  _HeartPainter(this.tick, this.together) : super(repaint: tick);

  /// Steps in one trip there and back.
  static const _trip = 48;

  static const _rows = ['.##.##.', '#######', '#######', '.#####.', '..###..', '...#...'];

  void _heart(Canvas canvas, Offset at, double unit, Color color) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = color;
    for (var y = 0; y < _rows.length; y++) {
      for (var x = 0; x < 7; x++) {
        if (_rows[y][x] == '#') {
          canvas.drawRect(
            Rect.fromLTWH(at.dx + x * unit, at.dy + y * unit, unit, unit),
            paint,
          );
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (together) {
      for (var i = 0; i < 4; i++) {
        final t = (tick.value % _trip / _trip + i / 4) % 1;
        final x = size.width / 2 + (i.isEven ? -1 : 1) * (14 + i * 9.0);
        final y = size.height - 104 - (t * 12).floor() * 2.0;
        _heart(canvas, Offset(x - 7, y), 2,
            AppColors.coral.withValues(alpha: (1 - t) > 0.5 ? 1 : 0.5));
      }
      return;
    }
    // An arc from one hero's head to the other's.
    const from = 86.0;
    final to = size.width - 86;
    Offset arc(double t) => Offset(
          from + (to - from) * t,
          74 - math.sin(t * math.pi) * 26,
        );
    final dot = Paint()
      ..isAntiAlias = false
      ..color = AppColors.white.withValues(alpha: 0.55);
    for (var i = 0; i <= 12; i++) {
      final p = arc(i / 12);
      canvas.drawRect(
          Rect.fromLTWH((p.dx / 2).floor() * 2, (p.dy / 2).floor() * 2, 2, 2),
          dot);
    }
    final step = tick.value % _trip;
    final p = arc((step < _trip / 2 ? step : _trip - step) / (_trip / 2));
    final at = Offset((p.dx / 2).floor() * 2 - 7, (p.dy / 2).floor() * 2 - 6);
    _heart(canvas, at.translate(2, 2), 2, AppColors.ink);
    _heart(canvas, at, 2, AppColors.coral);
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.tick != tick || old.together != together;
}

/// Both names, and how long they have been linked.
class PlayerHud extends StatelessWidget {
  final String myName;
  final String partnerName;
  final int? days;

  const PlayerHud({
    super.key,
    required this.myName,
    required this.partnerName,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Plate('P1', myName, PixelTone.coral)),
        SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelIcon(
                PixelIcons.heart,
                size: 24,
                color: AppColors.coral,
                shadow: true,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  days == null ? 'LINKED' : 'DAY $days',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.gray, letterSpacing: 0),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _Plate('P2', partnerName, PixelTone.cyan, right: true),
        ),
      ],
    );
  }
}

class _Plate extends StatelessWidget {
  final String slot;
  final String name;
  final PixelTone tone;
  final bool right;
  const _Plate(this.slot, this.name, this.tone, {this.right = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: PixelRaised(tone: tone, shadow: 2),
        child: Column(
          crossAxisAlignment:
              right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              slot,
              style: AppTextStyles.label.copyWith(
                color: tone.shade,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.button.copyWith(color: tone.text),
            ),
          ],
        ),
      );
}
