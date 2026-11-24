import 'package:flutter/material.dart';

import '../constants/sprite_options.dart';
import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_icon.dart';
import 'pixel_pressable.dart';
import 'sprite_avatar.dart';

/// A shelf of characters to choose from. The chosen one is held down and lit.
class SpriteSelector extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const SpriteSelector({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final option in SpriteOptions.selectable) _tile(option),
        ],
      );

  Widget _tile(SpriteOption option) {
    final selected = selectedId == option.id;
    return PixelPressable(
      onPressed: () => onSelected(option.id),
      sfx: AppSfx.hop,
      semanticLabel: option.label,
      selected: selected,
      builder: (_, pressed) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: PixelRaised(
                tone: PixelTone.neutral,
                outline: selected ? AppColors.yellow : AppColors.ink,
                pressed: pressed || selected,
                shadow: 2,
              ),
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (_, box) => Center(
                  child: SpriteAvatar(
                    spriteId: option.id,
                    size: box.biggest.shortestSide,
                  ),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                color: AppColors.yellow,
                child: PixelIcon(
                  PixelIcons.check,
                  color: PixelTone.yellow.text,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
