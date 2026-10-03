import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class OnboardingProgressBar extends StatelessWidget {
  final int currentStep; // 1 = login done, 2 = sprite done, 3 = paired
  const OnboardingProgressBar({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['LOGIN', 'SETUP', 'CONNECT'];
    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (i) {
            final done = i < currentStep;
            final active = i == currentStep - 1;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: done || active
                            ? AppColors.yellow
                            : AppColors.gray.withOpacity(0.3),
                        boxShadow: done || active
                            ? [
                                BoxShadow(
                                    color: AppColors.yellow.withOpacity(0.4),
                                    offset: const Offset(0, 2),
                                    blurRadius: 0)
                              ]
                            : [],
                      ),
                    ),
                  ),
                  if (i < steps.length - 1)
                    Container(width: 4, height: 6, color: Colors.black),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (i) {
            final active = i == currentStep - 1;
            final done = i < currentStep - 1;
            return Text(
              steps[i],
              style: AppTextStyles.caption.copyWith(
                color: done
                    ? AppColors.yellow
                    : active
                        ? AppColors.cyan
                        : AppColors.gray,
                fontSize: 6,
              ),
            );
          }),
        ),
      ],
    );
  }
}