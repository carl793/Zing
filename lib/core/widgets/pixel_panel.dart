import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_icon.dart';

/// A raised block holding one topic, with an optional title bar.
class PixelPanel extends StatelessWidget {
  final String? title;
  final PixelIcons? icon;
  final Color titleColor;

  /// Sits at the end of the title bar.
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color outline;

  const PixelPanel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.titleColor = AppColors.cyan,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.outline = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PixelRaised(outline: outline, shadow: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            PixelTitleBar(
              title: title!,
              icon: icon,
              color: titleColor,
              trailing: trailing,
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// The strip along the top of a panel or sheet.
class PixelTitleBar extends StatelessWidget {
  final String title;
  final PixelIcons? icon;
  final Color color;
  final Widget? trailing;

  const PixelTitleBar({
    super.key,
    required this.title,
    this.icon,
    this.color = AppColors.cyan,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 6, trailing == null ? 12 : 6, 6),
      decoration: const BoxDecoration(
        color: Color(0x33000020),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1C1A3F), width: kPixel),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            PixelIcon(icon!, color: color),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.button.copyWith(color: color),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A carved area for something shown rather than pressed.
class PixelWell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color outline;

  const PixelWell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.outline = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: PixelInset(outline: outline),
        child: child,
      );
}

/// A message lying flat on the screen: an error, a warning or a hint.
class PixelNote extends StatelessWidget {
  final String message;
  final Color color;
  final PixelIcons icon;

  const PixelNote(
    this.message, {
    super.key,
    this.color = AppColors.gray,
    this.icon = PixelIcons.info,
  });

  const PixelNote.error(this.message, {super.key})
      : color = AppColors.coral,
        icon = PixelIcons.warning;

  const PixelNote.warning(this.message, {super.key})
      : color = AppColors.amber,
        icon = PixelIcons.warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: PixelOutline(color: color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelIcon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bar that fills block by block.
class PixelProgressBar extends StatelessWidget {
  /// 0 to 1.
  final double value;
  final PixelTone tone;
  final int blocks;

  const PixelProgressBar({
    super.key,
    required this.value,
    this.tone = PixelTone.yellow,
    this.blocks = 16,
  });

  @override
  Widget build(BuildContext context) {
    final safe = value.clamp(0.0, 1.0);
    // Anything started shows one block; only done shows them all.
    final filled = safe >= 1
        ? blocks
        : (safe * blocks).floor().clamp(safe > 0 ? 1 : 0, blocks - 1);
    return Semantics(
      label: '${(safe * 100).floor()} percent',
      child: Container(
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: const PixelInset(),
        child: Row(
          children: [
            for (var i = 0; i < blocks; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: i < filled
                      ? BoxDecoration(
                          color: tone.face,
                          border: Border(
                            top: BorderSide(color: tone.light, width: 2),
                            bottom: BorderSide(color: tone.shade, width: 2),
                          ),
                        )
                      : const BoxDecoration(color: Color(0xFF211F47)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What to show when there is nothing to show.
class PixelEmpty extends StatelessWidget {
  final Widget art;
  final String title;
  final String message;
  final Widget? action;

  const PixelEmpty({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: art),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.button.copyWith(color: AppColors.yellow),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      );
}
