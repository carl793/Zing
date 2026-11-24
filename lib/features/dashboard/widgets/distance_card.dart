import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/permissions/permission_flows.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_loader.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/dashboard_controller.dart';
import 'overworld_scene.dart';

/// Where the two of you are, and how far apart.
class DistanceCard extends StatelessWidget {
  final DashboardController controller;
  const DistanceCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      title: 'OVERWORLD',
      icon: PixelIcons.pin,
      padding: EdgeInsets.zero,
      trailing: controller.locating
          ? const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: PixelLoader(size: 5, color: AppColors.cyan),
            )
          : controller.isSharing && !controller.sharingBlocked
              ? PixelIconButton(
                  icon: PixelIcons.refresh,
                  label: 'Refresh my location',
                  size: 36,
                  onPressed: controller.refreshLocation,
                )
              : null,
      child: switch (controller.distanceState) {
        DistanceState.loading => const SizedBox(
            height: OverworldScene.height,
            child: PixelLoading(),
          ),
        DistanceState.failed => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: PixelNote.warning("Couldn't load your room. Retrying..."),
          ),
        _ => _Overworld(controller: controller),
      },
    );
  }
}

class _Overworld extends StatelessWidget {
  final DashboardController controller;
  const _Overworld({required this.controller});

  @override
  Widget build(BuildContext context) {
    final together = controller.distanceState == DistanceState.together;
    final distance = controller.displayDistance;
    final reason = controller.approximateReason;
    final days = controller.daysTogetherThisYear;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          child: OverworldScene(
            mySprite: controller.me?.avatarSpriteId,
            partnerSprite: controller.partner?.avatarSpriteId,
            together: together,
            value: together
                ? "YOU'RE TOGETHER!"
                : distance == null
                    ? '---'
                    : '${controller.isApproximate ? '~' : ''}'
                        '${_format(distance)}',
            caption: together
                ? 'MAKE THIS ONE COUNT'
                : '${controller.distanceUnit} APART',
          ),
        ),
        Container(height: kPixel, color: AppColors.ink),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _City(controller.me?.homeCity, AppColors.coral),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child:
                          _City(controller.partner?.homeCity, AppColors.cyan),
                    ),
                  ],
                ),
              ),
              if (controller.distanceState == DistanceState.apart &&
                  reason != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PixelNote(reason, color: AppColors.amber),
              ],
              _LocationAction(controller),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PixelIcon(PixelIcons.heart, color: AppColors.coral),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      '$days ${days == 1 ? 'DAY' : 'DAYS'} TOGETHER IN '
                      '${DateTime.now().year}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "12,345"
  static String _format(double value) =>
      value.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]},',
          );
}

class _City extends StatelessWidget {
  final String? city;
  final Color color;
  const _City(this.city, this.color);

  @override
  Widget build(BuildContext context) {
    final name = city ?? '';
    return PixelWell(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          PixelIcon(PixelIcons.pin, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name.isEmpty ? 'HOME CITY NOT SET' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                height: 1.4,
                color: name.isEmpty ? AppColors.faint : AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What this player can do about their own location, if anything.
class _LocationAction extends StatelessWidget {
  final DashboardController controller;
  const _LocationAction(this.controller);

  @override
  Widget build(BuildContext context) {
    final Widget? action;
    if (controller.locating) {
      action = null;
    } else if (!controller.isSharing || controller.sharingBlocked) {
      action = PixelButton(
        label: controller.sharingBlocked
            ? 'FIX LOCATION ACCESS'
            : 'SHARE MY LOCATION',
        icon: PixelIcons.pin,
        small: true,
        onPressed: () => _share(context),
      );
    } else if (controller.positionUnavailable) {
      action = PixelButton(
        label: "COULDN'T LOCATE YOU. RETRY",
        icon: PixelIcons.refresh,
        style: PixelButtonStyle.neutral,
        small: true,
        onPressed: controller.refreshLocation,
      );
    } else if (controller.distanceState == DistanceState.unknown) {
      action = PixelNote(
        "WAITING FOR ${controller.session.partnerName}'S LOCATION "
        'OR HOME CITY',
        color: AppColors.amber,
      );
    } else {
      action = null;
    }
    return action == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: action,
          );
  }

  Future<void> _share(BuildContext context) async {
    final granted =
        await ensureLocationAccess(context, context.read<LocationService>());
    if (granted) await controller.startSharing();
  }
}
