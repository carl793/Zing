import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/models/couple_model.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../data/repositories/memory_repository.dart';

/// Visual state of a single calendar tile.
enum DayVisual { normal, today, memory, planned, unloggedPlan, nextVisit }

/// Calendar state: the displayed month, its entries grouped per day, recap
/// stats, and every create/update/delete/comment operation.
class CalendarController extends SafeNotifier {
  CalendarController(this._session, this._memories, this._storage) {
    _session.addListener(_onSession);
    _onSession();
  }

  static const int maxPhotos = 4;

  static const String _saveError =
      "COULDN'T SAVE. CHECK YOUR CONNECTION AND TRY AGAIN.";
  static const String _photoError =
      'PHOTO UPLOAD FAILED. CHECK YOUR CONNECTION AND TRY AGAIN.';
  static const String _notOwnerError = 'YOU CAN ONLY CHANGE YOUR OWN ENTRIES.';
  static const String _notLinkedError = 'NO PARTNER LINKED YET.';

  final SessionController _session;
  final MemoryRepository _memories;
  final StorageService _storage;

  String get myUid => _session.uid;
  String? get coupleId => _session.coupleId;
  String get partnerName => _session.partnerName;

  DateTime displayedMonth = _currentMonth();
  bool isLoading = true;

  /// True when the displayed year couldn't be loaded.
  bool loadFailed = false;

  // Entries per "yyyy-MM-dd". The year covers month browsing without a new
  // query; the latest few give "last met up" and today's entries while
  // another year is on screen.
  Map<String, List<MemoryModel>> _yearByDay = {};
  Map<String, List<MemoryModel>> _latestByDay = {};
  DateTime? _lastMetUp;

  StreamSubscription<List<MemoryModel>>? _yearSub;
  StreamSubscription<List<MemoryModel>>? _latestSub;
  String? _watchedCouple;
  int? _watchedYear;

  static DateTime _currentMonth() {
    final today = ZingDateUtils.today();
    return DateTime.utc(today.year, today.month);
  }

  void _onSession() {
    final id = coupleId;
    if (id != null && id != _watchedCouple) {
      _watchedCouple = id;
      _watchYear();
      _watchLatest(id);
    }
    if (id == null && _session.loadFailed) loadFailed = true;
    notifyListeners();
  }

  // ── Streams ────────────────────────────────────────────────────────────

  void _watchYear() {
    final id = coupleId;
    if (id == null) return;
    final year = displayedMonth.year;
    if (year != _watchedYear) _yearByDay = {};
    _watchedYear = year;
    _yearSub?.cancel();
    isLoading = true;
    loadFailed = false;
    _yearSub = _memories.watchYear(id, year).listen(
      (entries) {
        _yearByDay = _group(entries);
        isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('Calendar year stream error: $e');
        isLoading = false;
        loadFailed = true;
        notifyListeners();
      },
    );
  }

  void _watchLatest(String id) {
    _latestSub?.cancel();
    final today = ZingDateUtils.today();
    _latestSub = _memories.watchLatest(id, today).listen(
      (entries) {
        _latestByDay = _group(entries);
        _lastMetUp = entries
            .where((e) => e.entryType == MemoryEntryType.memory)
            .map((e) => ZingDateUtils.fromStored(e.date))
            .fold<DateTime?>(
              null,
              (latest, d) => latest == null || d.isAfter(latest) ? d : latest,
            );
        notifyListeners();
      },
      onError: (Object e) => debugPrint('Calendar latest stream error: $e'),
    );
  }

  /// Tries again after [loadFailed].
  void retry() {
    _watchYear();
    final id = coupleId;
    if (id != null) _watchLatest(id);
    notifyListeners();
  }

  Map<String, List<MemoryModel>> _group(Iterable<MemoryModel> items) {
    final map = <String, List<MemoryModel>>{};
    for (final memory in items) {
      map.putIfAbsent(ZingDateUtils.isoDate(memory.date), () => []).add(memory);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        if (a.authorUid == b.authorUid) {
          return a.createdAt.compareTo(b.createdAt);
        }
        return a.authorUid == myUid ? -1 : 1; // own entry first
      });
    }
    return map;
  }

  // ── Month navigation ───────────────────────────────────────────────────

  void previousMonth() =>
      _setMonth(DateTime.utc(displayedMonth.year, displayedMonth.month - 1));

  void nextMonth() =>
      _setMonth(DateTime.utc(displayedMonth.year, displayedMonth.month + 1));

  void jumpTo(int year, int month) => _setMonth(DateTime.utc(year, month));

  void _setMonth(DateTime month) {
    displayedMonth = month;
    if (month.year != _watchedYear) _watchYear();
    notifyListeners();
  }

  // ── Read helpers used by the UI ────────────────────────────────────────

  List<MemoryModel> entriesFor(DateTime date) {
    final key = ZingDateUtils.isoDate(date);
    return (date.year == _watchedYear ? _yearByDay[key] : _latestByDay[key]) ??
        const [];
  }

  List<MemoryModel> memoriesOn(DateTime date) => entriesFor(date)
      .where((e) => e.entryType == MemoryEntryType.memory)
      .toList();

  List<MemoryModel> plansOn(DateTime date) => entriesFor(date)
      .where((e) => e.entryType == MemoryEntryType.plan)
      .toList();

  bool hasOwnMemoryOn(DateTime date) =>
      memoriesOn(date).any((e) => e.authorUid == myUid);

  bool isMine(String uid) => uid == myUid;

  String nameFor(String uid) => uid == myUid ? 'YOU' : partnerName;

  DateTime? get nextMeetupDate {
    final quest = _session.couple?.reunionQuest;
    final target = quest?.targetDate;
    if (quest?.status != ReunionQuestStatus.accepted || target == null) {
      return null;
    }
    return ZingDateUtils.fromLocal(target);
  }

  DayVisual visualFor(DateTime date) {
    final today = ZingDateUtils.today();
    final entries = entriesFor(date);
    if (entries.any((e) => e.entryType == MemoryEntryType.memory)) {
      return DayVisual.memory;
    }
    if (nextMeetupDate == date && !date.isBefore(today)) {
      return DayVisual.nextVisit;
    }
    if (entries.isNotEmpty) {
      return date.isBefore(today) ? DayVisual.unloggedPlan : DayVisual.planned;
    }
    return date == today ? DayVisual.today : DayVisual.normal;
  }

  /// Tag shown under the day number on memory tiles.
  String? cellLabel(DateTime date) {
    final memories = memoriesOn(date);
    if (memories.isEmpty) return null;
    final tag = memories.first.tagCategory;
    return tag.isEmpty ? null : tag;
  }

  int get daysTogetherThisMonth {
    final month = ZingDateUtils.isoDate(displayedMonth).substring(0, 7);
    return _yearByDay.entries
        .where((day) =>
            day.key.startsWith(month) &&
            day.value.any((e) => e.entryType == MemoryEntryType.memory))
        .length;
  }

  int? get daysSinceLastMeetup {
    final last = _lastMetUp;
    return last == null
        ? null
        : ZingDateUtils.daysBetween(last, ZingDateUtils.today());
  }

  int? get daysUntilNextMeetup {
    final next = nextMeetupDate;
    if (next == null) return null;
    final days = ZingDateUtils.daysBetween(ZingDateUtils.today(), next);
    return days < 0 ? null : days;
  }

  // ── Writes ── each returns null on success, or a message to show.

  LocationPin? _pin(String name) {
    final trimmed = name.trim();
    // lat/lng are placeholders until place search is added.
    return trimmed.isEmpty ? null : LocationPin(name: trimmed, lat: 0, lng: 0);
  }

  Future<String?> createMemory({
    required DateTime date,
    required String title,
    required String story,
    required String tag,
    required String locationName,
    required List<Uint8List> photos,
  }) =>
      _write((id) async {
        final urls = await _upload(photos);
        await _memories.create(
          id,
          MemoryModel(
            memoryId: _memories.newId(id),
            authorUid: myUid,
            date: date,
            entryType: MemoryEntryType.memory,
            title: title,
            story: story,
            tagCategory: tag,
            locationPin: _pin(locationName),
            photoUrls: urls,
            createdAt: DateTime.now(),
          ),
        );
      });

  /// Edits an own memory, or converts an own plan into a memory.
  Future<String?> updateMemory({
    required MemoryModel original,
    required String title,
    required String story,
    required String tag,
    required String locationName,
    required List<String> keptPhotoUrls,
    required List<Uint8List> newPhotos,
  }) =>
      _write(
        (id) async => _memories.updateContent(
          id,
          original.memoryId,
          type: MemoryEntryType.memory,
          title: title,
          story: story,
          tag: tag,
          pin: _pin(locationName),
          photoUrls: [...keptPhotoUrls, ...await _upload(newPhotos)],
        ),
        owner: original.authorUid,
      );

  /// Creates a plan for a future day, or edits one of your own plans.
  Future<String?> savePlan({
    required DateTime date,
    required String title,
    required String notes,
    required String tag,
    MemoryModel? existing,
  }) =>
      _write(
        (id) => existing == null
            ? _memories.create(
                id,
                MemoryModel(
                  memoryId: _memories.newId(id),
                  authorUid: myUid,
                  date: date,
                  entryType: MemoryEntryType.plan,
                  title: title,
                  story: notes,
                  tagCategory: tag,
                  createdAt: DateTime.now(),
                ),
              )
            : _memories.updateContent(
                id,
                existing.memoryId,
                type: MemoryEntryType.plan,
                title: title,
                story: notes,
                tag: tag,
              ),
        owner: existing?.authorUid,
      );

  Future<String?> deleteMemory(MemoryModel memory) => _write(
        (id) => _memories.delete(id, memory.memoryId),
        owner: memory.authorUid,
      );

  Stream<List<CommentModel>> streamComments(String memoryId) {
    final id = coupleId;
    return id == null
        ? const Stream.empty()
        : _memories.watchComments(id, memoryId);
  }

  Future<String?> addComment(MemoryModel memory, String text) async {
    if (memory.authorUid == myUid) {
      return 'ONLY YOUR PARTNER CAN COMMENT ON YOUR ENTRY.';
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return _write((id) => _memories.addComment(
          id,
          memory.memoryId,
          authorUid: myUid,
          text: trimmed,
        ));
  }

  Future<List<String>> _upload(List<Uint8List> photos) async {
    if (photos.isEmpty) return const [];
    try {
      return await _storage.uploadPhotos(photos);
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      throw const _UploadFailed();
    }
  }

  /// Runs a write for the linked couple. [owner] must be this player.
  Future<String?> _write(
    Future<void> Function(String coupleId) action, {
    String? owner,
  }) async {
    final id = coupleId;
    if (id == null) return _notLinkedError;
    if (owner != null && owner != myUid) return _notOwnerError;
    try {
      await action(id);
      return null;
    } on _UploadFailed {
      return _photoError;
    } catch (e) {
      debugPrint('Calendar write failed: $e');
      return _saveError;
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _yearSub?.cancel();
    _latestSub?.cancel();
    super.dispose();
  }
}

class _UploadFailed implements Exception {
  const _UploadFailed();
}
