import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/calendar_controller.dart';
import '../widgets/entry_card.dart';

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
    final canAdd = !plansOnly && !ctrl.hasOwnMemoryOn(date);

    return PixelModalShell(
      title: ZingDateUtils.shortLabel(date),
      icon: PixelIcons.calendar,
      footer: !canAdd
          ? null
          : PixelButton(
              label: 'ADD YOUR SIDE',
              icon: PixelIcons.plus,
              style: PixelButtonStyle.coral,
              onPressed: () =>
                  Navigator.of(context).pop(const PickerResult.add()),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            EntryCard(
              entry: entry,
              isMine: ctrl.isMine(entry.authorUid),
              partnerName: ctrl.partnerName,
              onTap: () =>
                  Navigator.of(context).pop(PickerResult.select(entry)),
            ),
          ],
        ],
      ),
    );
  }
}
