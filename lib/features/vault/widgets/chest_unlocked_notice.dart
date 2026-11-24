import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_page.dart';
import '../controllers/vault_controller.dart';
import '../modals/chest_unlocked_modal.dart';
import 'chest_stage.dart';

/// Takes over a locked-chest screen when the chest opens while it's on
/// screen (its date arrives, or both partners have tapped).
class ChestUnlockedNotice extends StatefulWidget {
  final CapsuleModel capsule;
  const ChestUnlockedNotice({super.key, required this.capsule});

  @override
  State<ChestUnlockedNotice> createState() => _ChestUnlockedNoticeState();
}

class _ChestUnlockedNoticeState extends State<ChestUnlockedNotice> {
  @override
  void initState() {
    super.initState();
    AudioService.instance
      ..playSfx(AppSfx.unlock)
      ..knock(strong: true);
  }

  void _open() {
    final ctrl = context.read<VaultController>();
    final capsule = widget.capsule;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChestUnlockedModal(
          capsule: capsule,
          loadContent: () => ctrl.loadContent(capsule),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PixelPage(
      title: 'UNLOCKED!',
      actions: PixelButton(
        label: 'OPEN CHEST',
        icon: PixelIcons.unlock,
        sfx: AppSfx.seal,
        onPressed: _open,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const ChestStage(open: true),
          const SizedBox(height: AppSpacing.xl),
          Text(
            widget.capsule.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.subHeader,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The seal is broken. See what was waiting inside.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
