import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_loader.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../data/repositories/memory_repository.dart';
import '../../shell/shell_tabs.dart';
import '../controllers/calendar_controller.dart';
import '../modals/add_memory_modal.dart';
import '../modals/day_entry_picker_modal.dart';
import '../modals/month_year_picker_modal.dart';
import '../modals/plan_day_modal.dart';
import '../modals/view_memory_modal.dart';
import '../widgets/day_cell.dart';
import '../widgets/entry_card.dart';
import '../widgets/month_nav_bar.dart';
import '../widgets/month_stats.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CalendarController(
        ctx.read<SessionController>(),
        ctx.read<MemoryRepository>(),
        ctx.read<StorageService>(),
      ),
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  ShellTabs? _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = context.read<ShellTabs?>()?..addListener(_onTabs);
    _onTabs();
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabs);
    super.dispose();
  }

  /// The home screen's LOG MEMORY button starts here.
  void _onTabs() {
    if (!(_tabs?.take(ShellAction.logToday) ?? false)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _logToday(context.read<CalendarController>());
    });
  }

  void _logToday(CalendarController ctrl) =>
      _openDay(context, ctrl, ZingDateUtils.today());

  void _onSwipe(CalendarController ctrl, DragEndDetails details) {
    final speed = details.primaryVelocity ?? 0;
    if (speed.abs() < 200) return;
    AudioService.instance.playSfx(AppSfx.tick);
    speed < 0 ? ctrl.nextMonth() : ctrl.previousMonth();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CalendarController>();
    final entries = ctrl.monthEntries;

    return SafeArea(
      bottom: false,
      child: PixelColumn(
        child: Column(
          children: [
            PixelScreenTitle(
              title: 'CALENDAR',
              icon: PixelIcons.calendar,
              tone: PixelTone.coral,
              trailing: ctrl.isCurrentMonth
                  ? null
                  : SizedBox(
                      width: 84,
                      child: PixelButton(
                        label: 'TODAY',
                        style: PixelButtonStyle.neutral,
                        small: true,
                        sfx: AppSfx.tick,
                        onPressed: ctrl.goToToday,
                      ),
                    ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg + 4, AppSpacing.lg),
                children: [
                  MonthNavBar(
                    month: ctrl.displayedMonth,
                    onPrevious: ctrl.previousMonth,
                    onNext: ctrl.nextMonth,
                    onLabelTap: () => _openMonthPicker(context, ctrl),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (ctrl.loadFailed) ...[
                    const PixelNote.error(
                      "Couldn't load your calendar. Check your internet.",
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PixelButton(
                      label: 'RETRY',
                      icon: PixelIcons.refresh,
                      style: PixelButtonStyle.neutral,
                      small: true,
                      onPressed: ctrl.retry,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  GestureDetector(
                    onHorizontalDragEnd: (d) => _onSwipe(ctrl, d),
                    child: _CalendarGrid(
                      controller: ctrl,
                      onDayTap: (date) => _openDay(context, ctrl, date),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  MonthStats(
                    daysTogether: ctrl.daysTogetherThisMonth,
                    daysSince: ctrl.daysSinceLastMeetup,
                    daysUntil: ctrl.daysUntilNextMeetup,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PixelLabel(
                    '${ZingDateUtils.monthName(ctrl.displayedMonth.month)} LOG',
                    trailing: entries.isEmpty ? null : '${entries.length}',
                  ),
                  if (entries.isEmpty && !ctrl.isLoading)
                    const PixelNote(
                      'Nothing here yet. Tap a day to log a memory, or a day '
                      'ahead to plan it.',
                    ),
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: EntryCard(
                        entry: entry,
                        isMine: ctrl.isMine(entry.authorUid),
                        partnerName: ctrl.partnerName,
                        showDate: true,
                        onTap: () => _openEntry(context, ctrl, entry),
                      ),
                    ),
                ],
              ),
            ),
            PixelActionBar(
              child: PixelButton(
                label: 'LOG TODAY',
                icon: PixelIcons.heart,
                style: PixelButtonStyle.coral,
                onPressed: () => _logToday(ctrl),
              ),
            ),
          ],
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
    final today = ZingDateUtils.today();
    final blanks = ZingDateUtils.leadingBlanks(month.year, month.month);
    final days = ZingDateUtils.daysInMonth(month.year, month.month);

    return PixelPanel(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          SizedBox(
            height: 26,
            child: Row(
              children: [
                for (final day in _weekdays)
                  Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label.copyWith(letterSpacing: 0),
                    ),
                  ),
              ],
            ),
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.92,
            children: List.generate(blanks + days, (i) {
              if (i < blanks) return const SizedBox.shrink();
              final number = i - blanks + 1;
              final date = ZingDateUtils.day(month.year, month.month, number);
              final visual = controller.visualFor(date);
              return DayCell(
                dayNumber: number,
                visual: visual,
                isToday: date == today,
                entryCount: visual == DayVisual.memory
                    ? controller.memoriesOn(date).length
                    : controller.plansOn(date).length,
                onTap: () => onDayTap(date),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 24,
            child: controller.isLoading
                ? const Center(child: PixelLoader(size: 5))
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        _Legend(DayVisual.memory, 'MET UP'),
                        SizedBox(width: AppSpacing.lg),
                        _Legend(DayVisual.planned, 'PLAN'),
                        SizedBox(width: AppSpacing.lg),
                        _Legend(DayVisual.nextVisit, 'NEXT VISIT'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final DayVisual visual;
  final String label;
  const _Legend(this.visual, this.label);

  @override
  Widget build(BuildContext context) {
    final (tone, icon, mark) = DayCell.styleOf(visual);
    return Row(
      children: [
        PixelIcon(
          icon!,
          color: visual == DayVisual.planned ? mark : tone!.face,
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Modal flows (sequential: a modal returns a result, then the next opens)
// ─────────────────────────────────────────────

Future<T?> _showSheet<T>(
  BuildContext context,
  CalendarController ctrl,
  Widget child, {
  bool isForm = false,
}) {
  return showPixelSheet<T>(
    context: context,
    isForm: isForm,
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

Future<void> _openAdd(
  BuildContext context,
  CalendarController ctrl,
  DateTime date, {
  MemoryModel? existing,
}) =>
    _showSheet<void>(
      context,
      ctrl,
      AddMemoryModal(date: date, existing: existing),
      isForm: true,
    );

Future<void> _openPlan(
  BuildContext context,
  CalendarController ctrl,
  DateTime date, {
  MemoryModel? existing,
}) =>
    _showSheet<void>(
      context,
      ctrl,
      PlanDayModal(date: date, existing: existing),
      isForm: true,
    );

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
      await _openPlan(context, ctrl, date, existing: plans.firstOrNull);
    }
    return;
  }

  if (memories.isEmpty) {
    final ownPlan = plans.where((p) => p.authorUid == ctrl.myUid).firstOrNull;
    await _openAdd(context, ctrl, date, existing: ownPlan);
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
    await _openAdd(context, ctrl, date);
    return;
  }

  final entry = result.selected;
  if (entry != null) await _openEntry(context, ctrl, entry);
}

/// Opens one entry. An own plan whose day has come is logged as a memory.
Future<void> _openEntry(
  BuildContext context,
  CalendarController ctrl,
  MemoryModel entry,
) async {
  final date = ZingDateUtils.fromStored(entry.date);
  if (entry.entryType == MemoryEntryType.memory) {
    await _openMemory(context, ctrl, entry);
  } else if (date.isAfter(ZingDateUtils.today()) || !ctrl.isMine(entry.authorUid)) {
    await _openPlan(context, ctrl, date, existing: entry);
  } else {
    await _openAdd(context, ctrl, date, existing: entry);
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
    await _openAdd(
      context,
      ctrl,
      ZingDateUtils.fromStored(memory.date),
      existing: memory,
    );
  }
}
