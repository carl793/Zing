import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Branded launch screen shown while the signed-in destination is resolved.
class SplashScreen extends StatefulWidget {
  final Future<String> Function() resolveRoute;

  const SplashScreen({super.key, required this.resolveRoute});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _continueToApp();
  }

  Future<void> _continueToApp() async {
    String route;
    try {
      final results = await Future.wait<String>([
        widget.resolveRoute(),
        Future<void>.delayed(const Duration(milliseconds: 900)).then(
          (_) => '',
        ),
      ]);
      route = results.first;
    } catch (error) {
      debugPrint('Could not resolve launch destination: $error');
      route = '/welcome';
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _loadingAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.72, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(5, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/images/zing_logo.svg',
                  width: 88,
                  height: 88,
                  semanticsLabel: 'Zing pixel heart and lightning logo',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'ZING',
              style: AppTextStyles.header.copyWith(
                fontSize: 24,
                color: AppColors.cyan,
                letterSpacing: 4,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'CO-OP ROMANCE SPACE',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white70,
                letterSpacing: 1,
                fontSize: 7,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _loadingAnimation,
                  builder: (context, child) {
                    final phase = (_loadingAnimation.value - index * 0.18) % 1;
                    final opacity = phase < 0.55 ? 0.35 + phase : 0.9 - phase;
                    return Opacity(
                      opacity: opacity.clamp(0.25, 1).toDouble(),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == 1 ? AppColors.cyan : AppColors.yellow,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'LOADING',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white70,
                fontSize: 7,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
