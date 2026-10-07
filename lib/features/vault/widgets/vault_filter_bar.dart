import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/vault_controller.dart';

class VaultFilterBar extends StatelessWidget {
  final VaultFilter current;
  final VaultSenderFilter sender;
  final VaultStatusFilter status;
  final bool showArchived;
  final int totalCount;
  final ValueChanged<VaultFilter> onSelect;
  final ValueChanged<VaultSenderFilter> onSenderSelect;
  final ValueChanged<VaultStatusFilter> onStatusSelect;
  final ValueChanged<bool> onArchiveSelect;

  const VaultFilterBar({
    super.key,
    required this.current,
    required this.sender,
    required this.status,
    required this.showArchived,
    required this.totalCount,
    required this.onSelect,
    required this.onSenderSelect,
    required this.onStatusSelect,
    required this.onArchiveSelect,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdown<VaultFilter>(
                  current,
                  {
                    VaultFilter.all: 'ALL VAULTS',
                    VaultFilter.dateLocked: 'DATE LOCKED',
                    VaultFilter.dualTap: 'DUAL TAP',
                  },
                  onSelect,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _dropdown<VaultSenderFilter>(
                  sender,
                  {
                    VaultSenderFilter.all: 'ALL',
                    VaultSenderFilter.byYou: 'BY YOU',
                    VaultSenderFilter.byPartner: 'BY PARTNER',
                  },
                  onSenderSelect,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _dropdown<VaultStatusFilter>(
                  status,
                  {
                    VaultStatusFilter.all: 'ALL STATUSES',
                    VaultStatusFilter.unlocked: 'UNLOCKED',
                    VaultStatusFilter.locked: 'LOCKED',
                  },
                  onStatusSelect,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${showArchived ? 'ARCHIVED' : 'ACTIVE'} ($totalCount)',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.cyan, fontSize: 6),
              ),
              GestureDetector(
                onTap: () => onArchiveSelect(!showArchived),
                child: Text(
                  showArchived ? '[ VIEW ACTIVE ]' : '[ VIEW ARCHIVE ]',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.yellow, fontSize: 6),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _dropdown<T>(
    T value,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) =>
      Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: AppColors.cyan, width: 1),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            dropdownColor: AppColors.purple,
            icon: const Icon(
              Icons.arrow_drop_down,
              color: AppColors.yellow,
              size: 16,
            ),
            style: AppTextStyles.caption
                .copyWith(color: AppColors.cyan, fontSize: 5),
            items: options.entries
                .map((entry) => DropdownMenuItem<T>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (selected) {
              if (selected != null) onChanged(selected);
            },
          ),
        ),
      );
}
