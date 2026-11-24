import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/splash_screen.dart';
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

  // Problems caught before contacting Firebase, with the fields to mark.
  String? _formError;
  bool _emailError = false;
  bool _passwordError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _clearFormError() {
    _formError = null;
    _emailError = false;
    _passwordError = false;
  }

  void _showFormError(String message, {bool email = false, bool password = false}) {
    setState(() {
      _formError = message;
      _emailError = email;
      _passwordError = password;
    });
  }

  Future<void> _submit(AuthController controller) async {
    if (controller.status == AuthStatus.loading) return;
    setState(_clearFormError);
    final email = _email.text.trim();
    final password = _password.text;
    if (!Validators.isValidEmail(email)) {
      _showFormError('ENTER A VALID EMAIL ADDRESS.', email: true);
      return;
    }
    if (password.isEmpty) {
      _showFormError('ENTER YOUR PASSCODE.', password: true);
      return;
    }
    final bool ok;
    if (_tabIndex == 0) {
      ok = await controller.login(email, password);
    } else {
      if (password.length < 6) {
        _showFormError('PASSCODE MUST BE AT LEAST 6 CHARACTERS.', password: true);
        return;
      }
      if (password != _confirmPassword.text) {
        _showFormError("PASSCODES DON'T MATCH.", password: true);
        return;
      }
      if (!_agreedToTerms) {
        _showFormError('AGREE TO THE TERMS & PRIVACY POLICY TO CONTINUE.');
        return;
      }
      ok = await controller.register(email, password);
    }
    if (ok) {
      TextInput.finishAutofillContext();
      await _routeAfterAuth();
    }
  }

  Future<void> _google(AuthController controller) async {
    if (await controller.continueWithGoogle()) await _routeAfterAuth();
  }

  Future<void> _routeAfterAuth() async {
    if (!mounted) return;
    final String route;
    try {
      route = await AppRouter.resolveDestination(context);
    } catch (e) {
      debugPrint('Routing after sign-in failed: $e');
      if (mounted) {
        _showFormError("SIGNED IN, BUT YOUR PROFILE COULDN'T LOAD. "
            'CHECK YOUR CONNECTION AND TRY AGAIN.');
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _switchTab(AuthController controller, int index) {
    controller.clearError();
    setState(() {
      _tabIndex = index;
      _clearFormError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final loading = controller.status == AuthStatus.loading;
    final isLogin = _tabIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: PixelBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: ZingLogo(size: 72)),
                    const SizedBox(height: AppSpacing.md),
                    const ZingWordmark(),
                    const SizedBox(height: AppSpacing.xl),
                    PixelSegments(
                      labels: const ['LOGIN', 'REGISTER'],
                      selected: _tabIndex,
                      onSelected:
                          loading ? null : (i) => _switchTab(controller, i),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _form(controller, isLogin: isLogin, loading: loading),
                    const SizedBox(height: AppSpacing.lg),
                    PixelButton(
                      label: isLogin ? 'PRESS START' : 'CREATE ACCOUNT',
                      icon: PixelIcons.play,
                      busy: loading,
                      onPressed: () => _submit(controller),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _OrDivider(),
                    const SizedBox(height: AppSpacing.lg),
                    PixelButton(
                      label: 'CONTINUE WITH GOOGLE',
                      style: PixelButtonStyle.neutral,
                      onPressed: loading ? null : () => _google(controller),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(
    AuthController controller, {
    required bool isLogin,
    required bool loading,
  }) {
    return PixelPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelField(
              label: 'EMAIL',
              hint: 'you@email.com',
              icon: PixelIcons.mail,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              enabled: !loading,
              hasError: _emailError,
            ),
            const SizedBox(height: AppSpacing.lg),
            PixelField(
              label: 'PASSCODE',
              hint: isLogin ? 'Your passcode' : '6 or more',
              icon: PixelIcons.lock,
              controller: _password,
              secret: true,
              textInputAction:
                  isLogin ? TextInputAction.done : TextInputAction.next,
              autofillHints: [
                isLogin ? AutofillHints.password : AutofillHints.newPassword,
              ],
              enabled: !loading,
              hasError: _passwordError,
              onSubmitted: isLogin ? (_) => _submit(controller) : null,
            ),
            if (isLogin)
              Align(
                alignment: Alignment.centerRight,
                child: PixelLink(
                  label: 'FORGOT IT?',
                  color: AppColors.gray,
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.forgotPassword),
                ),
              )
            else ...[
              const SizedBox(height: AppSpacing.lg),
              PixelField(
                label: 'PASSCODE AGAIN',
                hint: 'Same as above',
                icon: PixelIcons.lock,
                controller: _confirmPassword,
                secret: true,
                textInputAction: TextInputAction.done,
                enabled: !loading,
                hasError: _passwordError,
                onSubmitted: (_) => _submit(controller),
              ),
              const SizedBox(height: AppSpacing.sm),
              PixelCheckbox(
                value: _agreedToTerms,
                label: 'I agree to the Terms & Privacy Policy',
                onChanged: (v) => setState(() => _agreedToTerms = v),
              ),
            ],
            if (_formError != null) ...[
              const SizedBox(height: AppSpacing.md),
              PixelNote.error(_formError!),
            ] else if (controller.errorType != AuthErrorType.none) ...[
              const SizedBox(height: AppSpacing.md),
              AuthErrorBanner(errorType: controller.errorType),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: kPixel * 2,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          border: Border(
            bottom: BorderSide(color: AppColors.violet, width: kPixel),
          ),
        ),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('OR', style: AppTextStyles.caption),
        ),
        line,
      ],
    );
  }
}
