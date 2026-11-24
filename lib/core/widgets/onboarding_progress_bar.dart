import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_icon.dart';

/// How far through setting up the player is. [currentStep] counts from 1.
class OnboardingProgressBar extends StatelessWidget {
  final int currentStep;
  const OnboardingProgressBar({super.key, required this.currentStep});

  static const _steps = ['LOGIN', 'HERO', 'CONNECT'];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, box) {
              final step = box.maxWidth / _steps.length;
              return Stack(
                children: [
                  for (var i = 1; i < _steps.length; i++)
                    Positioned(
                      left: step * (i - 0.5),
                      width: step,
                      top: 14,
                      height: 4,
                      child: ColoredBox(
                        color: i < currentStep
                            ? AppColors.yellow
                            : AppColors.violet,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) Expanded(child: _step(i)),
          ],
        ),
      ],
    );
  }

  Widget _step(int i) {
    final done = i < currentStep - 1;
    final active = i == currentStep - 1;
    final tone = done || active ? PixelTone.yellow : PixelTone.disabled;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: PixelRaised(tone: tone, shadow: 2, depth: 3),
          child: Center(
            child: done
                ? PixelIcon(PixelIcons.check, color: tone.text)
                : Text(
                    '${i + 1}',
                    style: AppTextStyles.button.copyWith(color: tone.text),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[i],
          style: AppTextStyles.label.copyWith(
            letterSpacing: 0,
            color: active ? AppColors.yellow : AppColors.gray,
          ),
        ),
      ],
    );
  }
}
