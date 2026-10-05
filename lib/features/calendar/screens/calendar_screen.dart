import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../controllers/calendar_controller.dart';
import '../modals/add_memory_modal.dart';
import '../modals/day_entry_picker_modal.dart';
import '../modals/month_year_picker_modal.dart';
import '../modals/plan_day_modal.dart';
import '../modals/view_memory_modal.dart';
import '../widgets/day_cell.dart';
import '../widgets/month_nav_bar.dart';
import '../widgets/recap_stats_card.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser!.uid;
    return ChangeNotifierProvider(
      create: (ctx) => CalendarController(
        ctx.read<FirestoreService>(),
        ctx.read<StorageService>(),
        myUid: uid,
      )..init(),
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CalendarController>();

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'VIRTUAL CALENDAR',
                textAlign: TextAlign.center,
                style: AppTextStyles.header.copyWith(
                  fontSize: 17,
                  shadows: const [
                    Shadow(color: Color(0xFF003A44), offset: Offset(3, 3), blurRadius: 0),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              MonthNavBar(
                month: ctrl.displayedMonth,
                onPrevious: ctrl.previousMonth,
                onNext: ctrl.nextMonth,
                onLabelTap: () => _openMonthPicker(context, ctrl),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CalendarGrid(
                controller: ctrl,
                onDayTap: (date) => _openDay(context, ctrl, date),
              ),
              const SizedBox(height: AppSpacing.lg),
              RecapStatsCard(
                daysTogether: ctrl.daysTogetherThisMonth,
                daysSinceLastMeetup: ctrl.daysSinceLastMeetup,
                nextMeetupDate: ctrl.nextMeetupDate,
                daysUntilNextMeetup: ctrl.daysUntilNextMeetup,
              ),
              const SizedBox(height: AppSpacing.lg),
              PixelButton(
                label: '[HIGHLIGHT DAY TOGETHER]',
                onPressed: () => _openDay(context, ctrl, ZingDateUtils.today()),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Calendar grid
// ─────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  static const List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  final CalendarController controller;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({required this.controller, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final month = controller.displayedMonth;
    final blanks = ZingDateUtils.leadingBlanks(month.year, month.month);
    final days = ZingDateUtils.daysInMonth(month.year, month.month);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          if (controller.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.yellow,
                backgroundColor: AppColors.purple,
              ),
            ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6,
            childAspectRatio: 2.4,
            children: _weekdays
                .map((d) => Center(
                      child: Text(
                        d,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.cyan, fontSize: 8),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: List.generate(blanks + days, (i) {
              if (i < blanks) return const SizedBox.shrink();
              final dayNumber = i - blanks + 1;
              final date = ZingDateUtils.day(month.year, month.month, dayNumber);
              return DayCell(
                dayNumber: dayNumber,
                visual: controller.visualFor(date),
                label: controller.cellLabel(date),
                entryCount: controller.memoriesOn(date).length,
                onTap: () => onDayTap(date),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Modal flows (sequential: a modal returns a result, then the next opens)
// ─────────────────────────────────────────────

Future<T?> _showSheet<T>(
  BuildContext context,
  CalendarController ctrl,
  Widget child,
) {
  return showPixelSheet<T>(
    context: context,
    builder: (_) => ChangeNotifierProvider<CalendarController>.value(
      value: ctrl,
      child: child,
    ),
  );
}

Future<void> _openMonthPicker(BuildContext context, CalendarController ctrl) async {
  final picked = await _showSheet<DateTime>(
    context,
    ctrl,
    MonthYearPickerModal(initial: ctrl.displayedMonth),
  );
  if (picked != null) ctrl.jumpTo(picked.year, picked.month);
}

/// Routes a tapped day to the right modal:
///   future day            → plan (create / edit / picker if several)
///   past or today, empty  → log a memory (converts your own plan if present)
///   own entry only        → open it directly
///   partner / both        → picker (so each partner can open or add theirs)
Future<void> _openDay(
  BuildContext context,
  CalendarController ctrl,
  DateTime date,
) async {
  if (ctrl.coupleId == null) return;

  final isFuture = date.isAfter(ZingDateUtils.today());
  final memories = ctrl.memoriesOn(date);
  final plans = ctrl.plansOn(date);

  if (isFuture) {
    if (plans.length > 1) {
      await _openPicker(context, ctrl, date, plans);
    } else {
      await _showSheet(
        context,
        ctrl,
        PlanDayModal(date: date, existing: plans.firstOrNull),
      );
    }
    return;
  }

  if (memories.isEmpty) {
    final ownPlan = plans.where((p) => p.authorUid == ctrl.myUid).firstOrNull;
    await _showSheet(context, ctrl, AddMemoryModal(date: date, existing: ownPlan));
    return;
  }

  if (memories.length == 1 && ctrl.hasOwnMemoryOn(date)) {
    await _openMemory(context, ctrl, memories.first);
    return;
  }

  await _openPicker(context, ctrl, date, memories);
}

Future<void> _openPicker(
  BuildContext context,
  CalendarController ctrl,
  DateTime date,
  List<MemoryModel> entries,
) async {
  final result = await _showSheet<PickerResult>(
    context,
    ctrl,
    DayEntryPickerModal(date: date, entries: entries),
  );
  if (result == null || !context.mounted) return;

  if (result.addRequested) {
    await _showSheet(context, ctrl, AddMemoryModal(date: date));
    return;
  }

  final entry = result.selected;
  if (entry == null) return;

  if (entry.entryType == MemoryEntryType.plan) {
    await _showSheet(
      context,
      ctrl,
      PlanDayModal(date: ZingDateUtils.fromStored(entry.date), existing: entry),
    );
  } else {
    await _openMemory(context, ctrl, entry);
  }
}

Future<void> _openMemory(
  BuildContext context,
  CalendarController ctrl,
  MemoryModel memory,
) async {
  final action = await _showSheet<ViewMemoryAction>(
    context,
    ctrl,
    ViewMemoryModal(memory: memory),
  );
  if (action == ViewMemoryAction.edit && context.mounted) {
    await _showSheet(
      context,
      ctrl,
      AddMemoryModal(date: ZingDateUtils.fromStored(memory.date), existing: memory),
    );
  }
}