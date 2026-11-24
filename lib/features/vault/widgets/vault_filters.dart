import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/vault_controller.dart';

/// Every filter in one sheet. The vault behind changes as they are chosen.
class VaultFilterSheet extends StatelessWidget {
  const VaultFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultController>();
    return PixelModalShell(
      title: 'FILTER CHESTS',
      icon: PixelIcons.filter,
      footer: Row(
        children: [
          Expanded(
            child: PixelButton(
              label: 'CLEAR',
              style: PixelButtonStyle.neutral,
              onPressed: vault.hasFilters ? vault.clearFilters : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PixelButton(
              label: 'SHOW ${vault.capsules.length}',
              icon: PixelIcons.check,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Group<VaultSenderFilter>(
            label: 'FROM',
            value: vault.senderFilter,
            options: {
              VaultSenderFilter.all: 'ANYONE',
              VaultSenderFilter.byYou: 'YOU',
              VaultSenderFilter.byPartner: vault.partnerName,
            },
            onSelected: vault.setSenderFilter,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Group<VaultStatusFilter>(
            label: 'STATUS',
            value: vault.statusFilter,
            options: const {
              VaultStatusFilter.all: 'ANY',
              VaultStatusFilter.locked: 'LOCKED',
              VaultStatusFilter.unlocked: 'OPEN',
            },
            onSelected: vault.setStatusFilter,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Group<VaultFilter>(
            label: 'OPENS BY',
            value: vault.filter,
            options: const {
              VaultFilter.all: 'ANY',
              VaultFilter.dateLocked: 'DATE',
              VaultFilter.dualTap: 'DUAL TAP',
            },
            onSelected: vault.setFilter,
          ),
        ],
      ),
    );
  }
}

class _Group<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  const _Group({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelLabel(label),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final MapEntry(:key, value: text) in options.entries)
                PixelChip(
                  label: text,
                  selected: key == value,
                  onTap: () => onSelected(key),
                ),
            ],
          ),
        ],
      );
}
