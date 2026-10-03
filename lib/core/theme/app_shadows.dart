import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  // Hard pixel pop-out shadow — used on buttons and cards
  static List<BoxShadow> pop({double offset = 4, Color color = Colors.black}) => [
        BoxShadow(color: color, offset: Offset(offset, offset), blurRadius: 0),
      ];

  // Inset look for text fields — simulated via a darker border + inner color
  // Flutter doesn't support true CSS inset shadows, so we fake it with
  // a slightly lighter inner container and a dark top-left border treatment
  static BoxDecoration insetField({bool hasError = false, bool hasFocus = false}) => BoxDecoration(
        color: const Color(0xFF121324),
        border: Border(
          top: BorderSide(color: hasError ? const Color(0xFFFF5376) : const Color(0xFF000000), width: 2),
          left: BorderSide(color: hasError ? const Color(0xFFFF5376) : const Color(0xFF000000), width: 2),
          bottom: BorderSide(color: hasError ? const Color(0xFFFF5376) : hasFocus ? const Color(0xFF00E5FF) : const Color(0xFF3D3B6B), width: 2),
          right: BorderSide(color: hasError ? const Color(0xFFFF5376) : hasFocus ? const Color(0xFF00E5FF) : const Color(0xFF3D3B6B), width: 2),
        ),
      );
}