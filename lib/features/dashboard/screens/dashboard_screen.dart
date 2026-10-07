import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/couple_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/router/app_router.dart';
import '../controllers/dashboard_controller.dart';
import '../modals/propose_quest_modal.dart';
import '../modals/review_quest_modal.dart';
import '../widgets/distance_card.dart';
import '../widgets/reunion_quest_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser!.uid;
    return ChangeNotifierProvider(
      create: (ctx) => DashboardController(
        ctx.read<FirestoreService>(),
        ctx.read<LocationService>(),
        ctx.read<CoupleService>(),
        myUid: uid,
      )..init(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Column(
            children: [
              _HeaderBar(
                p1Name: ctrl.me?.displayName ?? '...',
                p1Sprite: ctrl.me?.avatarSpriteId ?? '👤',
                p2Name: ctrl.partner?.displayName ?? '...',
                p2Sprite: ctrl.partner?.avatarSpriteId ?? '👤',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Column(
                    children: [
                      DistanceCard(controller: ctrl),
                      const SizedBox(height: AppSpacing.md),
                      ReunionQuestCard(
                        controller: ctrl,
                        onPropose: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ChangeNotifierProvider.value(
                            value: ctrl,
                            child: const ProposeQuestModal(),
                          ),
                        ),
                        onReview: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ChangeNotifierProvider.value(
                            value: ctrl,
                            child: const ReviewQuestModal(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
              _BottomCTAs(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String p1Name, p1Sprite, p2Name, p2Sprite;
  const _HeaderBar({
    required this.p1Name,
    required this.p1Sprite,
    required this.p2Name,
    required this.p2Sprite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.charcoal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.coral,
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(p1Name,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.coral, fontSize: 8)),
          const Spacer(),
          Column(children: [
            const Text('❤️', style: TextStyle(fontSize: 10)),
            Text('LINKED',
                style: AppTextStyles.caption.copyWith(fontSize: 5)),
          ]),
          const Spacer(),
          Text(p2Name,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.cyan, fontSize: 8)),
          const SizedBox(width: 6),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.cyan,
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCTAs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        border: Border(top: BorderSide(color: Colors.black, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PixelButton(
              label: '[LOG MEMORY]',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.calendar),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PixelButton(
              label: '[LOCK CHEST]',
              style: PixelButtonStyle.outline,
              backgroundColor: AppColors.charcoal,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.vault),
            ),
          ),
        ],
      ),
    );
  }
}