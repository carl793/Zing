import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pixel_button.dart';
import 'pixel_icon.dart';
import 'pixel_loader.dart';
import 'pixel_page.dart';
import 'pixel_panel.dart';

/// Branded launch screen shown while the signed-in destination is resolved.
class SplashScreen extends StatefulWidget {
  final Future<String> Function(BuildContext context) resolveRoute;

  const SplashScreen({super.key, required this.resolveRoute});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _continueToApp();
  }

  Future<void> _continueToApp() async {
    final String route;
    try {
      final results = await Future.wait<String>([
        widget.resolveRoute(context),
        // Long enough for the logo to land, short enough not to be in the way.
        Future<void>.delayed(const Duration(milliseconds: 600)).then(
          (_) => '',
        ),
      ]);
      route = results.first;
    } catch (error) {
      // Signed in but unreachable: offer a retry rather than the login screen.
      debugPrint('Could not resolve launch destination: $error');
      if (mounted) setState(() => _failed = true);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _retry() {
    setState(() => _failed = false);
    _continueToApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: PixelBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.72, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: const ZingLogo(size: 104),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const ZingWordmark(),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_failed) ...[
                    const PixelNote.warning(
                      "Couldn't connect. Check your internet.",
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PixelButton(
                      label: 'RETRY',
                      icon: PixelIcons.refresh,
                      onPressed: _retry,
                    ),
                  ] else
                    const PixelLoader(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The heart and bolt.
class ZingLogo extends StatelessWidget {
  final double size;
  const ZingLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/images/zing_logo.svg',
        width: size,
        height: size,
        semanticsLabel: 'Zing logo',
      );
}

class ZingWordmark extends StatelessWidget {
  const ZingWordmark({super.key});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ZING',
            style: AppTextStyles.header.copyWith(
              fontSize: 40,
              color: AppColors.cyan,
              letterSpacing: 2,
              shadows: const [
                Shadow(color: Color(0xFF17869F), offset: Offset(0, 4)),
                Shadow(color: AppColors.ink, offset: Offset(3, 7)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'CO-OP ROMANCE SPACE',
            style: AppTextStyles.caption.copyWith(letterSpacing: 1),
          ),
        ],
      );
}
