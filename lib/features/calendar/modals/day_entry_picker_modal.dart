import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/attribution_tag.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/calendar_controller.dart';

/// What the user chose in the picker.
class PickerResult {
  final MemoryModel? selected;
  final bool addRequested;

  const PickerResult.select(this.selected) : addRequested = false;
  const PickerResult.add() : selected = null, addRequested = true;
}

/// Shown when a day holds more than a single own entry — lets either partner
/// choose whose entry to open, or add their own if they haven't yet.
class DayEntryPickerModal extends StatelessWidget {
  final DateTime date;
  final List<MemoryModel> entries;

  const DayEntryPickerModal({
    super.key,
    required this.date,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<CalendarController>();
    final plansOnly = entries.every((e) => e.entryType == MemoryEntryType.plan);
    final count = entries.length;
    final noun = plansOnly
        ? (count == 1 ? 'PLAN' : 'PLANS')
        : (count == 1 ? 'MEMORY' : 'MEMORIES');

    return PixelModalShell(
      title: '${ZingDateUtils.shortLabel(date)} -\n$count $noun',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries) ...[
            _EntryCard(
              entry: entry,
              isMine: ctrl.isMine(entry.authorUid),
              partnerName: ctrl.partnerName,
              onTap: () => Navigator.of(context).pop(PickerResult.select(entry)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!plansOnly && !ctrl.hasOwnMemoryOn(date))
            PixelButton(
              label: '[ + ADD ANOTHER MEMORY ]',
              style: PixelButtonStyle.yellow,
              onPressed: () => Navigator.of(context).pop(const PickerResult.add()),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final MemoryModel entry;
  final bool isMine;
  final String partnerName;
  final VoidCallback onTap;

  const _EntryCard({
    required this.entry,
    required this.isMine,
    required this.partnerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.purple,
                border: Border.all(color: Colors.black, width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: entry.photoUrls.isNotEmpty
                  ? Image.network(
                      entry.photoUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        size: 16,
                        color: AppColors.gray,
                      ),
                    )
                  : const Icon(Icons.photo_camera, size: 16, color: AppColors.gray),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body
                        .copyWith(fontSize: 7, height: 1.5, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  AttributionTag(
                    label: isMine ? 'YOU' : partnerName,
                    isMine: isMine,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}