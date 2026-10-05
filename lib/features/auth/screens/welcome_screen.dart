import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_tab_bar.dart';
import '../../../core/widgets/pixel_text_field.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/utils/validators.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_error_banner.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _tabIndex = 0;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _agreedToTerms = false;
  bool _localError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController controller) async {
    setState(() => _localError = false);
    final email = _email.text.trim();
    if (!Validators.isValidEmail(email)) {
      setState(() => _localError = true);
      return;
    }
    bool ok;
    if (_tabIndex == 0) {
      ok = await controller.login(email, _password.text);
    } else {
      if (_password.text != _confirmPassword.text || !_agreedToTerms) {
        setState(() => _localError = true);
        return;
      }
      ok = await controller.register(email, _password.text);
    }
    if (ok) await _routeAfterAuth();
  }

  Future<void> _google(AuthController controller) async {
    if (await controller.continueWithGoogle()) await _routeAfterAuth();
  }

  Future<void> _routeAfterAuth() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final uid = authService.currentUser!.uid;
    final hasProfile = await authService.hasCompletedProfile(uid);
    // Also claims a link made while this account was signed out.
    final coupleId = await firestore.recoverCoupleId(uid);
    if (!mounted) return;
    final route = !hasProfile
        ? AppRoutes.spriteSelect
        : (coupleId == null || coupleId.isEmpty
            ? AppRoutes.pairing
            : AppRoutes.dashboard);
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final loading = controller.status == AuthStatus.loading;
    final isLogin = _tabIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // 1. Pixel Heart + Bolt Logo (Slightly enlarged for scale)
                const Align(
                  alignment: Alignment.center,
                  child: _PixelHeartBoltLogo(),
                ),
                const SizedBox(height: 16),

                // 2. Main Title: ZING
                Text(
                  'ZING',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.header.copyWith(
                    fontSize: 48,
                    color: AppColors.cyan,
                    letterSpacing: 2.0,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle from Figma
                Text(
                  'CO-OP ROMANCE SPACE',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.5,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),

                // Dynamic Status Ticker
                Text(
                  isLogin ? 'PRESS START TO LOGIN' : 'PRESS START TO REGISTER',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.yellow,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 3. Popped-out Dual Tab Switcher (Fixed string labels)
                PixelTabBar(
                  labels: const ['LOGIN', 'REGISTER'],
                  activeIndex: _tabIndex,
                  onTap: (i) => setState(() {
                    _tabIndex = i;
                    _localError = false;
                  }),
                ),

                // CLEAR GAP BETWEEN TOGGLE AND CONTAINER
                const SizedBox(height: 12),

                // 4. Main Carved/Container Card (Expanded Vertical Height)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B55),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(5, 5),
                        blurRadius: 0,
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 32.0, // Increased vertical padding for taller presence
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // EMAIL FIELD
                      _CarvedFieldWrapper(
                        child: PixelTextField(
                          label: 'EMAIL',
                          hint: 'ENTER EMAIL..',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          hasError: _localError,
                        ),
                      ),
                      const SizedBox(height: 24), // Generous field spacing

                      // PASSCODE FIELD
                      _CarvedFieldWrapper(
                        child: PixelTextField(
                          label: 'PASSCODE',
                          hint: isLogin
                              ? 'ENTER PASSWORD..'
                              : 'CREATE PASSWORD..',
                          controller: _password,
                          obscureText: true,
                          hasError: _localError,
                        ),
                      ),

                      // REGISTER ONLY: CONFIRM PASSCODE & TERMS
                      if (!isLogin) ...[
                        const SizedBox(height: 24),
                        _CarvedFieldWrapper(
                          child: PixelTextField(
                            label: 'CONFIRM PASSCODE',
                            hint: 'RE-ENTER PASSWORD..',
                            controller: _confirmPassword,
                            obscureText: true,
                            hasError: _localError,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                onChanged: (v) => setState(
                                    () => _agreedToTerms = v ?? false),
                                checkColor: AppColors.cyan,
                                fillColor: WidgetStateProperty.all(
                                    const Color(0xFF121124)),
                                side: const BorderSide(
                                    color: Colors.black, width: 2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'I AGREE TO THE TERMS & PRIVACY POLICY',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 8,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // LOGIN ONLY: FORGOT PASSCODE LINK
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.forgotPassword),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'FORGOT PASSCODE?',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  height: 2,
                                  width: 120,
                                  color: Colors.white38,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (controller.errorType != AuthErrorType.none) ...[
                        const SizedBox(height: 16),
                        AuthErrorBanner(errorType: controller.errorType),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 5. Primary Popped-Out Action Button
                PixelButton(
                  label: loading
                      ? '...'
                      : isLogin
                          ? '[ ENTER ]'
                          : '[ CREATE ACCOUNT ]',
                  onPressed: loading ? null : () => _submit(controller),
                  style: PixelButtonStyle.coral,
                ),

                const SizedBox(height: 20),

                // 6. Retro Pixel Divider
                Row(
                  children: [
                    const Expanded(
                      child: ContainerDivider(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: ContainerDivider(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 7. Social SSO Button (Continue with Google)
                PixelButton(
                  label: 'G   CONTINUE WITH GOOGLE',
                  style: PixelButtonStyle.outline,
                  onPressed: loading ? null : () => _google(controller),
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inset / Sunken Container Wrapper for TextFields to give carved depth
class _CarvedFieldWrapper extends StatelessWidget {
  final Widget child;
  const _CarvedFieldWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121124),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: child,
    );
  }
}

/// Custom Pixel Heart + Yellow Lightning Bolt Logo
class _PixelHeartBoltLogo extends StatelessWidget {
  const _PixelHeartBoltLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 2,
            left: 2,
            child: Icon(
              Icons.favorite,
              size: 58,
              color: Colors.black,
            ),
          ),
          const Icon(
            Icons.favorite,
            size: 54,
            color: Color(0xFFFF5376),
          ),
          Positioned(
            child: Icon(
              Icons.bolt,
              size: 34,
              color: AppColors.yellow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Crisp Retro Horizontal Line Divider
class ContainerDivider extends StatelessWidget {
  const ContainerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: Colors.black,
      child: Container(
        margin: const EdgeInsets.only(top: 1),
        height: 1,
        color: Colors.white24,
      ),
    );
  }
}