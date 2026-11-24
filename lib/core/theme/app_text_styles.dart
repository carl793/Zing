import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale. Press Start 2P is drawn on an 8-pixel grid and is hard to
/// read any smaller, so 8 is the minimum.
///
/// Capitals for titles, labels, buttons and statuses; sentences for anything
/// meant to be read.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Press Start 2P';

  /// A hard shadow, for titles and big numbers.
  static const List<Shadow> pop = [
    Shadow(color: AppColors.ink, offset: Offset(2, 2)),
  ];

  /// Big numbers: distance, countdowns, the pairing code.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    color: AppColors.yellow,
    height: 1.3,
    shadows: pop,
  );

  /// Screen titles.
  static const TextStyle header = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    color: AppColors.white,
    height: 1.4,
    shadows: pop,
  );

  /// Sheet and entry titles.
  static const TextStyle subHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    color: AppColors.white,
    height: 1.5,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    color: AppColors.white,
    height: 1.8,
  );
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    color: AppColors.white,
    height: 1.4,
  );

  /// Names above fields and values.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 8,
    color: AppColors.cyan,
    height: 1.5,
    letterSpacing: 0.5,
  );

  /// Hints, dates and other small print.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 8,
    color: AppColors.gray,
    height: 1.7,
  );
}
