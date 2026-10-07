import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shown while resolveInitialRoute() runs. Branded, no logic.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pixel heart + lightning bolt logo
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '💔',
                  style: TextStyle(
                    fontSize: 72,
                    shadows: [
                      Shadow(
                        color: AppColors.cyan.withOpacity(0.6),
                        offset: const Offset(0, 0),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'ZING',
              style: AppTextStyles.header.copyWith(
                fontSize: 32,
                color: AppColors.cyan,
                letterSpacing: 4,
                shadows: [
                  const Shadow(
                    color: Colors.black,
                    offset: Offset(4, 4),
                    blurRadius: 0,
                  ),
                  Shadow(
                    color: AppColors.cyan.withOpacity(0.4),
                    offset: const Offset(0, 0),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'CO-OP ROMANCE SPACE',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white54,
                letterSpacing: 2,
                fontSize: 7,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.purple,
                color: AppColors.yellow,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}