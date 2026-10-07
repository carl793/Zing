import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/sprite_avatar.dart';
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
          BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'OVERWORLD DISTANCE',
            style: AppTextStyles.label.copyWith(
              color: AppColors.cyan,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (controller.distanceState) {
      DistanceState.loading => const Center(
        child: CircularProgressIndicator(color: AppColors.yellow),
      ),
      DistanceState.bothOff => _BothOffState(controller: controller),
      DistanceState.together => _TogetherState(controller: controller),
      DistanceState.networkFail => _NetworkFailState(controller: controller),
      DistanceState.bothLive ||
      DistanceState.partial => _LiveDistanceState(controller: controller),
    };
  }
}

// ── Hero sprites ──────────────────────────────────────────────────────────────

/// Displays both partner sprites side-by-side with the distance in between.
class _SpriteRow extends StatelessWidget {
  final String mySprite;
  final String partnerSprite;
  final Widget center;
  const _SpriteRow({
    required this.mySprite,
    required this.partnerSprite,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // My sprite — left
        _HeroSprite(spriteId: mySprite, borderColor: AppColors.coral),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: center),
        const SizedBox(width: AppSpacing.sm),
        // Partner sprite — right
        _HeroSprite(spriteId: partnerSprite, borderColor: AppColors.cyan),
      ],
    );
  }
}

class _HeroSprite extends StatelessWidget {
  final String spriteId;
  final Color borderColor;
  const _HeroSprite({required this.spriteId, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      alignment: Alignment.center,
      child: SpriteAvatar(spriteId: spriteId, size: 60),
    );
  }
}

// ── Distance states ───────────────────────────────────────────────────────────

class _LiveDistanceState extends StatelessWidget {
  final DashboardController controller;
  const _LiveDistanceState({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isPartial = controller.isApproximateDistance;
    final distance = controller.displayDistance;
    final prefix = isPartial ? '~' : '';
    final distText = distance != null
        ? '$prefix${_fmt(distance)} ${controller.distanceUnit}\nAPART'
        : '--- ${controller.distanceUnit}\nAPART';

    return Column(
      children: [
        _SpriteRow(
          mySprite: controller.me?.avatarSpriteId ?? '👤',
          partnerSprite: controller.partner?.avatarSpriteId ?? '👤',
          center: Text(
            distText,
            textAlign: TextAlign.center,
            style: AppTextStyles.header.copyWith(
              color: AppColors.yellow,
              fontSize: 21,
              height: 1.35,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
        if (isPartial) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              border: Border.all(color: AppColors.amber, width: 1),
            ),
            child: Text(
              'APPROX — ${controller.partner?.displayName?.toUpperCase() ?? 'PARTNER'}\'S GPS OFF',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.amber,
                fontSize: 8,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                controller.myCity.isEmpty
                    ? 'HOME CITY NOT SET'
                    : controller.myCity,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                  fontSize: 7,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                '\u2194',
                style: AppTextStyles.label.copyWith(fontSize: 9),
              ),
            ),
            Expanded(
              child: Text(
                '${controller.partnerCity.isEmpty ? 'HOME CITY NOT SET' : controller.partnerCity}${isPartial ? ' (APPROX.)' : ''}',
                textAlign: TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                  fontSize: 7,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: AppColors.charcoal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❤️', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 6),
              Text(
                'TOGETHER: ${controller.daysTogetherthisYear} DAYS IN ${DateTime.now().year}',
                style: AppTextStyles.caption.copyWith(fontSize: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double km) => km
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

class _BothOffState extends StatelessWidget {
  final DashboardController controller;
  const _BothOffState({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SpriteRow(
          mySprite: controller.me?.avatarSpriteId ?? '👤',
          partnerSprite: controller.partner?.avatarSpriteId ?? '👤',
          center: Text(
            '--- ${controller.distanceUnit}\nAPART',
            textAlign: TextAlign.center,
            style: AppTextStyles.header.copyWith(
              color: AppColors.yellow,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  controller.myCity.isEmpty
                      ? 'HOME CITY NOT SET'
                      : controller.myCity,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.cyan,
                    fontSize: 7,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  '\u2194',
                  style: AppTextStyles.label.copyWith(fontSize: 9),
                ),
              ),
              Expanded(
                child: Text(
                  controller.partnerCity.isEmpty
                      ? 'HOME CITY NOT SET'
                      : controller.partnerCity,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.cyan,
                    fontSize: 7,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Icon(Icons.location_off, size: 28, color: AppColors.coral),
        const SizedBox(height: AppSpacing.md),
        Text(
          'TURN ON LOCATION TO SEE\nYOUR LIVE DISTANCE',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white70,
            height: 1.8,
            fontSize: 8,
          ),
        ),
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
  final DashboardController controller;
  const _TogetherState({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SpriteRow(
          mySprite: controller.me?.avatarSpriteId ?? '👤',
          partnerSprite: controller.partner?.avatarSpriteId ?? '👤',
          center: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                "YOU'RE\nTOGETHER!",
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.yellow,
                  fontSize: 10,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'MAKE THIS ONE COUNT ❤',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.cyan),
        ),
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
        Text(
          "COULDN'T REFRESH LOCATION.\nSHOWING LAST KNOWN DISTANCE.",
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.amber,
            height: 1.8,
            fontSize: 8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${controller.displayDistance?.toStringAsFixed(0) ?? '---'} ${controller.distanceUnit} APART',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: AppColors.yellow,
            fontSize: 12,
          ),
        ),
        if (controller.lastUpdated != null)
          Text(
            'LAST UPDATED: ${_ago(controller.lastUpdated!)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.gray,
              fontSize: 7,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        PixelButton(
          label: '[ RETRY ]',
          style: PixelButtonStyle.outline,
          onPressed: controller.refreshMyLocation,
        ),
      ],
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    return '${diff.inHours}H AGO';
  }
}
