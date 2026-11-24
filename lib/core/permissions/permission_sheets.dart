import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_modal_shell.dart';

/// What Zing asks for, and how it explains itself.
enum PermissionKind {
  location(
    icon: Icons.place,
    title: 'SHARE YOUR\nLOCATION?',
    why: 'Zing uses your location to show how far apart you and your partner '
        'are.',
    points: [
      'Only your linked partner can see it.',
      'Checked only while the app is open.',
      'Turn it off any time in CONFIG.',
    ],
    fallback: 'Without it, your home city is used instead.',
    blockedTitle: 'LOCATION IS\nBLOCKED',
    blockedHow: 'Open settings, tap Permissions, then Location, and choose '
        '"Allow only while using the app".',
  ),
  microphone(
    icon: Icons.mic,
    title: 'RECORD A\nVOICE NOTE?',
    why: 'Zing uses the microphone to record a voice note for your chest.',
    points: [
      'Records only while you see the timer.',
      'Saved only when you seal the chest.',
    ],
    fallback: 'Without it, you can still add a note and a photo.',
    blockedTitle: 'MICROPHONE IS\nBLOCKED',
    blockedHow: 'Open settings, tap Permissions, then Microphone, and choose '
        '"Allow only while using the app".',
  ),
  photos(
    icon: Icons.photo_library,
    title: 'PICK A\nPHOTO?',
    why: 'Zing opens your gallery so you can choose a photo.',
    points: [
      'Zing only sees the photos you pick.',
      'Photos are uploaded when you save.',
    ],
    fallback: 'You can always save without a photo.',
    blockedTitle: 'PHOTOS ARE\nBLOCKED',
    blockedHow: 'Open settings, tap Permissions, then Photos, and allow '
        'access.',
  );

  const PermissionKind({
    required this.icon,
    required this.title,
    required this.why,
    required this.points,
    required this.fallback,
    required this.blockedTitle,
    required this.blockedHow,
  });

  final IconData icon;
  final String title;
  final String why;
  final List<String> points;
  final String fallback;
  final String blockedTitle;
  final String blockedHow;
}

/// Explains a permission before the system asks. True when the user agrees to
/// continue to the system prompt.
Future<bool> showPermissionPrimer(
  BuildContext context,
  PermissionKind kind,
) async {
  final agreed = await showPixelSheet<bool>(
    context: context,
    builder: (_) => _PermissionSheet(
      kind: kind,
      title: kind.title,
      message: kind.why,
      points: kind.points,
      confirmLabel: '[ CONTINUE ]',
    ),
  );
  return agreed ?? false;
}

/// Explains why something is unavailable and offers the way to fix it. True
/// when the user chose to open the settings.
Future<bool> showPermissionBlocked(
  BuildContext context,
  PermissionKind kind, {
  String? title,
  String? how,
}) async {
  final open = await showPixelSheet<bool>(
    context: context,
    builder: (_) => _PermissionSheet(
      kind: kind,
      title: title ?? kind.blockedTitle,
      message: how ?? kind.blockedHow,
      points: const [],
      confirmLabel: '[ OPEN SETTINGS ]',
    ),
  );
  return open ?? false;
}

class _PermissionSheet extends StatelessWidget {
  final PermissionKind kind;
  final String title;
  final String message;
  final List<String> points;
  final String confirmLabel;

  const _PermissionSheet({
    required this.kind,
    required this.title,
    required this.message,
    required this.points,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final body = AppTextStyles.body.copyWith(height: 1.8);
    return PixelModalShell(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(kind.icon, size: 40, color: AppColors.yellow),
          const SizedBox(height: AppSpacing.lg),
          Text(message, textAlign: TextAlign.center, style: body),
          for (final point in points) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 14, color: AppColors.cyan),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(point, style: body)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            kind.fallback,
            textAlign: TextAlign.center,
            style: body.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: AppSpacing.xl),
          PixelButton(
            label: confirmLabel,
            style: PixelButtonStyle.yellow,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.md),
          PixelButton(
            label: '[ NOT NOW ]',
            style: PixelButtonStyle.outline,
            backgroundColor: AppColors.charcoal,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
