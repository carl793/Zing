import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_text_field.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;
  bool _sending = false;

  Future<void> _send() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<AuthService>().sendPasswordResetEmail(_email.text.trim());
      setState(() { _sent = true; _sending = false; });
    } catch (_) {
      setState(() => _sending = false);
    }
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
              PixelTextField(label: 'EMAIL', hint: 'ENTER EMAIL..', controller: _email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: AppSpacing.lg),
              PixelButton(label: _sending ? '...' : '[ SEND RESET LINK ]', onPressed: _sending ? null : _send),
            ] else ...[
              const Text('📧', style: TextStyle(fontSize: 26), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('CHECK YOUR\nEMAIL', textAlign: TextAlign.center, style: AppTextStyles.subHeader.copyWith(fontSize: 11)),
              const SizedBox(height: AppSpacing.sm),
              Text('WE SENT A RESET LINK TO\n${_email.text.trim()}.', textAlign: TextAlign.center, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.lg),
              PixelButton(label: '[ RESEND EMAIL ]', style: PixelButtonStyle.outline, onPressed: _send),
            ],
          ]),
        ),
      ),
    );
  }
}