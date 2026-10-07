import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/sprite_options.dart';

/// Displays the selected character art, retaining emoji support for older IDs.
class SpriteAvatar extends StatelessWidget {
  final String spriteId;
  final double size;
  final Color? backgroundColor;

  const SpriteAvatar({
    super.key,
    required this.spriteId,
    this.size = 48,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final option = SpriteOptions.resolve(spriteId);
    final assetPath = option.assetPath;
    final art = assetPath == null
        ? _emoji(option, size)
        : assetPath.toLowerCase().endsWith('.svg')
        ? SvgPicture.asset(
            assetPath,
            width: size * 0.9,
            height: size * 0.9,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => _emoji(option, size),
          )
        : Image.asset(
            assetPath,
            width: size * 0.9,
            height: size * 0.9,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) => _emoji(option, size),
          );

    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: backgroundColor ?? Colors.transparent,
        child: Center(child: art),
      ),
    );
  }

  Widget _emoji(SpriteOption option, double size) =>
      Text(option.emojiFallback, style: TextStyle(fontSize: size * 0.58));
}

/// SVG image helper for non-character pixel art, with a PNG fallback.
class SpriteAssetIcon extends StatelessWidget {
  final String assetPath;
  final String fallbackPath;
  final double size;
  final String semanticsLabel;

  const SpriteAssetIcon({
    super.key,
    required this.assetPath,
    required this.fallbackPath,
    required this.size,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    assetPath,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticsLabel: semanticsLabel,
    placeholderBuilder: (_) => Image.asset(
      fallbackPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}
