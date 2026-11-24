import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Asks Cloudinary for a copy no wider than [width] pixels. Other urls are
/// returned unchanged.
String sizedPhotoUrl(String url, int width) {
  const marker = '/image/upload/';
  final at = url.indexOf(marker);
  if (!url.contains('res.cloudinary.com') || at < 0) return url;
  final split = at + marker.length;
  return '${url.substring(0, split)}c_limit,w_$width,q_auto/'
      '${url.substring(split)}';
}

/// A network photo downloaded and decoded at the size it is shown, instead of
/// the full 1600px original. Falls back to the original, then to an icon.
class RemotePhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const RemotePhoto(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final pixels = logical * MediaQuery.devicePixelRatioOf(context);
        // Rounded up to steps, so similar sizes share one cached copy.
        final width = ((pixels / 200).ceil() * 200).clamp(200, 1600);
        return Image.network(
          sizedPhotoUrl(url, width),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: _loading,
          errorBuilder: (_, _, _) => Image.network(
            url,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: width,
            loadingBuilder: _loading,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image, color: AppColors.gray),
            ),
          ),
        );
      },
    );
  }

  static Widget _loading(
    BuildContext context,
    Widget child,
    ImageChunkEvent? progress,
  ) =>
      progress == null
          ? child
          : const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.yellow,
                ),
              ),
            );
}
