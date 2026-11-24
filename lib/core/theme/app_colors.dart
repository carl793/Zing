import 'package:flutter/material.dart';

/// Every colour in the app, from the back of the screen to the front.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color night = Color(0xFF11112A);
  static const Color navy = Color(0xFF1B1B3A);

  /// Raised panels.
  static const Color purple = Color(0xFF2F2C5E);

  /// Neutral buttons, raised above panels.
  static const Color violet = Color(0xFF464289);

  /// Wells carved into panels: fields, values, lists.
  static const Color charcoal = Color(0xFF161532);

  /// Outlines, hard shadows and text on bright colours.
  static const Color ink = Color(0xFF08081A);

  // Text
  static const Color white = Color(0xFFF5F2FF);
  static const Color gray = Color(0xFFB0ACDD);
  static const Color faint = Color(0xFF8581BE);

  // Accents. Yellow acts, coral is me, cyan is my partner.
  static const Color yellow = Color(0xFFFFDA47);
  static const Color cyan = Color(0xFF54DFF2);
  static const Color coral = Color(0xFFFF6B89);
  static const Color amber = Color(0xFFFFB648);
}

/// A colour with the lit and shaded edges that make it look solid.
class PixelTone {
  final Color face;
  final Color light;
  final Color shade;
  final Color text;

  const PixelTone({
    required this.face,
    required this.light,
    required this.shade,
    required this.text,
  });

  static const yellow = PixelTone(
    face: AppColors.yellow,
    light: Color(0xFFFFF3B8),
    shade: Color(0xFFBD8712),
    text: Color(0xFF2B1D00),
  );
  static const coral = PixelTone(
    face: AppColors.coral,
    light: Color(0xFFFFBDCA),
    shade: Color(0xFFB0304F),
    text: Color(0xFF30040F),
  );
  static const cyan = PixelTone(
    face: AppColors.cyan,
    light: Color(0xFFC9F8FF),
    shade: Color(0xFF17869F),
    text: Color(0xFF02232B),
  );
  static const amber = PixelTone(
    face: AppColors.amber,
    light: Color(0xFFFFE2B0),
    shade: Color(0xFFAD6B0B),
    text: Color(0xFF2B1800),
  );
  static const neutral = PixelTone(
    face: AppColors.violet,
    light: Color(0xFF6E69BE),
    shade: Color(0xFF282553),
    text: AppColors.white,
  );
  static const danger = PixelTone(
    face: Color(0xFF5B2748),
    light: Color(0xFF8E4069),
    shade: Color(0xFF34142A),
    text: Color(0xFFFFB3C2),
  );
  static const disabled = PixelTone(
    face: Color(0xFF3A3763),
    light: Color(0xFF48457A),
    shade: Color(0xFF252347),
    text: AppColors.faint,
  );
  static const panel = PixelTone(
    face: AppColors.purple,
    light: Color(0xFF4F4B92),
    shade: Color(0xFF1C1A3F),
    text: AppColors.white,
  );

  /// Mine is coral, my partner's is cyan, everywhere.
  static PixelTone player({required bool isMe}) => isMe ? coral : cyan;
}
