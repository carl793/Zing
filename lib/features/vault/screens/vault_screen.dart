import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/vault_controller.dart';
import '../modals/chest_locked_date_modal.dart';
import '../modals/chest_locked_dualtap_modal.dart';
import '../modals/chest_unlocked_modal.dart';
import '../modals/create_capsule_modal.dart';
import '../widgets/chest_card.dart';
import '../widgets/vault_filter_bar.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser!.uid;
    return ChangeNotifierProvider(
      create: (ctx) => VaultController(
        ctx.read<FirestoreService>(),
        ctx.read<StorageService>(),
        myUid: uid,
      )..init(),
      child: const _VaultView(),
    );
  }
}

class _VaultView extends StatelessWidget {
  const _VaultView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VaultController>();
    final capsules = ctrl.capsules;
    final isEmpty = ctrl.isLoading ? false : ctrl.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TREASURE\nVAULT',
                    style: AppTextStyles.header.copyWith(
                      fontSize: 19,
                      color: AppColors.cyan,
                      height: 1.5,
                      shadows: const [
                        Shadow(
                          color: Color(0xFF003A44),
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  _NewChestButton(ctrl: ctrl),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              if (ctrl.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  ),
                )
              else if (ctrl.error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctrl.error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.coral,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PixelButton(label: '[ RETRY ]', onPressed: ctrl.retry),
                      ],
                    ),
                  ),
                )
              else ...[
                VaultFilterBar(
                  current: ctrl.filter,
                  sender: ctrl.senderFilter,
                  status: ctrl.statusFilter,
                  showArchived: ctrl.showArchived,
                  totalCount: ctrl.totalCount,
                  onSelect: ctrl.setFilter,
                  onSenderSelect: ctrl.setSenderFilter,
                  onStatusSelect: ctrl.setStatusFilter,
                  onArchiveSelect: ctrl.setShowArchived,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: capsules.isEmpty
                      ? (isEmpty &&
                                !ctrl.showArchived &&
                                ctrl.filter == VaultFilter.all &&
                                ctrl.senderFilter == VaultSenderFilter.all &&
                                ctrl.statusFilter == VaultStatusFilter.all
                            ? _EmptyVault(ctrl: ctrl)
                            : Center(
                                child: Text(
                                  ctrl.showArchived
                                      ? 'NO ARCHIVED CHESTS.'
                                      : 'NO CHESTS IN THIS FILTER.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.gray,
                                  ),
                                ),
                              ))
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                          itemCount: capsules.length,
                          itemBuilder: (ctx, i) {
                            final capsule = capsules[i];
                            return ChestCard(
                              capsule: capsule,
                              ctrl: ctrl,
                              onTap: () => _openChest(context, ctrl, capsule),
                              onLongPress: () =>
                                  _longPress(context, ctrl, capsule),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  void _openChest(
    BuildContext context,
    VaultController ctrl,
    CapsuleModel capsule,
  ) {
    if (capsule.status == CapsuleStatus.unlocked) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: ctrl,
            child: ChestUnlockedModal(capsule: capsule),
          ),
        ),
      );
      return;
    }

    if (capsule.triggerMode == CapsuleTriggerMode.dateRelease) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: ctrl,
            child: ChestLockedDateModal(capsule: capsule),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: ChestLockedDualTapModal(capsule: capsule),
        ),
      ),
    );
  }

  /// Long-press on own sealed chest — shows a context sheet with cancel option.
  void _longPress(
    BuildContext context,
    VaultController ctrl,
    CapsuleModel capsule,
  ) {
    showPixelSheet(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: ctrl,
        child: _ChestContextSheet(capsule: capsule),
      ),
    );
  }
}

class _NewChestButton extends StatelessWidget {
  final VaultController ctrl;
  const _NewChestButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPixelSheet(
        context: context,
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: const CreateCapsuleModal(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.yellow,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpriteAssetIcon(
              assetPath: 'assets/sprites/mystery_box.svg',
              fallbackPath: 'assets/sprites/mystery_box_96.png',
              size: 40,
              semanticsLabel: 'Mystery box chest',
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '+ NEW\nCHEST',
              textAlign: TextAlign.center,
              style: AppTextStyles.button.copyWith(fontSize: 9, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  final VaultController ctrl;
  const _EmptyVault({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SpriteAssetIcon(
          assetPath: 'assets/sprites/mystery_box.svg',
          fallbackPath: 'assets/sprites/mystery_box_96.png',
          size: 64,
          semanticsLabel: 'Mystery box chest',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'NO TREASURES\nYET',
          textAlign: TextAlign.center,
          style: AppTextStyles.header.copyWith(
            color: AppColors.yellow,
            fontSize: 14,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Lock away a memory for\nyour partner to discover\nlater.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.gray,
            height: 1.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: PixelButton(
            label: '[ + CREATE YOUR\nFIRST CHEST ]',
            style: PixelButtonStyle.yellow,
            onPressed: () => showPixelSheet(
              context: context,
              builder: (_) => ChangeNotifierProvider.value(
                value: ctrl,
                child: const CreateCapsuleModal(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChestContextSheet extends StatelessWidget {
  final CapsuleModel capsule;
  const _ChestContextSheet({required this.capsule});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<VaultController>();

    return PixelModalShell(
      title: '"${capsule.title}"',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            capsule.isArchived
                ? 'ARCHIVED CHEST.'
                : (ctrl.isMyChest(capsule) &&
                          capsule.status == CapsuleStatus.sealed
                      ? 'YOUR OWN SEALED CHEST.'
                      : 'CHEST OPTIONS.'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.gray,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelButton(
            label: capsule.isArchived
                ? '[ RESTORE TO VAULT ]'
                : '[ ARCHIVE CHEST ]',
            style: PixelButtonStyle.outline,
            backgroundColor: AppColors.charcoal,
            onPressed: () async {
              await ctrl.setArchived(capsule, !capsule.isArchived);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          if (ctrl.isMyChest(capsule) && capsule.status == CapsuleStatus.sealed)
            const SizedBox(height: AppSpacing.md),
          if (ctrl.isMyChest(capsule) && capsule.status == CapsuleStatus.sealed)
            PixelButton(
              label: '[ CANCEL CHEST ]',
              style: PixelButtonStyle.outlineDanger,
              backgroundColor: AppColors.charcoal,
              onPressed: () async {
                Navigator.of(context).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  barrierColor: Colors.black87,
                  builder: (_) => _CancelDialog(chestName: capsule.title),
                );
                if (confirmed != true || !context.mounted) return;
                await ctrl.cancelCapsule(capsule);
              },
            ),
        ],
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
