import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_icon.dart';
import 'pixel_loader.dart';
import 'pixel_pressable.dart';

/// What a button means, not just its colour.
enum PixelButtonStyle {
  /// The main thing to do here.
  yellow(PixelTone.yellow),

  /// Anything that records love: memories, pairing.
  coral(PixelTone.coral),

  /// Plans, and anything about the partner.
  cyan(PixelTone.cyan),

  /// Everything else.
  neutral(PixelTone.neutral),

  /// Deletes, unlinks, throws away.
  danger(PixelTone.danger);

  const PixelButtonStyle(this.tone);
  final PixelTone tone;
}

/// A key that stands out of the screen and goes down when pressed.
class PixelButton extends StatelessWidget {
  final String label;
  final PixelIcons? icon;
  final VoidCallback? onPressed;
  final PixelButtonStyle style;

  /// Shows the loader in place of the icon and ignores presses.
  final bool busy;

  /// A shorter key, for use inside panels.
  final bool small;
  final AppSfx sfx;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PixelButtonStyle.yellow,
    this.busy = false,
    this.small = false,
    this.sfx = AppSfx.tap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final tone = enabled || busy ? style.tone : PixelTone.disabled;

    return PixelPressable(
      onPressed: enabled ? onPressed : null,
      sfx: sfx,
      builder: (context, pressed) => Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: small ? 44 : 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: PixelRaised(tone: tone, pressed: pressed || busy),
        child: Center(
          heightFactor: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  PixelLoader(size: 4, color: tone.text),
                  const SizedBox(width: AppSpacing.sm),
                ] else if (icon != null) ...[
                  PixelIcon(icon!, color: tone.text),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  label,
                  style: AppTextStyles.button.copyWith(color: tone.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A square key holding only an icon.
class PixelIconButton extends StatelessWidget {
  final PixelIcons icon;

  /// Read aloud, since there is no text.
  final String label;
  final VoidCallback? onPressed;
  final PixelTone tone;
  final double size;
  final AppSfx sfx;

  /// A dot in the corner: something here needs attention.
  final bool dot;

  const PixelIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = PixelTone.neutral,
    this.size = 44,
    this.sfx = AppSfx.tap,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final shown = onPressed == null ? PixelTone.disabled : tone;
    final small = size < 40;
    final key = PixelPressable(
      onPressed: onPressed,
      semanticLabel: label,
      sfx: sfx,
      builder: (context, pressed) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: PixelRaised(
          tone: shown,
          pressed: pressed,
          depth: small ? 3 : 4,
          shadow: 2,
        ),
        child: PixelIcon(icon, color: shown.text, size: small ? 12 : 18),
      ),
    );
    if (!dot) return key;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        key,
        const Positioned(top: -3, right: -3, child: PixelDot()),
      ],
    );
  }
}

/// A small square marker for something new.
class PixelDot extends StatelessWidget {
  final Color color;
  const PixelDot({super.key, this.color = AppColors.coral});

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: PixelOutline(color: AppColors.ink, fill: color),
      );
}

/// Words that can be pressed, for the quieter choices on a screen.
class PixelLink extends StatelessWidget {
  final String label;
  final PixelIcons? icon;
  final VoidCallback? onPressed;
  final Color color;

  const PixelLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    final shown = onPressed == null ? AppColors.faint : color;
    return PixelPressable(
      onPressed: onPressed,
      sfx: AppSfx.tick,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        transform: Matrix4.translationValues(0, pressed ? 2 : 0, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              PixelIcon(icon!, color: shown),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: shown,
                  decoration: TextDecoration.underline,
                  decorationColor: shown.withValues(alpha: 0.5),
                  decorationThickness: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
