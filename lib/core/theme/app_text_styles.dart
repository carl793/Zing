import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Press Start 2P';

  static const TextStyle header = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    color: AppColors.cyan,
    height: 1.4,
  );
  static const TextStyle subHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    color: AppColors.cyan,
    height: 1.5,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 8,
    color: Colors.white,
    height: 1.7,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 7,
    color: AppColors.cyan,
    letterSpacing: 0.5,
  );
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    color: Colors.black,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 6,
    color: AppColors.gray,
  );
  static const TextStyle error = TextStyle(
    fontFamily: fontFamily,
    fontSize: 7,
    color: AppColors.coral,
    height: 1.7,
  );
}
