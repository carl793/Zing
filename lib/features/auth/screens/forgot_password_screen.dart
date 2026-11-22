import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/pixel_text_field.dart';

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
    final email = _email.text.trim();
    if (!Validators.isValidEmail(email)) {
      setState(() => _error = '✕ ENTER A VALID EMAIL ADDRESS.');
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
          ? '⚠ NO CONNECTION. CHECK YOUR INTERNET.'
          : "⚠ COULDN'T SEND THE LINK. TRY AGAIN.";
    } catch (_) {
      error = "⚠ COULDN'T SEND THE LINK. TRY AGAIN.";
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GestureDetector(onTap: () => Navigator.of(context).pop(), child: Text('◀ BACK TO LOGIN', style: AppTextStyles.caption)),
            const SizedBox(height: AppSpacing.lg),
            if (!_sent) ...[
              const Text('🔑', style: TextStyle(fontSize: 26), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('RESET YOUR\nPASSCODE', textAlign: TextAlign.center, style: AppTextStyles.subHeader.copyWith(fontSize: 11)),
              const SizedBox(height: AppSpacing.lg),
              PixelTextField(
                label: 'EMAIL',
                hint: 'ENTER EMAIL..',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                hasError: _error != null,
              ),
              const SizedBox(height: AppSpacing.lg),
              PixelButton(label: _sending ? '...' : '[ SEND RESET LINK ]', onPressed: _sending ? null : _send),
            ] else ...[
              const Text('📧', style: TextStyle(fontSize: 26), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('CHECK YOUR\nEMAIL', textAlign: TextAlign.center, style: AppTextStyles.subHeader.copyWith(fontSize: 11)),
              const SizedBox(height: AppSpacing.sm),
              // Firebase doesn't reveal whether an address has an account.
              Text(
                'IF AN ACCOUNT USES\n${_email.text.trim()},\nA RESET LINK IS ON ITS WAY.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(height: 1.8),
              ),
              const SizedBox(height: AppSpacing.lg),
              PixelButton(
                label: _sending ? '...' : '[ RESEND EMAIL ]',
                style: PixelButtonStyle.outline,
                onPressed: _sending ? null : _send,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              PixelErrorBox(message: _error!),
            ],
          ]),
        ),
      ),
    );
  }
}
