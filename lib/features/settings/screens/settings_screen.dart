import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/router/app_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'SYSTEM CONFIG',
                textAlign: TextAlign.center,
                style: AppTextStyles.header.copyWith(
                  fontSize: 15,
                  color: AppColors.cyan,
                  shadows: [
                    const Shadow(
                      color: Colors.black,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Placeholder content box
              Container(
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(5, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACCOUNT',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.cyan)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'FULL SETTINGS CONFIGURATION\nCOMING SOON.',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.gray,
                          fontSize: 7,
                          height: 1.8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Danger zone — logout always accessible from settings
              Container(
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(5, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('DANGER ZONE',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.coral)),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () async {
                        final auth = context.read<AuthService>();
                        final navigator = Navigator.of(context);
                        await auth.logout();
                        navigator.pushNamedAndRemoveUntil(
                          AppRoutes.welcome,
                          (_) => false,
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: Text(
                        '[ LOGOUT ]',
                        style: AppTextStyles.button.copyWith(fontSize: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}