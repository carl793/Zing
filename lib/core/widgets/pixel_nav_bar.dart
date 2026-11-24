import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_button.dart';
import 'pixel_icon.dart';
import 'pixel_pressable.dart';

class PixelNavItem {
  final PixelIcons icon;
  final String label;

  /// Marks the tab: something there needs attention.
  final bool dot;
  const PixelNavItem(this.icon, this.label, {this.dot = false});
}

/// The tabs along the bottom. The current one is held down and lit.
class PixelNavBar extends StatelessWidget {
  final List<PixelNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PixelNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.charcoal,
        border: Border(top: BorderSide(color: AppColors.ink, width: kPixel)),
      ),
      padding: EdgeInsets.fromLTRB(
          6, 6, 6, 6 + MediaQuery.viewPaddingOf(context).bottom),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _Tab(
                item: items[i],
                active: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final PixelNavItem item;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = active ? PixelTone.yellow : PixelTone.panel;
    final color = active ? tone.text : AppColors.gray;
    return PixelPressable(
      onPressed: onTap,
      sfx: AppSfx.tick,
      selected: active,
      builder: (_, pressed) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
            decoration: PixelRaised(
              tone: tone,
              pressed: active || pressed,
              shadow: 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: PixelIcon(item.icon, size: 18, color: color)),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    style: AppTextStyles.label
                        .copyWith(color: color, letterSpacing: 0),
                  ),
                ),
              ],
            ),
          ),
          if (item.dot)
            const Positioned(top: 1, right: 6, child: PixelDot()),
        ],
      ),
    );
  }
}
