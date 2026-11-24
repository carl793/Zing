import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_icon.dart';

VoidCallback? _hideCurrent;

/// Shows a short message at the top of the screen, replacing any message
/// already showing. It sits above everything, open sheets included. Coral ones
/// are failures, and sound like it.
void showPixelToast(
  BuildContext context,
  String message, {
  Color color = AppColors.yellow,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  if (color == AppColors.coral) {
    AudioService.instance
      ..playSfx(AppSfx.error)
      ..knock(strong: true);
  }
  _hideCurrent?.call();

  var removed = false;
  late final OverlayEntry entry;
  void hide() {
    if (removed) return;
    removed = true;
    if (_hideCurrent == hide) _hideCurrent = null;
    entry
      ..remove()
      ..dispose();
  }

  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, color: color, onDone: hide),
  );
  _hideCurrent = hide;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final Color color;
  final VoidCallback onDone;
  const _Toast({
    required this.message,
    required this.color,
    required this.onDone,
  });

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with TickerProviderStateMixin {
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  /// Long enough to read: roughly a second per four words.
  late final _stay = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2000 + widget.message.length * 35),
  );

  @override
  void initState() {
    super.initState();
    _slide.forward();
    _stay.forward().whenComplete(_leave);
  }

  Future<void> _leave() async {
    if (!mounted) return;
    await _slide.reverse().orCancel.catchError((_) {});
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _slide.dispose();
    _stay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final problem = color == AppColors.coral || color == AppColors.amber;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.4), end: Offset.zero)
              .animate(CurvedAnimation(
            parent: _slide,
            curve: Curves.easeOutCubic,
          )),
          child: GestureDetector(
            onTap: _leave,
            onVerticalDragEnd: (_) => _leave(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: PixelRaised(outline: color),
                        child: Row(
                          children: [
                            PixelIcon(
                              problem ? PixelIcons.warning : PixelIcons.check,
                              color: color,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
