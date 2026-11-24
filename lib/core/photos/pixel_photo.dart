import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/pixel_loader.dart';
import 'photo_cache.dart';

/// Asks Cloudinary for a copy no wider than [width] pixels, turned the right
/// way up. Other urls are returned unchanged.
String sizedPhotoUrl(String url, int width) {
  const marker = '/image/upload/';
  final at = url.indexOf(marker);
  if (!url.contains('res.cloudinary.com') || at < 0) return url;
  final split = at + marker.length;
  return '${url.substring(0, split)}c_limit,w_$width,q_auto/'
      '${url.substring(split)}';
}

/// One photo: already uploaded, or just picked from the gallery.
class PhotoItem {
  final String? url;
  final Uint8List? bytes;
  const PhotoItem.url(String this.url) : bytes = null;
  const PhotoItem.bytes(Uint8List this.bytes) : url = null;

  static const _thumbWidth = 200;

  /// The largest copy that is stored.
  static const fullWidth = 1600;

  /// A copy decoded no wider than [width] pixels.
  ImageProvider sized(int width) {
    final link = url;
    return ResizeImage.resizeIfNeeded(
      width,
      null,
      link == null
          ? MemoryImage(bytes!)
          : CachedPhoto(sizedPhotoUrl(link, width), fallback: link),
    );
  }

  ImageProvider get thumb => sized(_thumbWidth);

  /// So small that, enlarged, it turns into a mosaic.
  ImageProvider get mosaic => ResizeImage(
        url == null
            ? MemoryImage(bytes!)
            : CachedPhoto(sizedPhotoUrl(url!, _thumbWidth), fallback: url),
        width: 18,
      );
}

/// A photo loaded no larger than it's shown. It appears as a mosaic first, then
/// snaps into focus.
class PixelPhoto extends StatefulWidget {
  final PhotoItem photo;

  /// [BoxFit.contain] always shows the whole photo, whatever its shape.
  final BoxFit fit;

  /// Loads the largest copy, for zooming in.
  final bool full;

  const PixelPhoto(
    this.photo, {
    super.key,
    this.fit = BoxFit.cover,
    this.full = false,
  });

  @override
  State<PixelPhoto> createState() => _PixelPhotoState();
}

class _PixelPhotoState extends State<PixelPhoto> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final logical = box.hasBoundedWidth
            ? box.maxWidth
            : MediaQuery.sizeOf(context).width;
        final pixels = logical * MediaQuery.devicePixelRatioOf(context);
        // Rounded up to steps, so similar sizes share one stored copy.
        final width = widget.full
            ? PhotoItem.fullWidth
            : ((pixels / 200).ceil() * 200).clamp(200, PhotoItem.fullWidth);
        return Image(
          key: ValueKey(_attempt),
          image: widget.photo.sized(width),
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (_, child, frame, wasReady) =>
              wasReady || frame != null ? child : _loading(),
          errorBuilder: (_, _, _) => _failed(box),
        );
      },
    );
  }

  Widget _loading() => Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: widget.photo.mosaic,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          const Center(child: PixelLoader(size: 5)),
        ],
      );

  Widget _failed(BoxConstraints box) {
    // Too small to say more than that it's missing.
    if (box.maxWidth < 120) {
      return const Center(
        child: PixelIcon(PixelIcons.cloudOff, color: AppColors.faint),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _attempt++),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelIcon(PixelIcons.cloudOff,
                size: 24, color: AppColors.faint),
            const SizedBox(height: AppSpacing.md),
            Text(
              "COULDN'T LOAD\nTAP TO RETRY",
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// The dimmed mosaic that fills whatever a photo's shape leaves empty.
class PhotoMosaic extends StatelessWidget {
  final PhotoItem photo;
  const PhotoMosaic(this.photo, {super.key});

  @override
  Widget build(BuildContext context) => Image(
        image: photo.mosaic,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.none,
        color: const Color(0xB3161532),
        colorBlendMode: BlendMode.srcATop,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
}
