import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_loader.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/pixel_toast.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../../shell/shell_tabs.dart';
import '../controllers/vault_controller.dart';
import '../modals/chest_locked_date_modal.dart';
import '../modals/chest_locked_dualtap_modal.dart';
import '../modals/chest_unlocked_modal.dart';
import '../modals/create_capsule_modal.dart';
import '../modals/locked_chest_page.dart';
import '../widgets/chest_card.dart';
import '../widgets/vault_filters.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  ShellTabs? _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = context.read<ShellTabs?>()?..addListener(_onTabs);
    _onTabs();
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabs);
    super.dispose();
  }

  /// The home screen's LOCK CHEST button starts here.
  void _onTabs() {
    if (!(_tabs?.take(ShellAction.newChest) ?? false)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newChest();
    });
  }

  void _sheet(Widget child, {bool isForm = false}) {
    final vault = context.read<VaultController>();
    showPixelSheet<void>(
      context: context,
      isForm: isForm,
      builder: (_) => ChangeNotifierProvider.value(value: vault, child: child),
    );
  }

  void _newChest() => _sheet(const CreateCapsuleModal(), isForm: true);

  void _push(Widget page) {
    final vault = context.read<VaultController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(value: vault, child: page),
      ),
    );
  }

  void _openChest(CapsuleModel capsule) {
    final vault = context.read<VaultController>();
    if (capsule.status == CapsuleStatus.unlocked) {
      _push(ChestUnlockedModal(
        capsule: capsule,
        loadContent: () => vault.loadContent(capsule),
      ));
    } else if (capsule.triggerMode == CapsuleTriggerMode.dateRelease) {
      _push(ChestLockedDateModal(capsule: capsule));
    } else {
      _push(ChestLockedDualTapModal(
        capsule: capsule,
        session: context.read<SessionController>(),
      ));
    }
  }

  /// Archive or restore, or cancel your own sealed chest. The sheet only picks
  /// the action; it runs here, once the sheet has closed (the sheet's own
  /// context is gone by then).
  Future<void> _showOptions(CapsuleModel capsule) async {
    final vault = context.read<VaultController>();
    final action = await showPixelSheet<_ChestAction>(
      context: context,
      builder: (_) => _ChestOptions(
        capsule: capsule,
        canCancel: vault.isMyChest(capsule) &&
            capsule.status == CapsuleStatus.sealed,
      ),
    );
    if (action == null || !mounted) return;

    final String? error;
    switch (action) {
      case _ChestAction.toggleArchive:
        error = await vault.setArchived(capsule, !capsule.isArchived);
      case _ChestAction.cancel:
        if (!await confirmCancelChest(context, capsule)) return;
        error = await vault.cancelCapsule(capsule);
    }
    if (!mounted) return;
    if (error != null) {
      showPixelToast(context, error, color: AppColors.coral);
    } else if (action == _ChestAction.toggleArchive) {
      showPixelToast(
        context,
        capsule.isArchived ? 'BACK IN THE VAULT.' : 'MOVED TO THE ARCHIVE.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VaultController>();

    return SafeArea(
      bottom: false,
      child: PixelColumn(
        child: Column(
          children: [
            PixelScreenTitle(
              title: 'VAULT',
              icon: PixelIcons.chest,
              tone: PixelTone.yellow,
              trailing: PixelIconButton(
                icon: PixelIcons.filter,
                label: 'Filter chests',
                dot: ctrl.hasFilters,
                onPressed: () => _sheet(const VaultFilterSheet()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: PixelSegments(
                labels: const ['CHESTS', 'ARCHIVE'],
                icons: const [PixelIcons.chest, PixelIcons.archive],
                selected: ctrl.showArchived ? 1 : 0,
                onSelected: (i) => ctrl.setShowArchived(i == 1),
              ),
            ),
            Expanded(child: _shelf(ctrl)),
            PixelActionBar(
              child: PixelButton(
                label: 'NEW CHEST',
                icon: PixelIcons.plus,
                onPressed: _newChest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shelf(VaultController ctrl) {
    if (ctrl.isLoading) return const PixelLoading(label: 'OPENING THE VAULT');
    final chests = ctrl.capsules;
    final error = ctrl.error;
    if (error != null && chests.isEmpty) {
      return _Centered(children: [
        PixelNote.error(error),
        const SizedBox(height: AppSpacing.md),
        PixelButton(
          label: 'RETRY',
          icon: PixelIcons.refresh,
          onPressed: ctrl.retry,
        ),
      ]);
    }
    if (chests.isEmpty) return _Centered(children: [_empty(ctrl)]);

    return CustomScrollView(
      slivers: [
        if (error != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            sliver: SliverToBoxAdapter(child: PixelNote.warning(error)),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg + 4, AppSpacing.lg),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: ChestCard.height,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemCount: chests.length,
            itemBuilder: (_, i) => ChestCard(
              key: ValueKey(chests[i].capsuleId),
              capsule: chests[i],
              ctrl: ctrl,
              onTap: () => _openChest(chests[i]),
              onOptions: () => _showOptions(chests[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(VaultController ctrl) {
    const art = SpriteIdle(child: ChestImage(size: 96));
    if (ctrl.hasFilters && !ctrl.isEmpty) {
      return PixelEmpty(
        art: art,
        title: 'NO MATCHES',
        message: 'No chest fits these filters.',
        action: PixelButton(
          label: 'CLEAR FILTERS',
          style: PixelButtonStyle.neutral,
          onPressed: ctrl.clearFilters,
        ),
      );
    }
    return ctrl.showArchived
        ? const PixelEmpty(
            art: art,
            title: 'ARCHIVE IS EMPTY',
            message: "Chests you've put away will rest here.",
          )
        : const PixelEmpty(
            art: art,
            title: 'NO TREASURE YET',
            message: 'Lock away a note, a photo or your voice for your partner '
                'to discover later.',
          );
  }
}

class _Centered extends StatelessWidget {
  final List<Widget> children;
  const _Centered({required this.children});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
}

enum _ChestAction { toggleArchive, cancel }

class _ChestOptions extends StatelessWidget {
  final CapsuleModel capsule;
  final bool canCancel;
  const _ChestOptions({required this.capsule, required this.canCancel});

  @override
  Widget build(BuildContext context) {
    return PixelModalShell(
      title: capsule.title,
      icon: PixelIcons.chest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelButton(
            label: capsule.isArchived ? 'RESTORE TO VAULT' : 'ARCHIVE',
            icon: PixelIcons.archive,
            style: PixelButtonStyle.neutral,
            onPressed: () =>
                Navigator.of(context).pop(_ChestAction.toggleArchive),
          ),
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.md),
            PixelButton(
              label: 'CANCEL CHEST',
              icon: PixelIcons.trash,
              style: PixelButtonStyle.danger,
              onPressed: () => Navigator.of(context).pop(_ChestAction.cancel),
            ),
          ],
        ],
      ),
    );
  }
}
