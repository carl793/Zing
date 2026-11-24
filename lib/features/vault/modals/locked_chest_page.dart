import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_dialog.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_toast.dart';
import '../controllers/vault_controller.dart';
import '../widgets/chest_stage.dart';
import '../widgets/chest_unlocked_notice.dart';

/// Asks a chest's creator to confirm cancelling it.
Future<bool> confirmCancelChest(BuildContext context, CapsuleModel capsule) =>
    showConfirmDialog(
      context: context,
      title: 'CANCEL CHEST?',
      message: '"${capsule.title}" and everything sealed inside will be gone '
          "for both of you. It can't be reopened.",
      confirmLabel: 'CANCEL CHEST',
      confirmIcon: PixelIcons.trash,
      cancelLabel: 'KEEP SEALED',
    );

/// What every sealed chest's screen shares. [body] explains how it opens.
///
/// Reads the live chest rather than the copy it was opened with, so the partner's
/// tap, and the chest opening, appear while it's on screen.
class LockedChestPage extends StatelessWidget {
  final CapsuleModel capsule;
  final List<Widget> Function(
    BuildContext context,
    VaultController vault,
    CapsuleModel chest,
  ) body;
  final Widget? Function(VaultController vault, CapsuleModel chest)? actions;

  const LockedChestPage({
    super.key,
    required this.capsule,
    required this.body,
    this.actions,
  });

  Future<void> _cancel(BuildContext context, VaultController vault) async {
    if (!await confirmCancelChest(context, capsule)) return;
    final error = await vault.cancelCapsule(capsule);
    if (!context.mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      showPixelToast(context, error, color: AppColors.coral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultController>();
    final chest = vault.capsuleById(capsule.capsuleId) ?? capsule;
    if (chest.status == CapsuleStatus.unlocked) {
      return ChestUnlockedNotice(capsule: chest);
    }
    final mine = vault.isMyChest(chest);

    return PixelPage(
      title: 'SEALED',
      actions: actions?.call(vault, chest),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          const ChestStage(open: false),
          const SizedBox(height: AppSpacing.lg),
          Text(
            chest.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.subHeader,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PixelTag.owner(
                mine ? 'FROM YOU' : 'FROM ${vault.partnerName}',
                isMe: mine,
              ),
              PixelTag(
                ZingDateUtils.shortLabel(
                    ZingDateUtils.fromLocal(chest.createdAt)),
                icon: PixelIcons.lock,
                color: AppColors.gray,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          ...body(context, vault, chest),
          if (mine) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: PixelLink(
                label: 'CANCEL THIS CHEST',
                color: AppColors.coral,
                onPressed: () => _cancel(context, vault),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
