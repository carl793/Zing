import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/comment_model.dart';
import '../../../core/models/couple_model.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/date_utils.dart';

/// Visual state of a single calendar tile.
enum DayVisual { normal, today, memory, planned, unloggedPlan, nextVisit }

/// Owns calendar state: the displayed month, its memories/plans (grouped per
/// day), recap stats, and every create/update/delete/comment operation.
///
/// Firestore paths (see firebase schema):
///   couples/{coupleId}/memories/{memoryId}
///   couples/{coupleId}/memories/{memoryId}/comments/{commentId}
class CalendarController extends ChangeNotifier {
  CalendarController(this._fs, this._storage, {required this.myUid});

  static const int maxPhotos = 4;

  static const String _saveError =
      "COULDN'T SAVE. CHECK YOUR CONNECTION AND TRY AGAIN.";
  static const String _photoError =
      'PHOTO UPLOAD FAILED. CHECK YOUR CONNECTION AND TRY AGAIN.';
  static const String _notOwnerError = 'YOU CAN ONLY CHANGE YOUR OWN ENTRIES.';
  static const String _notLinkedError = 'NO PARTNER LINKED YET.';

  final FirestoreService _fs;
  final StorageService _storage;
  final String myUid;

  // ── Identity ──
  String? coupleId;
  String partnerUid = '';
  String partnerName = 'PARTNER';

  // ── View state ──
  DateTime displayedMonth = _currentMonth();
  bool isLoading = true;
  DateTime? nextMeetupDate;

  Map<String, List<MemoryModel>> _monthByDay = {};
  Map<String, List<MemoryModel>> _recentByDay = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _monthSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _recentSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _coupleSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partnerProfileSub;
  bool _disposed = false;

  static DateTime _currentMonth() {
    final today = ZingDateUtils.today();
    return DateTime.utc(today.year, today.month, 1);
  }

  String get _memoriesPath => 'couples/$coupleId/memories';

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  Future<void> init() async {
    try {
      final mySnap = await _fs.doc('users/$myUid').get();
      final me = UserModel.fromMap(myUid, mySnap.data()!);
      coupleId = me.coupleId;

      if (coupleId == null) {
        isLoading = false;
        notifyListeners();
        return;
      }

      final coupleSnap = await _fs.doc('couples/$coupleId').get();
      final couple = CoupleModel.fromMap(coupleId!, coupleSnap.data()!);
      partnerUid = couple.partnerUid(myUid);

      if (partnerUid.isNotEmpty) {
        _partnerProfileSub = _fs.streamDoc('users/$partnerUid').listen((snap) {
          if (!snap.exists || snap.data() == null) return;
          final name = UserModel.fromMap(partnerUid, snap.data()!).displayName;
          if (name.isNotEmpty) {
            partnerName = name.toUpperCase();
            notifyListeners();
          }
        });
      }

      _coupleSub = _fs.streamDoc('couples/$coupleId').listen((snap) {
        if (!snap.exists) return;
        final quest = CoupleModel.fromMap(snap.id, snap.data()!).reunionQuest;
        nextMeetupDate =
            (quest.status == ReunionQuestStatus.accepted &&
                    quest.targetDate != null)
                ? ZingDateUtils.fromLocal(quest.targetDate!)
                : null;
        notifyListeners();
      });

      _subscribeMonth();
      _subscribeRecent();
    } catch (e) {
      debugPrint('CalendarController.init failed: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _monthSub?.cancel();
    _recentSub?.cancel();
    _coupleSub?.cancel();
    _partnerProfileSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Streams
  // ─────────────────────────────────────────────

  void _subscribeMonth() {
    if (coupleId == null) return;
    _monthSub?.cancel();
    isLoading = true;
    notifyListeners();

    final start = DateTime.utc(displayedMonth.year, displayedMonth.month, 1);
    final end = DateTime.utc(displayedMonth.year, displayedMonth.month + 1, 1);

    _monthSub = _fs
        .streamCollection(_memoriesPath, whereDateRange: ('date', start, end))
        .listen(
      (snap) {
        _monthByDay = _group(
          snap.docs.map((d) => MemoryModel.fromMap(d.id, d.data())),
        );
        isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('Calendar month stream error: $e');
        isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Rolling window (last ~400 days) used for "last met up" and for resolving
  /// today's entries when another month is on screen.
  void _subscribeRecent() {
    if (coupleId == null) return;
    _recentSub?.cancel();

    final today = ZingDateUtils.today();
    final start = today.subtract(const Duration(days: 400));
    final end = today.add(const Duration(days: 1));

    _recentSub = _fs
        .streamCollection(_memoriesPath, whereDateRange: ('date', start, end))
        .listen(
      (snap) {
        _recentByDay = _group(
          snap.docs.map((d) => MemoryModel.fromMap(d.id, d.data())),
        );
        notifyListeners();
      },
      onError: (Object e) => debugPrint('Calendar recent stream error: $e'),
    );
  }

  Map<String, List<MemoryModel>> _group(Iterable<MemoryModel> items) {
    final map = <String, List<MemoryModel>>{};
    for (final memory in items) {
      map.putIfAbsent(ZingDateUtils.isoDate(memory.date), () => []).add(memory);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        if (a.authorUid == b.authorUid) return a.createdAt.compareTo(b.createdAt);
        return a.authorUid == myUid ? -1 : 1; // own entry first
      });
    }
    return map;
  }

  // ─────────────────────────────────────────────
  // Month navigation
  // ─────────────────────────────────────────────

  void previousMonth() => _setMonth(
        DateTime.utc(displayedMonth.year, displayedMonth.month - 1, 1),
      );

  void nextMonth() => _setMonth(
        DateTime.utc(displayedMonth.year, displayedMonth.month + 1, 1),
      );

  void jumpTo(int year, int month) => _setMonth(DateTime.utc(year, month, 1));

  void _setMonth(DateTime month) {
    displayedMonth = month;
    _subscribeMonth();
  }

  // ─────────────────────────────────────────────
  // Read helpers used by the UI
  // ─────────────────────────────────────────────

  List<MemoryModel> entriesFor(DateTime date) {
    final key = ZingDateUtils.isoDate(date);
    return _monthByDay[key] ?? _recentByDay[key] ?? const [];
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

  DayVisual visualFor(DateTime date) {
    final today = ZingDateUtils.today();
    final isToday = date == today;
    final isFuture = date.isAfter(today);

    if (memoriesOn(date).isNotEmpty) return DayVisual.memory;

    final isNextVisit =
        nextMeetupDate != null && nextMeetupDate == date && !date.isBefore(today);
    if (isNextVisit) return DayVisual.nextVisit;

    if (plansOn(date).isNotEmpty) {
      return (isFuture || isToday) ? DayVisual.planned : DayVisual.unloggedPlan;
    }

    return isToday ? DayVisual.today : DayVisual.normal;
  }

  /// Tag shown under the day number on memory tiles.
  String? cellLabel(DateTime date) {
    final memories = memoriesOn(date);
    if (memories.isEmpty) return null;
    final tag = memories.first.tagCategory;
    return tag.isEmpty ? null : tag;
  }

  // ── Recap stats ──

  int get daysTogetherThisMonth => _monthByDay.values
      .where((list) => list.any((e) => e.entryType == MemoryEntryType.memory))
      .length;

  int? get daysSinceLastMeetup {
    final today = ZingDateUtils.today();
    DateTime? latest;
    for (final list in _recentByDay.values) {
      for (final memory in list) {
        if (memory.entryType != MemoryEntryType.memory) continue;
        final day = ZingDateUtils.fromStored(memory.date);
        if (day.isAfter(today)) continue;
        if (latest == null || day.isAfter(latest)) latest = day;
      }
    }
    return latest == null ? null : ZingDateUtils.daysBetween(latest, today);
  }

  int? get daysUntilNextMeetup {
    if (nextMeetupDate == null) return null;
    final diff = ZingDateUtils.daysBetween(ZingDateUtils.today(), nextMeetupDate!);
    return diff < 0 ? null : diff;
  }

  // ─────────────────────────────────────────────
  // Writes — each returns null on success, or a user-facing error message
  // ─────────────────────────────────────────────

  LocationPin? _pin(String name) {
    final trimmed = name.trim();
    // lat/lng are placeholders until place search/geocoding is added.
    return trimmed.isEmpty ? null : LocationPin(name: trimmed, lat: 0, lng: 0);
  }

  Future<String?> createMemory({
    required DateTime date,
    required String title,
    required String story,
    required String tag,
    required String locationName,
    required List<Uint8List> photos,
  }) async {
    if (coupleId == null) return _notLinkedError;

    List<String> urls = const [];
    try {
      final memoryId = '${myUid}_${DateTime.now().millisecondsSinceEpoch}';

      if (photos.isNotEmpty) {
        try {
          urls = await _storage.uploadMemoryPhotos(
            coupleId: coupleId!,
            memoryId: memoryId,
            photos: photos,
          );
        } catch (e) {
          debugPrint('Photo upload failed: $e');
          return _photoError;
        }
      }

      final memory = MemoryModel(
        memoryId: memoryId,
        authorUid: myUid,
        date: date,
        entryType: MemoryEntryType.memory,
        title: title,
        story: story,
        tagCategory: tag,
        locationPin: _pin(locationName),
        photoUrls: urls,
        createdAt: DateTime.now(),
      );

      await _fs.setDoc('$_memoriesPath/$memoryId', memory.toMap(), merge: false);
      return null;
    } catch (e) {
      debugPrint('createMemory failed: $e');
      await _storage.deletePhotosByUrl(urls);
      return _saveError;
    }
  }

  /// Edits an own memory, or converts an own plan into a memory.
  Future<String?> updateMemory({
    required MemoryModel original,
    required String title,
    required String story,
    required String tag,
    required String locationName,
    required List<String> keptPhotoUrls,
    required List<Uint8List> newPhotos,
  }) async {
    if (coupleId == null) return _notLinkedError;
    if (original.authorUid != myUid) return _notOwnerError;

    List<String> newUrls = const [];
    try {
      if (newPhotos.isNotEmpty) {
        try {
          newUrls = await _storage.uploadMemoryPhotos(
            coupleId: coupleId!,
            memoryId: original.memoryId,
            photos: newPhotos,
          );
        } catch (e) {
          debugPrint('Photo upload failed: $e');
          return _photoError;
        }
      }

      final pin = _pin(locationName);
      await _fs.updateDoc('$_memoriesPath/${original.memoryId}', {
        'entryType': MemoryEntryType.memory.name,
        'title': title,
        'story': story,
        'tagCategory': tag,
        'locationPin': pin?.toMap() ?? FieldValue.delete(),
        'photoUrls': [...keptPhotoUrls, ...newUrls],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final removed =
          original.photoUrls.where((url) => !keptPhotoUrls.contains(url));
      await _storage.deletePhotosByUrl(removed);
      return null;
    } catch (e) {
      debugPrint('updateMemory failed: $e');
      await _storage.deletePhotosByUrl(newUrls);
      return _saveError;
    }
  }

  /// Creates a plan for a future day, or edits one of your own plans.
  Future<String?> savePlan({
    required DateTime date,
    required String title,
    required String notes,
    required String tag,
    MemoryModel? existing,
  }) async {
    if (coupleId == null) return _notLinkedError;
    if (existing != null && existing.authorUid != myUid) return _notOwnerError;

    try {
      if (existing == null) {
        final planId = '${myUid}_${DateTime.now().millisecondsSinceEpoch}';
        final plan = MemoryModel(
          memoryId: planId,
          authorUid: myUid,
          date: date,
          entryType: MemoryEntryType.plan,
          title: title,
          story: notes,
          tagCategory: tag,
          createdAt: DateTime.now(),
        );
        await _fs.setDoc('$_memoriesPath/$planId', plan.toMap(), merge: false);
      } else {
        await _fs.updateDoc('$_memoriesPath/${existing.memoryId}', {
          'title': title,
          'story': notes,
          'tagCategory': tag,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return null;
    } catch (e) {
      debugPrint('savePlan failed: $e');
      return _saveError;
    }
  }

  Future<String?> deleteMemory(MemoryModel memory) async {
    if (coupleId == null) return _notLinkedError;
    if (memory.authorUid != myUid) return _notOwnerError;

    try {
      await _fs.deleteDoc('$_memoriesPath/${memory.memoryId}');
      await _storage.deletePhotosByUrl(memory.photoUrls);
      return null;
    } catch (e) {
      debugPrint('deleteMemory failed: $e');
      return _saveError;
    }
  }

  // ─────────────────────────────────────────────
  // Comments
  // ─────────────────────────────────────────────

  Stream<List<CommentModel>> streamComments(String memoryId) {
    return _fs
        .streamCollection('$_memoriesPath/$memoryId/comments',
            orderBy: 'createdAt')
        .map((snap) =>
            snap.docs.map((d) => CommentModel.fromMap(d.id, d.data())).toList());
  }

  Future<String?> addComment(MemoryModel memory, String text) async {
    if (coupleId == null) return _notLinkedError;
    if (memory.authorUid == myUid) {
      return 'ONLY YOUR PARTNER CAN COMMENT ON YOUR ENTRY.';
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    try {
      final comment = CommentModel(
        commentId: '',
        authorUid: myUid,
        text: trimmed,
        createdAt: DateTime.now(),
      );
      await _fs.addToCollection(
        '$_memoriesPath/${memory.memoryId}/comments',
        comment.toMap(),
      );
      return null;
    } catch (e) {
      debugPrint('addComment failed: $e');
      return "COULDN'T SEND COMMENT. TRY AGAIN.";
    }
  }
}
