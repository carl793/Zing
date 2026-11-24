import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final email = _email.text.trim();
    if (!Validators.isValidEmail(email)) {
      setState(() => _error = 'ENTER A VALID EMAIL ADDRESS.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    String? error;
    try {
      await context.read<AuthService>().sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      error = e.code == 'network-request-failed'
          ? 'NO CONNECTION. CHECK YOUR INTERNET.'
          : "COULDN'T SEND THE LINK. TRY AGAIN.";
    } catch (_) {
      error = "COULDN'T SEND THE LINK. TRY AGAIN.";
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      if (error == null) _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PixelPage(
      title: 'NEW PASSCODE',
      child: PixelPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelEmpty(
              art: PixelIcon(
                _sent ? PixelIcons.mail : PixelIcons.key,
                size: 48,
                color: AppColors.yellow,
                shadow: true,
              ),
              title: _sent ? 'CHECK YOUR EMAIL' : 'FORGOT YOUR PASSCODE?',
              // Firebase doesn't reveal whether an address has an account.
              message: _sent
                  ? 'If an account uses ${_email.text.trim()}, a reset link is '
                      'on its way.'
                  : "Enter your email and we'll send a link to set a new one.",
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_sent) ...[
              PixelField(
                label: 'EMAIL',
                hint: 'you@email.com',
                icon: PixelIcons.mail,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                autofillHints: const [AutofillHints.email],
                enabled: !_sending,
                hasError: _error != null,
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_error != null) ...[
              PixelNote.error(_error!),
              const SizedBox(height: AppSpacing.lg),
            ],
            PixelButton(
              label: _sent ? 'SEND AGAIN' : 'SEND LINK',
              icon: PixelIcons.send,
              style:
                  _sent ? PixelButtonStyle.neutral : PixelButtonStyle.yellow,
              busy: _sending,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
