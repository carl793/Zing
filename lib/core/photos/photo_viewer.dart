import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_controls.dart';
import '../widgets/pixel_icon.dart';
import 'pixel_photo.dart';

/// Photos full screen: swipe between them, pinch or double-tap to zoom, rotate,
/// and drag up or down to leave. The only screen that turns with the phone.
class PhotoViewer extends StatefulWidget {
  final List<PhotoItem> photos;
  final int initialIndex;
  final String title;

  const PhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.title = '',
  });

  /// Resolves to the photo that was showing when it closed.
  static Future<int?> open(
    BuildContext context, {
    required List<PhotoItem> photos,
    int initialIndex = 0,
    String title = '',
  }) =>
      Navigator.of(context, rootNavigator: true).push<int>(
        PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 160),
          reverseTransitionDuration: const Duration(milliseconds: 140),
          pageBuilder: (_, _, _) => PhotoViewer(
            photos: photos,
            initialIndex: initialIndex,
            title: title,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// Quarter turns per photo.
  final Map<int, int> _turns = {};
  bool _zoomed = false;
  bool _bars = true;
  int _fingers = 0;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pages.dispose();
    super.dispose();
  }

  void _close() {
    AudioService.instance.playSfx(AppSfx.close);
    Navigator.of(context).pop(_index);
  }

  void _countFingers(int change) {
    final before = _fingers;
    _fingers = (_fingers + change).clamp(0, 10);
    // A second finger means zooming, not turning the page.
    if ((before > 1) != (_fingers > 1)) setState(() {});
  }

  void _endDrag(DragEndDetails details) {
    final fast = (details.primaryVelocity ?? 0).abs() > 700;
    if (_drag.abs() > 110 || (fast && _drag.abs() > 20)) {
      _close();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.photos.length > 1;
    final locked = _zoomed || _fingers > 1;

    return Scaffold(
      backgroundColor: Colors.black
          .withValues(alpha: (1 - _drag.abs() / 500).clamp(0.35, 1)),
      body: Stack(
        children: [
          Listener(
            onPointerDown: (_) => _countFingers(1),
            onPointerUp: (_) => _countFingers(-1),
            onPointerCancel: (_) => _countFingers(-1),
            child: GestureDetector(
              onTap: () => setState(() => _bars = !_bars),
              onVerticalDragUpdate: locked
                  ? null
                  : (d) => setState(() => _drag += d.delta.dy),
              onVerticalDragEnd: locked ? null : _endDrag,
              onVerticalDragCancel:
                  locked ? null : () => setState(() => _drag = 0),
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: widget.photos.length,
                  allowImplicitScrolling: true,
                  physics: locked
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (i) => setState(() {
                    _index = i;
                    _zoomed = false;
                  }),
                  itemBuilder: (_, i) => _ZoomablePhoto(
                    photo: widget.photos[i],
                    quarterTurns: _turns[i] ?? 0,
                    isCurrent: i == _index,
                    onZoom: (zoomed) {
                      if (i == _index && zoomed != _zoomed) {
                        setState(() => _zoomed = zoomed);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_bars && _drag == 0)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    if (many) ...[
                      PixelTag(
                        '${_index + 1}/${widget.photos.length}',
                        color: AppColors.white,
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.white),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    PixelIconButton(
                      icon: PixelIcons.rotate,
                      label: 'Rotate',
                      onPressed: () => setState(() =>
                          _turns[_index] = ((_turns[_index] ?? 0) + 1) % 4),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PixelIconButton(
                      icon: PixelIcons.close,
                      label: 'Close',
                      sfx: AppSfx.close,
                      onPressed: () => Navigator.of(context).pop(_index),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  final PhotoItem photo;
  final int quarterTurns;
  final bool isCurrent;
  final ValueChanged<bool> onZoom;

  const _ZoomablePhoto({
    required this.photo,
    required this.quarterTurns,
    required this.isCurrent,
    required this.onZoom,
  });

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  static const _doubleTapScale = 2.5;

  final _view = TransformationController();
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(_animate);
  Matrix4Tween? _path;
  Offset _tapAt = Offset.zero;

  bool get _isZoomed => _view.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _view.addListener(() => widget.onZoom(_isZoomed));
  }

  @override
  void didUpdateWidget(_ZoomablePhoto old) {
    super.didUpdateWidget(old);
    // Left behind, or turned: back to the whole photo.
    final left = old.isCurrent && !widget.isCurrent;
    if (left || old.quarterTurns != widget.quarterTurns) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _view.value = Matrix4.identity();
      });
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _view.dispose();
    super.dispose();
  }

  void _animate() {
    final path = _path;
    if (path != null) {
      _view.value = path.transform(Curves.easeOut.transform(_motion.value));
    }
  }

  void _toggleZoom() {
    final Matrix4 target;
    if (_isZoomed) {
      target = Matrix4.identity();
    } else {
      // Zooms in on the spot that was tapped.
      const s = _doubleTapScale;
      target = Matrix4.identity()
        ..translateByDouble(-_tapAt.dx * (s - 1), -_tapAt.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    _path = Matrix4Tween(begin: _view.value, end: target);
    _motion.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _view,
        maxScale: 5,
        onInteractionStart: (_) => _motion.stop(),
        child: SizedBox.expand(
          child: RotatedBox(
            quarterTurns: widget.quarterTurns,
            child: PixelPhoto(widget.photo, fit: BoxFit.contain, full: true),
          ),
        ),
      ),
    );
  }
}
