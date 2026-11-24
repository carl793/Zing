import 'package:flutter/material.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_pressable.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../controllers/vault_controller.dart';

/// How a chest stands right now, in a couple of words.
class ChestStatus {
  final String label;
  final Color color;
  final PixelIcons icon;
  const ChestStatus(this.label, this.color, this.icon);

  factory ChestStatus.of(CapsuleModel chest, VaultController vault) {
    if (chest.status == CapsuleStatus.unlocked) {
      return const ChestStatus('OPEN', AppColors.yellow, PixelIcons.unlock);
    }
    final date = chest.unlockDate;
    if (chest.triggerMode == CapsuleTriggerMode.dateRelease && date != null) {
      return ChestStatus(
        'IN ${ZingDateUtils.timeLeft(date)}',
        AppColors.gray,
        PixelIcons.clock,
      );
    }
    if (chest.triggerMode == CapsuleTriggerMode.dualTapSync) {
      return vault.myTapDone(chest)
          ? ChestStatus(
              "${vault.partnerName}'S TAP",
              AppColors.amber,
              PixelIcons.hand,
            )
          : const ChestStatus('YOUR TAP', AppColors.coral, PixelIcons.hand);
    }
    return const ChestStatus('SEALED', AppColors.gray, PixelIcons.lock);
  }
}

class ChestCard extends StatelessWidget {
  final CapsuleModel capsule;
  final VaultController ctrl;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const ChestCard({
    super.key,
    required this.capsule,
    required this.ctrl,
    required this.onTap,
    required this.onOptions,
  });

  static const double height = 218;

  @override
  Widget build(BuildContext context) {
    final open = capsule.status == CapsuleStatus.unlocked;
    final status = ChestStatus.of(capsule, ctrl);
    final mine = ctrl.isMyChest(capsule);
    const image = ChestImage(size: 72);

    final card = PixelPressable(
      onPressed: onTap,
      onLongPress: onOptions,
      builder: (_, pressed) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: PixelRaised(
          pressed: pressed,
          outline: open ? AppColors.yellow : AppColors.ink,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mine ? 'FROM YOU' : 'FROM ${ctrl.partnerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: mine ? AppColors.coral : AppColors.cyan,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 24, height: 32),
              ],
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 92,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        open
                            ? const SpriteIdle(canHop: false, child: image)
                            : image,
                        if (open) ...[
                          const Positioned(
                            left: 0,
                            top: 0,
                            child: PixelIcon(PixelIcons.sparkle,
                                size: 18, color: AppColors.yellow),
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 8,
                            child: PixelIcon(PixelIcons.sparkle,
                                size: 18, color: AppColors.coral),
                          ),
                        ] else
                          const Positioned(
                            right: 4,
                            bottom: 4,
                            child: PixelIcon(
                              PixelIcons.lock,
                              size: 24,
                              color: AppColors.yellow,
                              shadow: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 30,
              child: Center(
                child: Text(
                  capsule.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: AppTextStyles.button,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: PixelTag(
                status.label,
                icon: status.icon,
                color: status.color,
                solid: status.color != AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        card,
        Positioned(
          top: 2,
          right: 2,
          child: PixelPressable(
            onPressed: onOptions,
            semanticLabel: 'Chest options',
            builder: (_, down) => SizedBox(
              width: 44,
              height: 44,
              child: Align(
                alignment: const Alignment(0.4, -0.1),
                child: PixelIcon(
                  PixelIcons.more,
                  color: down ? AppColors.yellow : AppColors.gray,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
