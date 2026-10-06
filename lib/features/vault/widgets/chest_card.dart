import 'package:flutter/material.dart';
import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_dashed_border.dart';
import '../../../core/widgets/pixel_padlock.dart';
import '../controllers/vault_controller.dart';

class ChestCard extends StatelessWidget {
  final CapsuleModel capsule;
  final VaultController ctrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChestCard({
    super.key,
    required this.capsule,
    required this.ctrl,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = capsule.status == CapsuleStatus.unlocked;
    final isMine = ctrl.isMyChest(capsule);

    final cardBody = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Attribution label
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              '${ctrl.creatorLabel(capsule)} ▸ ${ctrl.recipientLabel(capsule)}',
              style: AppTextStyles.caption.copyWith(
                fontSize: 5,
                color: isMine ? AppColors.coral : AppColors.cyan,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Chest icon
          const PixelPadlock(size: 44),
          const SizedBox(height: AppSpacing.sm),
          // Title
          Text(
            capsule.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(fontSize: 7, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Status badge
          _StatusBadge(capsule: capsule, ctrl: ctrl),
        ],
      ),
    );

    final wrapped = isUnlocked
        ? PixelDashedBorder(
            color: AppColors.yellow,
            strokeWidth: 2.5,
            dashLength: 5,
            gapLength: 3,
            child: cardBody,
          )
        : cardBody;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: wrapped,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final CapsuleModel capsule;
  final VaultController ctrl;
  const _StatusBadge({required this.capsule, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = capsule.status == CapsuleStatus.unlocked;

    if (isUnlocked) {
      return _badge('UNLOCKED - TAP', AppColors.yellow, Colors.black);
    }

    if (capsule.triggerMode == CapsuleTriggerMode.dateRelease &&
        capsule.unlockDate != null) {
      final d = capsule.unlockDate!;
      final months = [
        '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
      ];
      return _badge(
        'UNLOCKS ${months[d.month]} ${d.day.toString().padLeft(2, '0')}',
        AppColors.coral,
        Colors.black,
      );
    }

    if (capsule.triggerMode == CapsuleTriggerMode.dualTapSync) {
      final myDone = ctrl.myTapDone(capsule);
      final partnerDone = ctrl.partnerTapDone(capsule);
      if (!myDone) {
        return _badge('WAITING FOR ME', AppColors.coral, Colors.black);
      }
      if (!partnerDone) {
        return _badge(
          'WAITING FOR ${ctrl.partnerName}',
          AppColors.amber,
          Colors.black,
        );
      }
    }

    return _badge('SEALED', AppColors.gray, Colors.white);
  }

  Widget _badge(String label, Color bg, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(fontSize: 5, color: textColor),
      ),
    );
  }
}