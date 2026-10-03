import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum PixelButtonStyle { coral, yellow, outline }

class PixelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PixelButtonStyle style;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PixelButtonStyle.coral,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;

    final Color fill = disabled
        ? const Color(0xFF555555)
        : switch (style) {
            PixelButtonStyle.coral => AppColors.coral,
            PixelButtonStyle.yellow => AppColors.yellow,
            PixelButtonStyle.outline => Colors.transparent,
          };

    final Color textColor = disabled
        ? const Color(0xFF888888)
        : (style == PixelButtonStyle.outline ? AppColors.cyan : Colors.black);

    final Color borderColor =
        style == PixelButtonStyle.outline ? AppColors.cyan : Colors.black;

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
                    color: style == PixelButtonStyle.outline
                        ? AppColors.cyan.withOpacity(0.4)
                        : Colors.black,
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