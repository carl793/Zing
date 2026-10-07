import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PixelNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PixelNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _tabs = [
    _NavTab(icon: Icons.map, label: 'OVERWORLD'),
    _NavTab(icon: Icons.calendar_today, label: 'CALENDAR'),
    _NavTab(icon: Icons.lock, label: 'VAULT'),
    _NavTab(icon: Icons.settings, label: 'CONFIG'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.charcoal,
        border: Border(top: BorderSide(color: Colors.black, width: 2)),
        boxShadow: [
          BoxShadow(color: Colors.black, offset: Offset(0, -4), blurRadius: 0),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppColors.yellow : Colors.transparent,
                  border: i < _tabs.length - 1
                      ? const Border(
                          right: BorderSide(color: Colors.black, width: 1),
                        )
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabs[i].icon,
                      size: 18,
                      color: active ? Colors.black : AppColors.gray,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tabs[i].label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 7,
                        color: active ? Colors.black : AppColors.gray,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;
  const _NavTab({required this.icon, required this.label});
}
