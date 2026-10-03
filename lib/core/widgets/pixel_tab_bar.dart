import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PixelTabBar extends StatelessWidget {
  final List<String> labels; // exactly 2
  final int activeIndex;
  final ValueChanged<int> onTap;

  const PixelTabBar({super.key, required this.labels, required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final active = i == activeIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? AppColors.yellow : Colors.transparent,
                border: Border.all(color: Colors.black, width: 2),
              ),
              alignment: Alignment.center,
              child: Text('[ ${labels[i]} ]',
                  style: AppTextStyles.button.copyWith(color: active ? Colors.black : Colors.white)),
            ),
          ),
        );
      }),
    );
  }
}