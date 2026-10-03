import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../controllers/dashboard_controller.dart';

class DistanceCard extends StatelessWidget {
  final DashboardController controller;
  const DistanceCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0)
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('OVERWORLD DISTANCE',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.cyan, fontSize: 9)),
          const SizedBox(height: AppSpacing.md),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (controller.distanceState) {
      DistanceState.loading => const Center(
          child: CircularProgressIndicator(color: AppColors.yellow)),
      DistanceState.bothOff => _BothOffState(controller: controller),
      DistanceState.together => _TogetherState(),
      DistanceState.networkFail => _NetworkFailState(controller: controller),
      DistanceState.bothLive ||
      DistanceState.partial =>
        _LiveDistanceState(controller: controller),
    };
  }
}

class _LiveDistanceState extends StatelessWidget {
  final DashboardController controller;
  const _LiveDistanceState({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isPartial = controller.distanceState == DistanceState.partial;
    final km = controller.distanceKm;
    final distText = km != null
        ? '${isPartial ? '~' : ''}${km.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} KM'
        : '--- KM';

    return Column(
      children: [
        // Sprites flanking distance
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(controller.me?.avatarSpriteId ?? '👤',
                style: const TextStyle(fontSize: 32)),
            Expanded(
              child: Text('$distText\nAPART',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.header.copyWith(
                      color: AppColors.yellow,
                      fontSize: 20,
                      height: 1.4,
                      shadows: [
                        const Shadow(
                            color: Colors.black,
                            offset: Offset(3, 3),
                            blurRadius: 0)
                      ])),
            ),
            Text(controller.partner?.avatarSpriteId ?? '👤',
                style: const TextStyle(fontSize: 32)),
          ],
        ),
        if (isPartial) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              border: Border.all(color: AppColors.amber, width: 1),
            ),
            child: Text('APPROX — ASHE\'S GPS OFF',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.amber, fontSize: 6)),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text('MANILA - - - + - - - DAVAO${isPartial ? ' (LAST KNOWN)' : ''}',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: Colors.white54)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: AppColors.charcoal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❤️', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 6),
              Text('TOGETHER: 34 DAYS IN 2026',
                  style: AppTextStyles.caption.copyWith(fontSize: 6)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BothOffState extends StatelessWidget {
  final DashboardController controller;
  const _BothOffState({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        const Text('📍', style: TextStyle(fontSize: 28)),
        const SizedBox(height: AppSpacing.md),
        Text('TURN ON LOCATION TO SEE\nYOUR LIVE DISTANCE',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white54, height: 1.8)),
        const SizedBox(height: AppSpacing.lg),
        PixelButton(
          label: '[ ENABLE LOCATION ]',
          style: PixelButtonStyle.yellow,
          onPressed: controller.enableLocation,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _TogetherState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        const Text('🎉', style: TextStyle(fontSize: 28)),
        const SizedBox(height: AppSpacing.sm),
        Text("YOU'RE TOGETHER!",
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
                color: AppColors.yellow,
                fontSize: 10,
                shadows: [
                  const Shadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0)
                ])),
        const SizedBox(height: AppSpacing.xs),
        Text('MAKE THIS ONE COUNT ❤',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.cyan)),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _NetworkFailState extends StatelessWidget {
  final DashboardController controller;
  const _NetworkFailState({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 22)),
        const SizedBox(height: AppSpacing.sm),
        Text("COULDN'T REFRESH LOCATION.\nSHOWING LAST KNOWN DISTANCE.",
            textAlign: TextAlign.center,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.amber, height: 1.8)),
        const SizedBox(height: AppSpacing.sm),
        Text('${controller.distanceKm?.toStringAsFixed(0) ?? '---'} KM APART',
            textAlign: TextAlign.center,
            style: AppTextStyles.body
                .copyWith(color: AppColors.yellow, fontSize: 12)),
        if (controller.lastUpdated != null)
          Text('LAST UPDATED 3H AGO',
              style: AppTextStyles.caption.copyWith(color: AppColors.gray)),
        const SizedBox(height: AppSpacing.md),
        PixelButton(
          label: '[ RETRY ]',
          style: PixelButtonStyle.outline,
          onPressed: controller.refreshMyLocation,
        ),
      ],
    );
  }
}