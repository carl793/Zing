import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/capsule_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_pressable.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/repositories/memory_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../shell/shell_tabs.dart';
import '../../vault/controllers/vault_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../modals/propose_quest_modal.dart';
import '../modals/review_quest_modal.dart';
import '../widgets/distance_card.dart';
import '../widgets/overworld_scene.dart';
import '../widgets/reunion_quest_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardController(
        session: ctx.read<SessionController>(),
        users: ctx.read<UserRepository>(),
        couples: ctx.read<CoupleRepository>(),
        memories: ctx.read<MemoryRepository>(),
        location: ctx.read<LocationService>(),
      ),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Also picks up access that was just changed in the phone's settings.
    _lifecycle = AppLifecycleListener(
      onResume: () => context
          .read<DashboardController>()
          .refreshLocation(onlyIfStale: true),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _openSheet(DashboardController ctrl, Widget sheet, {bool form = false}) =>
      showPixelSheet<void>(
        context: context,
        isForm: form,
        builder: (_) =>
            ChangeNotifierProvider.value(value: ctrl, child: sheet),
      );

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    final tabs = context.read<ShellTabs>();

    return SafeArea(
      bottom: false,
      child: PixelColumn(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              child: PlayerHud(
                myName: ctrl.me?.displayName ?? '...',
                partnerName: ctrl.partner?.displayName ?? '...',
                days: ctrl.daysLinked,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.xs, AppSpacing.lg + 4, AppSpacing.lg),
                child: Column(
                  children: [
                    DistanceCard(controller: ctrl),
                    const SizedBox(height: AppSpacing.lg),
                    const _ChestTeaser(),
                    ReunionQuestCard(
                      controller: ctrl,
                      onPropose: () => _openSheet(
                          ctrl, const ProposeQuestModal(), form: true),
                      onReview: () => _openSheet(ctrl, const ReviewQuestModal()),
                    ),
                  ],
                ),
              ),
            ),
            PixelActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      label: 'LOG MEMORY',
                      icon: PixelIcons.heart,
                      style: PixelButtonStyle.coral,
                      onPressed: () => tabs.open(
                        ShellTab.calendar,
                        then: ShellAction.logToday,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PixelButton(
                      label: 'LOCK CHEST',
                      icon: PixelIcons.lock,
                      onPressed: () => tabs.open(
                        ShellTab.vault,
                        then: ShellAction.newChest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chest waiting for this player, or the next one to open.
class _ChestTeaser extends StatelessWidget {
  const _ChestTeaser();

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultController>();
    final chest = vault.highlight;
    if (chest == null) return const SizedBox.shrink();
    final waiting = vault.isWaitingForMe(chest);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: PixelPressable(
        onPressed: () => context.read<ShellTabs>().open(ShellTab.vault),
        builder: (_, pressed) => Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: PixelRaised(
            pressed: pressed,
            outline: waiting ? AppColors.coral : AppColors.ink,
          ),
          child: Row(
            children: [
              SpriteIdle(
                canHop: false,
                child: const ChestImage(size: 48),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting ? 'WAITING FOR YOUR TAP' : _opensIn(chest),
                      style: AppTextStyles.label.copyWith(
                        color: waiting ? AppColors.coral : AppColors.yellow,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.button,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const PixelIcon(PixelIcons.right, color: AppColors.gray),
            ],
          ),
        ),
      ),
    );
  }

  static String _opensIn(CapsuleModel chest) =>
      'OPENS IN ${ZingDateUtils.timeLeft(chest.unlockDate!)}';
}
