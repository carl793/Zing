import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../controllers/vault_controller.dart';

class ChestLockedDualTapModal extends StatefulWidget {
  final CapsuleModel capsule;
  const ChestLockedDualTapModal({super.key, required this.capsule});

  @override
  State<ChestLockedDualTapModal> createState() =>
      _ChestLockedDualTapModalState();
}

class _ChestLockedDualTapModalState extends State<ChestLockedDualTapModal> {
  bool _tapping = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VaultController>();
    final myDone = ctrl.myTapDone(widget.capsule);
    final partnerDone = ctrl.partnerTapDone(widget.capsule);
    final isMine = ctrl.isMyChest(widget.capsule);

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHEST SEALED',
                    style: AppTextStyles.header.copyWith(
                      color: AppColors.coral,
                      fontSize: 18,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  _CloseBtn(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                '"${widget.capsule.title}"',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.cyan,
                  fontSize: 10,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const Center(
                child: SpriteAssetIcon(
                  assetPath: 'assets/sprites/mystery_box.svg',
                  fallbackPath: 'assets/sprites/mystery_box_96.png',
                  size: 84,
                  semanticsLabel: 'Mystery box chest',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'LOCKED',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.yellow,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'DUAL-TAP SYNC STATUS',
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(color: AppColors.cyan),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: _TapChip(
                      label: 'P1: YOU',
                      status: myDone ? 'TAPPED ✓' : 'WAITING...',
                      done: myDone,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _TapChip(
                      label: 'P2: ${ctrl.partnerName}',
                      status: partnerDone ? 'TAPPED ✓' : 'WAITING...',
                      done: partnerDone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              if (_error != null) ...[
                PixelErrorBox(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],

              PixelButton(
                label: _tapping
                    ? 'TAPPING...'
                    : (myDone
                          ? '[ WAITING FOR PARTNER ]'
                          : '[ TAP TO UNLOCK ]'),
                style: PixelButtonStyle.yellow,
                onPressed: (myDone || _tapping)
                    ? null
                    : () => _tap(context, ctrl),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'Both partners must tap within the same session to unlock this chest.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.gray,
                  fontSize: 6,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Cancel only for creator
              if (isMine) ...[
                GestureDetector(
                  onTap: () => _cancel(context, ctrl),
                  child: Center(
                    child: Text(
                      '[ CANCEL CHEST ]',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.coral,
                        fontSize: 6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              PixelButton(
                label: '[ CLOSE ]',
                style: PixelButtonStyle.outline,
                backgroundColor: AppColors.charcoal,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tap(BuildContext context, VaultController ctrl) async {
    setState(() {
      _tapping = true;
      _error = null;
    });
    final error = await ctrl.tapUnlock(widget.capsule);
    if (!mounted) return;
    setState(() => _tapping = false);
    if (error != null) setState(() => _error = error);
    // If both tapped, capsule stream will flip to unlocked and screen will
    // be popped by the vault_screen logic.
  }

  Future<void> _cancel(BuildContext context, VaultController ctrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _CancelDialog(chestName: widget.capsule.title),
    );
    if (confirmed != true || !mounted) return;
    final error = await ctrl.cancelCapsule(widget.capsule);
    if (!mounted) return;
    if (error == null) Navigator.of(context).pop();
  }
}

class _TapChip extends StatelessWidget {
  final String label;
  final String status;
  final bool done;
  const _TapChip({
    required this.label,
    required this.status,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(
          color: done ? AppColors.cyan : AppColors.gray,
          width: 2,
        ),
        boxShadow: done
            ? const [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: done ? AppColors.cyan : AppColors.gray,
              fontSize: 7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: done ? AppColors.cyan : AppColors.gray,
              fontSize: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: AppColors.coral, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Text(
          '[ X ]',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.coral,
            fontSize: 8,
          ),
        ),
      ),
    );
  }
}

class _CancelDialog extends StatelessWidget {
  final String chestName;
  const _CancelDialog({required this.chestName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.purple,
          border: Border.all(color: AppColors.coral, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.amber,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'CANCEL THIS\nCHEST?',
              textAlign: TextAlign.center,
              style: AppTextStyles.subHeader.copyWith(
                color: AppColors.coral,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This will permanently delete\n"$chestName" and everything sealed inside it.\nThis cannot be undone.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.gray,
                fontSize: 6,
                height: 1.8,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PixelButton(
              label: '[ KEEP SEALED ]',
              style: PixelButtonStyle.outline,
              backgroundColor: AppColors.charcoal,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.md),
            PixelButton(
              label: '[ YES, CANCEL CHEST ]',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
