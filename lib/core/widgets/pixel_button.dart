import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum PixelButtonStyle { coral, yellow, cyan, outline, outlineDanger }

class PixelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PixelButtonStyle style;

  /// Optional fill override (e.g. charcoal behind an outline button).
  final Color? backgroundColor;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PixelButtonStyle.coral,
    this.backgroundColor,
  });

  bool get _isOutline =>
      style == PixelButtonStyle.outline ||
      style == PixelButtonStyle.outlineDanger;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    final Color accent = style == PixelButtonStyle.outlineDanger
        ? AppColors.coral
        : AppColors.cyan;

    final Color fill = disabled
        ? const Color(0xFF555555)
        : backgroundColor ??
            switch (style) {
              PixelButtonStyle.coral => AppColors.coral,
              PixelButtonStyle.yellow => AppColors.yellow,
              PixelButtonStyle.cyan => AppColors.cyan,
              PixelButtonStyle.outline ||
              PixelButtonStyle.outlineDanger =>
                Colors.transparent,
            };

    final Color textColor = disabled
        ? const Color(0xFF888888)
        : (_isOutline ? accent : Colors.black);

    final Color borderColor = _isOutline ? accent : Colors.black;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color:
                        _isOutline ? accent.withOpacity(0.4) : Colors.black,
                    offset: const Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.button.copyWith(color: textColor),
        ),
      ),
    );
  }
}