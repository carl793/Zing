import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Swipeable photo viewer with ‹ PHOTO 1 OF N › controls.
class PhotoCarousel extends StatefulWidget {
  final List<String> urls;
  final double height;

  const PhotoCarousel({super.key, required this.urls, this.height = 190});

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.urls.length) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.urls.length;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: count == 0
          ? Center(
              child: Text(
                '[ NO PHOTOS ]',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.gray, fontSize: 7),
              ),
            )
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Image.network(
                    widget.urls[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, progress) => progress == null
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
                          ),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: AppColors.gray),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ArrowButton(
                          icon: Icons.chevron_left,
                          enabled: _index > 0,
                          onTap: () => _go(-1),
                        ),
                        Text(
                          'PHOTO ${_index + 1} OF $count',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.cyan, fontSize: 6),
                        ),
                        _ArrowButton(
                          icon: Icons.chevron_right,
                          enabled: _index < count - 1,
                          onTap: () => _go(1),
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

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.cyan : AppColors.gray,
        ),
      ),
    );
  }
}