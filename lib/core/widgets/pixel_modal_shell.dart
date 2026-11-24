import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_button.dart';
import 'pixel_dialog.dart';
import 'pixel_icon.dart';
import 'pixel_panel.dart';

/// Opens a bottom sheet. Pass a [PixelModalShell] as its content. Forms can't
/// be dragged away ([isForm]), since that would skip asking about their work.
Future<T?> showPixelSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isForm = false,
}) {
  AudioService.instance.playSfx(AppSfx.open);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: !isForm,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC08081A),
    elevation: 0,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 200),
      reverseDuration: Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
    ),
    builder: builder,
  );
}

/// The frame of every sheet: a title bar, a body that scrolls, and a [footer]
/// that stays in reach, above the keyboard too.
class PixelModalShell extends StatelessWidget {
  final String title;
  final PixelIcons? icon;
  final Color titleColor;
  final Widget child;

  /// The sheet's actions.
  final Widget? footer;

  /// True while something typed here would be lost; closing then asks first.
  final bool Function()? hasUnsavedWork;

  /// True while closing would interrupt a save.
  final bool busy;

  const PixelModalShell({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.titleColor = AppColors.cyan,
    this.footer,
    this.hasUnsavedWork,
    this.busy = false,
  });

  Future<void> _close(BuildContext context) async {
    if (busy) return;
    final navigator = Navigator.of(context);
    if (hasUnsavedWork?.call() ?? false) {
      final discard = await showConfirmDialog(
        context: context,
        title: 'NOT SAVED YET',
        message: 'Close this and lose what you wrote?',
        confirmLabel: 'DISCARD',
        confirmIcon: PixelIcons.trash,
        cancelLabel: 'KEEP WRITING',
      );
      if (!discard || !navigator.mounted) return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // Above the keyboard, or else above the phone's own gesture bar.
    final bottom = keyboard > 0 ? keyboard : 0.0;
    final bar = keyboard > 0 ? 0.0 : media.viewPadding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(context);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Center(
          heightFactor: 1,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: media.size.height * 0.93,
              maxWidth: 560,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const PixelRaised(depth: 0, shadow: 0),
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelTitleBar(
                  title: title,
                  icon: icon,
                  color: titleColor,
                  trailing: PixelIconButton(
                    icon: PixelIcons.close,
                    label: 'Close',
                    size: 36,
                    sfx: AppSfx.close,
                    onPressed: busy ? null : () => _close(context),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg + (footer == null ? bar : 0),
                    ),
                    child: child,
                  ),
                ),
                if (footer != null)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md + bar,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0x33000020),
                      border: Border(
                        top: BorderSide(
                            color: Color(0xFF1C1A3F), width: kPixel),
                      ),
                    ),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
