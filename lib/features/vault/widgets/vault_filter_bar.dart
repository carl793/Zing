import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/vault_controller.dart';

class VaultFilterBar extends StatelessWidget {
  final VaultFilter current;
  final int totalCount;
  final ValueChanged<VaultFilter> onSelect;

  const VaultFilterBar({
    super.key,
    required this.current,
    required this.totalCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'ALL ($totalCount)',
            active: current == VaultFilter.all,
            onTap: () => onSelect(VaultFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'DATE-LOCKED',
            active: current == VaultFilter.dateLocked,
            onTap: () => onSelect(VaultFilter.dateLocked),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'DUAL-TAP',
            active: current == VaultFilter.dualTap,
            onTap: () => onSelect(VaultFilter.dualTap),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.yellow : Colors.transparent,
          border: Border.all(
            color: active ? Colors.black : AppColors.cyan,
            width: 2,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          '[ $label ]',
          style: AppTextStyles.caption.copyWith(
            fontSize: 6,
            color: active ? Colors.black : AppColors.cyan,
          ),
        ),
      ),
    );
  }
}