import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_button.dart';
import 'pixel_icon.dart';

/// The night sky behind every screen. Painted once.
class PixelBackdrop extends StatelessWidget {
  final Widget child;
  const PixelBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _SkyPainter(), isComplex: true),
          ),
          child,
        ],
      );
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    // Flat bands instead of a smooth gradient.
    const bands = 7;
    for (var i = 0; i < bands; i++) {
      final top = size.height * i / bands;
      canvas.drawRect(
        Rect.fromLTRB(0, top.floorToDouble(), size.width,
            (top + size.height / bands).ceilToDouble()),
        paint
          ..color =
              Color.lerp(AppColors.navy, AppColors.night, i / (bands - 1))!,
      );
    }
    // The same stars every time.
    final random = math.Random(14);
    for (var i = 0; i < 70; i++) {
      final x = (random.nextDouble() * size.width / 4).floor() * 4.0;
      final y = (random.nextDouble() * size.height / 4).floor() * 4.0;
      final big = random.nextInt(9) == 0;
      paint.color = [
        const Color(0xFF2B2960),
        const Color(0xFF37346F),
        const Color(0xFF253A63),
      ][random.nextInt(3)];
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), paint);
      if (big) {
        canvas
          ..drawRect(Rect.fromLTWH(x - 2, y, 6, 2), paint)
          ..drawRect(Rect.fromLTWH(x, y - 2, 2, 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => false;
}

/// A screen's name, with room for its actions.
class PixelScreenTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PixelIcons? icon;
  final PixelTone tone;
  final Widget? trailing;

  /// Shows a back key in place of the icon.
  final VoidCallback? onBack;

  const PixelScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = PixelTone.cyan,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          if (onBack != null) ...[
            PixelIconButton(
              icon: PixelIcons.left,
              label: 'Back',
              sfx: AppSfx.close,
              onPressed: onBack,
            ),
            const SizedBox(width: AppSpacing.md),
          ] else if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: PixelRaised(tone: tone, shadow: 2),
              child: Center(
                child: PixelIcon(icon!, color: tone.text, size: 18),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: AppTextStyles.header),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// The strip that keeps a screen's main actions in reach of a thumb.
class PixelActionBar extends StatelessWidget {
  final Widget child;
  const PixelActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 10, AppSpacing.lg, 10),
        decoration: const BoxDecoration(
          color: Color(0xE611112A),
          border: Border(top: BorderSide(color: AppColors.ink, width: kPixel)),
        ),
        child: child,
      );
}

/// A full screen pushed over the tabs: title, scrolling body, actions.
class PixelPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? actions;
  final VoidCallback? onBack;

  const PixelPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.night,
        body: PixelBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PixelScreenTitle(
                      title: title,
                      subtitle: subtitle,
                      onBack: onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg + 4, AppSpacing.xl),
                        child: child,
                      ),
                    ),
                    if (actions != null) PixelActionBar(child: actions!),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Keeps a tab's content in a comfortable column on wide screens.
class PixelColumn extends StatelessWidget {
  final Widget child;
  const PixelColumn({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: child,
        ),
      );
}
