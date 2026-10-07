import 'package:flutter/material.dart';

import '../constants/sprite_options.dart';
import '../theme/app_colors.dart';
import 'sprite_avatar.dart';

/// Preserves the original square pixel picker while offering the SVG heroes.
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
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: SpriteOptions.selectable.map((option) {
          final selected = selectedId == option.id;
          return GestureDetector(
            onTap: () => onSelected(option.id),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.purple,
                border: Border.all(
                  color: selected ? AppColors.yellow : Colors.black,
                  width: selected ? 3 : 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: SpriteAvatar(
                spriteId: option.id,
                size: selected ? 46 : 40,
              ),
            ),
          );
        }).toList(),
      );
}
