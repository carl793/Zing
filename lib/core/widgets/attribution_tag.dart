import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// YOU / PARTNER chip. Mine = coral, partner = cyan (matches P1/P2 colours).
class AttributionTag extends StatelessWidget {
  final String label;
  final bool isMine;

  const AttributionTag({super.key, required this.label, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final color = isMine ? AppColors.coral : AppColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: color, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color, fontSize: 6),
      ),
    );
  }
}