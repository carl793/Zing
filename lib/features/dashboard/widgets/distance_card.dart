import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/permissions/permission_flows.dart';
import '../../../core/services/location_service.dart';
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
          switch (controller.distanceState) {
            DistanceState.loading => const Center(
                child: CircularProgressIndicator(color: AppColors.yellow),
              ),
            DistanceState.failed => const _LoadFailed(),
            _ => _Distance(controller: controller),
          },
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) => Text(
        "COULDN'T LOAD YOUR ROOM.\nRETRYING...",
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.amber),
      );
}

class _Distance extends StatelessWidget {
  final DashboardController controller;
  const _Distance({required this.controller});

  @override
  Widget build(BuildContext context) {
    final reason = controller.approximateReason;
    final isTogether = controller.distanceState == DistanceState.together;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _HeroSprite(
              spriteId: controller.me?.avatarSpriteId,
              borderColor: AppColors.coral,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: isTogether ? const _Together() : _Apart(controller),
            ),
            const SizedBox(width: AppSpacing.sm),
            _HeroSprite(
              spriteId: controller.partner?.avatarSpriteId,
              borderColor: AppColors.cyan,
            ),
          ],
        ),
        if (controller.distanceState == DistanceState.apart &&
            reason != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _Note(reason),
        ],
        const SizedBox(height: AppSpacing.sm),
        _Cities(controller),
        _LocationAction(controller),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: AppColors.charcoal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❤️', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'TOGETHER: ${controller.daysTogetherThisYear} '
                  '${controller.daysTogetherThisYear == 1 ? 'DAY' : 'DAYS'} '
                  'IN ${DateTime.now().year}',
                  style: AppTextStyles.caption.copyWith(fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Apart extends StatelessWidget {
  final DashboardController controller;
  const _Apart(this.controller);

  @override
  Widget build(BuildContext context) {
    final distance = controller.displayDistance;
    final value = distance == null
        ? '---'
        : '${controller.isApproximate ? '~' : ''}${_format(distance)}';
    return Text(
      '$value ${controller.distanceUnit}\nAPART',
      textAlign: TextAlign.center,
      style: AppTextStyles.header.copyWith(
        color: AppColors.yellow,
        fontSize: 18,
        height: 1.35,
        shadows: const [
          Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
    );
  }

  /// "12,345"
  static String _format(double value) =>
      value.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]},',
          );
}

class _Together extends StatelessWidget {
  const _Together();

  @override
  Widget build(BuildContext context) => Column(
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
                Shadow(color: Colors.black, offset: Offset(2, 2)),
              ],
            ),
          ),
          Text(
            'MAKE THIS ONE COUNT ❤',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.cyan),
          ),
        ],
      );
}

/// Both home cities, under the sprites.
class _Cities extends StatelessWidget {
  final DashboardController controller;
  const _Cities(this.controller);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _city(controller.me?.homeCity, TextAlign.right)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text('↔', style: AppTextStyles.label.copyWith(fontSize: 9)),
        ),
        Expanded(child: _city(controller.partner?.homeCity, TextAlign.left)),
      ],
    );
  }

  Widget _city(String? city, TextAlign align) => Text(
        city == null || city.isEmpty ? 'HOME CITY NOT SET' : city,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white70,
          fontSize: 7,
        ),
      );
}

/// What this player can do about their own location, if anything.
class _LocationAction extends StatelessWidget {
  final DashboardController controller;
  const _LocationAction(this.controller);

  @override
  Widget build(BuildContext context) {
    if (controller.locating) {
      return _padded(const _Note('LOCATING YOU...', color: AppColors.cyan));
    }
    if (!controller.isSharing || controller.sharingBlocked) {
      return _padded(
        PixelButton(
          label: controller.sharingBlocked
              ? '[ FIX LOCATION ACCESS ]'
              : '[ SHARE MY LOCATION ]',
          style: PixelButtonStyle.yellow,
          onPressed: () => _share(context),
        ),
      );
    }
    if (controller.positionUnavailable) {
      return _padded(
        PixelButton(
          label: "[ COULDN'T LOCATE YOU. RETRY ]",
          style: PixelButtonStyle.outline,
          backgroundColor: AppColors.charcoal,
          onPressed: controller.refreshLocation,
        ),
      );
    }
    if (controller.distanceState == DistanceState.unknown) {
      return _padded(
        _Note("WAITING FOR ${controller.session.partnerName}'S LOCATION "
            'OR HOME CITY'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: child,
      );

  Future<void> _share(BuildContext context) async {
    final granted =
        await ensureLocationAccess(context, context.read<LocationService>());
    if (granted) await controller.startSharing();
  }
}

class _Note extends StatelessWidget {
  final String text;
  final Color color;
  const _Note(this.text, {this.color = AppColors.amber});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 7,
            height: 1.6,
          ),
        ),
      );
}

class _HeroSprite extends StatelessWidget {
  final String? spriteId;
  final Color borderColor;
  const _HeroSprite({required this.spriteId, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final id = spriteId;
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
      child: id == null || id.isEmpty
          ? null
          : SpriteAvatar(spriteId: id, size: 60),
    );
  }
}
