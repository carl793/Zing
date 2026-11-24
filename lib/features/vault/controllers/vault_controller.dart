import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/capsule_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../data/repositories/capsule_repository.dart';

enum VaultFilter { all, dateLocked, dualTap }

enum VaultSenderFilter { all, byYou, byPartner }

enum VaultStatusFilter { all, unlocked, locked }

/// The couple's chests: live list, filters, unlocking, and creating.
///
/// Lives in the shell rather than the Vault tab, so date chests open on time
/// whichever tab is showing.
class VaultController extends SafeNotifier {
  VaultController(this._session, this._capsules, this._storage) {
    _session.addListener(_onSession);
    // Timers stop while the phone sleeps, so check again on return.
    _lifecycle = AppLifecycleListener(onResume: checkDueUnlocks);
    _onSession();
  }

  late final AppLifecycleListener _lifecycle;
  final SessionController _session;
  final CapsuleRepository _capsules;
  final StorageService _storage;

  static const _loadError =
      'COULD NOT LOAD THE VAULT. CHECK YOUR CONNECTION AND RETRY.';
  static const _saveError = "COULDN'T SAVE. CHECK YOUR CONNECTION.";
  static const _uploadError = 'UPLOAD FAILED. CHECK YOUR CONNECTION.';
  static const _tapError = "COULDN'T TAP UNLOCK. CHECK YOUR CONNECTION.";
  static const _notLinkedError = 'NO PARTNER LINKED YET.';

  /// How long to wait for the server before calling the vault unreachable.
  static const _loadTimeout = Duration(seconds: 15);

  String get myUid => _session.uid;
  String? get coupleId => _session.coupleId;
  String get partnerName => _session.partnerName;
  bool get isPlayerOne => _session.isPlayerOne;

  // ── Live list ──────────────────────────────────────────────────────────

  List<CapsuleModel> _all = [];
  bool isLoading = true;
  String? error;

  StreamSubscription<CapsuleList>? _sub;
  Timer? _loadTimer;
  String? _watchedCouple;

  void _onSession() {
    final id = coupleId;
    if (id != null && id != _watchedCouple) {
      _watchedCouple = id;
      _watch(id);
    } else if (id == null && _session.loadFailed) {
      isLoading = false;
      error = _loadError;
    }
    notifyListeners();
  }

  void _watch(String id) {
    _sub?.cancel();
    _loadTimer?.cancel();
    isLoading = _all.isEmpty;
    error = null;
    _loadTimer = Timer(_loadTimeout, () => _fail('no answer from the server'));
    _sub = _capsules.watch(id).listen((list) {
      // An empty cached list only means nothing was stored on this phone.
      if (list.fromCache && list.capsules.isEmpty && isLoading) return;
      _all = list.capsules;
      isLoading = false;
      error = null;
      _loadTimer?.cancel();
      notifyListeners();
      _scheduleUnlock();
      if (!list.fromCache) _moveContentInside();
    }, onError: _fail);
  }

  void _fail(Object reason) {
    debugPrint('Vault load failed: $reason');
    _loadTimer?.cancel();
    isLoading = false;
    error = _loadError;
    notifyListeners();
  }

  void retry() {
    final id = coupleId;
    if (id == null) return;
    _watch(id);
    notifyListeners();
  }

  CapsuleModel? capsuleById(String id) =>
      _all.where((c) => c.capsuleId == id).firstOrNull;

  // ── Content ────────────────────────────────────────────────────────────

  /// What is inside an open chest. Throws if it can't be read.
  Future<CapsuleContent> loadContent(CapsuleModel capsule) async {
    final inline = capsule.inlineContent;
    if (inline != null) return inline;
    final id = coupleId;
    if (id == null) throw StateError(_notLinkedError);
    return _capsules.fetchContent(id, capsule.capsuleId);
  }

  final Set<String> _moved = {};

  /// Protects this player's sealed chests from older builds, once each.
  void _moveContentInside() {
    final id = coupleId;
    if (id == null) return;
    for (final chest in _all) {
      if (chest.inlineContent == null ||
          chest.status != CapsuleStatus.sealed ||
          !isMyChest(chest) ||
          !_moved.add(chest.capsuleId)) {
        continue;
      }
      // If this fails the chest is simply left as it was.
      _capsules.moveContentInside(id, chest).catchError(
          (Object e) => debugPrint('Protecting a chest failed: $e'));
    }
  }

  // ── Filters ────────────────────────────────────────────────────────────

  VaultFilter filter = VaultFilter.all;
  VaultSenderFilter senderFilter = VaultSenderFilter.all;
  VaultStatusFilter statusFilter = VaultStatusFilter.all;
  bool showArchived = false;

  Iterable<CapsuleModel> get _shelf =>
      _all.where((c) => c.isArchived == showArchived);

  int get totalCount => _shelf.length;

  /// True when there is nothing at all on this shelf, filters aside.
  bool get isEmpty => totalCount == 0;

  bool get hasFilters =>
      filter != VaultFilter.all ||
      senderFilter != VaultSenderFilter.all ||
      statusFilter != VaultStatusFilter.all;

  List<CapsuleModel> get capsules => _shelf.where((c) {
        final typeOk = switch (filter) {
          VaultFilter.all => true,
          VaultFilter.dateLocked =>
            c.triggerMode == CapsuleTriggerMode.dateRelease,
          VaultFilter.dualTap =>
            c.triggerMode == CapsuleTriggerMode.dualTapSync,
        };
        final senderOk = switch (senderFilter) {
          VaultSenderFilter.all => true,
          VaultSenderFilter.byYou => isMyChest(c),
          VaultSenderFilter.byPartner => !isMyChest(c),
        };
        final statusOk = switch (statusFilter) {
          VaultStatusFilter.all => true,
          VaultStatusFilter.unlocked => c.status == CapsuleStatus.unlocked,
          VaultStatusFilter.locked => c.status == CapsuleStatus.sealed,
        };
        return typeOk && senderOk && statusOk;
      }).toList();

  void setFilter(VaultFilter value) {
    filter = value;
    notifyListeners();
  }

  void setSenderFilter(VaultSenderFilter value) {
    senderFilter = value;
    notifyListeners();
  }

  void setStatusFilter(VaultStatusFilter value) {
    statusFilter = value;
    notifyListeners();
  }

  void setShowArchived(bool value) {
    showArchived = value;
    notifyListeners();
  }

  // ── Date unlocks ───────────────────────────────────────────────────────

  Timer? _unlockTimer;
  final Set<String> _unlocking = {};

  /// Opens every chest whose date has come, then sleeps until the next one.
  void _scheduleUnlock() {
    _unlockTimer?.cancel();
    if (isDisposed) return;
    final now = DateTime.now();
    DateTime? next;
    for (final chest in _all) {
      final date = chest.unlockDate;
      if (date == null ||
          chest.status != CapsuleStatus.sealed ||
          chest.triggerMode != CapsuleTriggerMode.dateRelease) {
        continue;
      }
      if (!date.isAfter(now)) {
        _unlock(chest.capsuleId);
      } else if (next == null || date.isBefore(next)) {
        next = date;
      }
    }
    if (next == null) return;
    // Long timers drift while the phone sleeps, so check in hourly.
    final wait = next.difference(now);
    const maxWait = Duration(hours: 1);
    _unlockTimer = Timer(wait < maxWait ? wait : maxWait, _scheduleUnlock);
  }

  Future<void> _unlock(String id) async {
    final couple = coupleId;
    if (couple == null || !_unlocking.add(id)) return;
    try {
      await _capsules.unlock(couple, id);
    } catch (e) {
      debugPrint('Unlocking $id failed: $e');
      // Wait before trying again, e.g. while the phone's clock is ahead.
      await Future<void>.delayed(const Duration(seconds: 30));
      _unlocking.remove(id);
      _scheduleUnlock();
      return;
    }
    _unlocking.remove(id);
  }

  /// Rechecks now, e.g. when a countdown on screen reaches zero.
  void checkDueUnlocks() => _scheduleUnlock();

  // ── Actions ── each returns null on success, or a message to show.

  Future<String?> createCapsule({
    required CapsuleTriggerMode trigger,
    required String title,
    required String secretNote,
    DateTime? unlockDate,
    Uint8List? photo,
    String? voiceNotePath,
  }) async {
    final id = coupleId;
    if (id == null) return _notLinkedError;

    final String? photoUrl;
    final String? voiceUrl;
    try {
      final uploads = await Future.wait<String?>([
        photo == null ? Future.value() : _storage.uploadPhoto(photo),
        voiceNotePath == null
            ? Future.value()
            : _storage.uploadVoiceNote(voiceNotePath),
      ]);
      photoUrl = uploads[0];
      voiceUrl = uploads[1];
    } catch (e) {
      debugPrint('Chest upload failed: $e');
      return _uploadError;
    }

    final isDate = trigger == CapsuleTriggerMode.dateRelease;
    return _run(
      (couple) => _capsules.create(
        couple,
        CapsuleModel(
          capsuleId: _capsules.newId(couple),
          creatorUid: myUid,
          title: title,
          triggerMode: trigger,
          unlockDate: isDate ? unlockDate : null,
          dualTapState: isDate ? null : DualTapState(),
          createdAt: DateTime.now(),
        ),
        CapsuleContent(
          secretNote: secretNote,
          photoUrl: photoUrl,
          voiceNoteUrl: voiceUrl,
        ),
      ),
    );
  }

  Future<String?> tapUnlock(CapsuleModel capsule) => _run(
        (id) => _capsules.tap(id, capsule.capsuleId, isPlayerOne: isPlayerOne),
        error: _tapError,
      );

  Future<String?> cancelCapsule(CapsuleModel capsule) async {
    if (!isMyChest(capsule)) return 'YOU CAN ONLY CANCEL YOUR OWN CHESTS.';
    return _run((id) => _capsules.cancel(id, capsule.capsuleId));
  }

  Future<String?> setArchived(CapsuleModel capsule, bool archived) =>
      _run((id) => _capsules.setArchived(id, capsule.capsuleId, archived));

  Future<String?> _run(
    Future<void> Function(String coupleId) action, {
    String error = _saveError,
  }) async {
    final id = coupleId;
    if (id == null) return _notLinkedError;
    try {
      await action(id);
      return null;
    } catch (e) {
      debugPrint('Vault action failed: $e');
      return error;
    }
  }

  // ── Labels ─────────────────────────────────────────────────────────────

  bool isMyChest(CapsuleModel capsule) => capsule.creatorUid == myUid;

  String creatorLabel(CapsuleModel capsule) =>
      isMyChest(capsule) ? 'YOU' : partnerName;

  String recipientLabel(CapsuleModel capsule) =>
      isMyChest(capsule) ? partnerName : 'YOU';

  bool myTapDone(CapsuleModel capsule) =>
      _tapOf(capsule, playerOne: isPlayerOne) != null;

  bool partnerTapDone(CapsuleModel capsule) =>
      _tapOf(capsule, playerOne: !isPlayerOne) != null;

  DateTime? _tapOf(CapsuleModel capsule, {required bool playerOne}) {
    final taps = capsule.dualTapState;
    return playerOne ? taps?.p1TappedAt : taps?.p2TappedAt;
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _lifecycle.dispose();
    _sub?.cancel();
    _unlockTimer?.cancel();
    _loadTimer?.cancel();
    super.dispose();
  }
}
