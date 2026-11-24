import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../controllers/vault_controller.dart';
import '../modals/chest_unlocked_modal.dart';

/// Takes over a locked-chest screen when the chest opens while it's on
/// screen (its date arrives, or both partners have tapped).
class ChestUnlockedNotice extends StatelessWidget {
  final CapsuleModel capsule;
  const ChestUnlockedNotice({super.key, required this.capsule});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CHEST UNLOCKED',
                textAlign: TextAlign.center,
                style: AppTextStyles.header.copyWith(color: AppColors.yellow),
              ),
              const SizedBox(height: AppSpacing.lg),
              PixelButton(
                label: '[ OPEN CHEST ]',
                onPressed: () {
                  final ctrl = context.read<VaultController>();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ChestUnlockedModal(
                        capsule: capsule,
                        loadContent: () => ctrl.loadContent(capsule),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              PixelButton(
                label: '[ CLOSE ]',
                style: PixelButtonStyle.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
