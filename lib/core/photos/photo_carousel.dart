import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/pixel_pressable.dart';
import 'photo_viewer.dart';
import 'pixel_photo.dart';

/// Swipeable photos, each shown whole. The frame grows and shrinks to fit the
/// shape of the photo in it; tapping one opens it full screen.
class PhotoCarousel extends StatefulWidget {
  final List<PhotoItem> photos;
  final String title;

  const PhotoCarousel({super.key, required this.photos, this.title = ''});

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  /// Used until a photo's shape is known.
  static const _defaultAspect = 4 / 3;

  final _pages = PageController();
  int _index = 0;

  /// Width over height, per photo.
  final Map<int, double> _aspects = {};
  final List<(ImageStream, ImageStreamListener)> _measuring = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.photos.length; i++) {
      _measure(i);
    }
  }

  void _measure(int i) {
    final stream = widget.photos[i].thumb.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        final aspect = info.image.width / info.image.height;
        info.dispose();
        if (!mounted || _aspects[i] == aspect) return;
        setState(() => _aspects[i] = aspect);
      },
      onError: (_, _) {},
    );
    stream.addListener(listener);
    _measuring.add((stream, listener));
  }

  @override
  void dispose() {
    for (final (stream, listener) in _measuring) {
      stream.removeListener(listener);
    }
    _pages.dispose();
    super.dispose();
  }

  /// Tall photos get a tall frame and wide ones a low frame, within reason. A
  /// photo beyond those limits still fits whole, with space beside it.
  double _heightOf(int i, double width, double tallest) {
    final natural = width / (_aspects[i] ?? _defaultAspect);
    final lowest = width * 0.5;
    return natural.clamp(lowest, math.max(lowest, tallest));
  }

  double _currentHeight(double width, double tallest) {
    final page = _pages.hasClients && _pages.position.haveDimensions
        ? _pages.page ?? _index.toDouble()
        : _index.toDouble();
    final last = widget.photos.length - 1;
    final from = page.floor().clamp(0, last);
    final to = page.ceil().clamp(0, last);
    return lerpDouble(
      _heightOf(from, width, tallest),
      _heightOf(to, width, tallest),
      (page - from).clamp(0.0, 1.0),
    )!;
  }

  void _go(int index) => _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );

  Future<void> _open(int index) async {
    AudioService.instance.playSfx(AppSfx.open);
    final last = await PhotoViewer.open(
      context,
      photos: widget.photos,
      initialIndex: index,
      title: widget.title,
    );
    // Come back to the photo that was being looked at.
    if (last != null && mounted && _pages.hasClients) _pages.jumpToPage(last);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    final many = photos.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Above the frame, so the keys stay put while the frame changes height.
        if (many) ...[
          _strip(photos),
          const SizedBox(height: AppSpacing.sm),
        ],
        LayoutBuilder(
          builder: (context, box) {
            final inner = box.maxWidth - kPixel * 2;
            final tallest = math.min(
              inner * 1.3,
              MediaQuery.sizeOf(context).height * 0.5,
            );
            return AnimatedBuilder(
              animation: _pages,
              builder: (_, child) => SizedBox(
                height: _currentHeight(inner, tallest) + kPixel * 3,
                child: child,
              ),
              child: Container(
                decoration: const PixelInset(),
                clipBehavior: Clip.hardEdge,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: photos.length,
                  // Keeps the neighbours ready.
                  allowImplicitScrolling: true,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Semantics(
                    image: true,
                    button: true,
                    label: 'Photo ${i + 1} of ${photos.length}',
                    child: GestureDetector(
                      onTap: () => _open(i),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PhotoMosaic(photos[i]),
                          PixelPhoto(photos[i], fit: BoxFit.contain),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PixelIcon(PixelIcons.expand, color: AppColors.faint),
            const SizedBox(width: AppSpacing.sm),
            Text(
              many
                  ? 'PHOTO ${_index + 1} OF ${photos.length}'
                  : 'TAP TO ENLARGE',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ],
    );
  }

  Widget _strip(List<PhotoItem> photos) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PixelIconButton(
            icon: PixelIcons.left,
            label: 'Previous photo',
            size: 44,
            sfx: AppSfx.tick,
            onPressed: _index > 0 ? () => _go(_index - 1) : null,
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < photos.length; i++)
                  Flexible(
                    child: _Thumb(
                      photo: photos[i],
                      selected: i == _index,
                      onTap: () => _go(i),
                    ),
                  ),
              ],
            ),
          ),
          PixelIconButton(
            icon: PixelIcons.right,
            label: 'Next photo',
            size: 44,
            sfx: AppSfx.tick,
            onPressed: _index < photos.length - 1 ? () => _go(_index + 1) : null,
          ),
        ],
      );
}

class _Thumb extends StatelessWidget {
  final PhotoItem photo;
  final bool selected;
  final VoidCallback onTap;
  const _Thumb({
    required this.photo,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PixelPressable(
        onPressed: onTap,
        sfx: AppSfx.tick,
        selected: selected,
        builder: (_, pressed) => Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(3),
          decoration: PixelOutline(
            color: selected ? AppColors.yellow : AppColors.ink,
            fill: selected ? AppColors.yellow : AppColors.ink,
          ),
          child: ExcludeSemantics(
            child: Opacity(
              opacity: selected || pressed ? 1 : 0.6,
              child: Image(
                image: photo.thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
}
