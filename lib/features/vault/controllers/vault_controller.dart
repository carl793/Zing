import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/models/couple_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';

enum VaultFilter { all, dateLocked, dualTap }
enum VaultSenderFilter { all, byYou, byPartner }
enum VaultStatusFilter { all, unlocked, locked }

class VaultController extends ChangeNotifier {
  VaultController(this._fs, this._storage, {required this.myUid});

  final FirestoreService _fs;
  final StorageService _storage;
  final String myUid;

  // ── Identity ──
  String? coupleId;
  String partnerUid = '';
  String partnerName = 'PARTNER';
  bool isPlayerOne = false; // index 0 in memberUids

  // ── State ──
  List<CapsuleModel> _allCapsules = [];
  VaultFilter filter = VaultFilter.all;
  VaultSenderFilter senderFilter = VaultSenderFilter.all;
  VaultStatusFilter statusFilter = VaultStatusFilter.all;
  bool showArchived = false;
  bool isLoading = true;
  String? error;

  // ── Create form transient state ──
  CapsuleTriggerMode draftTrigger = CapsuleTriggerMode.dateRelease;
  Uint8List? draftPhotoBytes;
  String? draftVoiceNotePath;
  bool isRecording = false;
  bool isSaving = false;
  String? saveError;

  StreamSubscription? _sealedCapsuleSub;
  StreamSubscription? _unlockedCapsuleSub;
  StreamSubscription? _partnerProfileSub;
  final Map<String, CapsuleModel> _sealedCapsules = {};
  final Map<String, CapsuleModel> _unlockedCapsules = {};
  // A document changing status is removed from one filtered query before the
  // other query is guaranteed to deliver it. Keep its last known value visible
  // until a direct read or the destination query confirms the new status.
  final Map<String, CapsuleModel> _pendingCapsuleTransitions = {};
  final Set<String> _resolvingCapsuleTransitions = {};
  bool _sealedSnapshotReceived = false;
  bool _unlockedSnapshotReceived = false;
  bool _sealedStreamFailed = false;
  bool _unlockedStreamFailed = false;
  bool _initialLoadExpired = false;
  final List<String> _streamErrors = [];
  Timer? _unlockTimer;
  Timer? _initialLoadTimeout;
  final Set<String> _unlockingCapsuleIds = {};
  final AudioRecorder _recorder = AudioRecorder();
  bool _disposed = false;

  static const _saveErr = "COULDN'T SAVE. CHECK YOUR CONNECTION.";
  static const _photoErr = 'PHOTO UPLOAD FAILED. CHECK YOUR CONNECTION.';
  static const _voiceErr = 'VOICE UPLOAD FAILED. CHECK YOUR CONNECTION.';

  // ─────────────────────────────────────────────
  // Filtered list
  // ─────────────────────────────────────────────

  List<CapsuleModel> get capsules {
    return _allCapsules.where((c) {
      if (c.status == CapsuleStatus.cancelled || c.isArchived != showArchived) return false;
      if (filter == VaultFilter.dateLocked && c.triggerMode != CapsuleTriggerMode.dateRelease) return false;
      if (filter == VaultFilter.dualTap && c.triggerMode != CapsuleTriggerMode.dualTapSync) return false;
      if (senderFilter == VaultSenderFilter.byYou && c.creatorUid != myUid) return false;
      if (senderFilter == VaultSenderFilter.byPartner && c.creatorUid != partnerUid) return false;
      if (statusFilter == VaultStatusFilter.unlocked && c.status != CapsuleStatus.unlocked) return false;
      if (statusFilter == VaultStatusFilter.locked && c.status != CapsuleStatus.sealed) return false;
      return true;
    }).toList();
  }

  /// Total capsule count across every filter.
  int get totalCount => _allCapsules.where((c) => c.status != CapsuleStatus.cancelled && c.isArchived == showArchived).length;

  /// True when this couple has no capsules at all.
  bool get isEmpty => totalCount == 0;
  CapsuleModel? capsuleById(String id) { for (final c in _allCapsules) { if (c.capsuleId == id) return c; } return null; }
  Future<void> refreshDueUnlocks() => _checkAutoUnlock();

  void setFilter(VaultFilter f) {
    filter = f;
    notifyListeners();
  }

  void setSenderFilter(VaultSenderFilter f) { senderFilter = f; notifyListeners(); }
  void setStatusFilter(VaultStatusFilter f) { statusFilter = f; notifyListeners(); }
  void setShowArchived(bool value) { showArchived = value; notifyListeners(); }

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  Future<void> init() async {
    _sealedCapsuleSub?.cancel();
    _unlockedCapsuleSub?.cancel();
    _initialLoadTimeout?.cancel();
    _initialLoadExpired = false;
    _sealedStreamFailed = false;
    _unlockedStreamFailed = false;
    _streamErrors.clear();
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final mySnap = await _fs
          .doc('users/$myUid')
          .get()
          .timeout(const Duration(seconds: 12));
      if (!mySnap.exists) {
        isLoading = false;
        error = 'YOUR ACCOUNT COULD NOT BE FOUND.';
        notifyListeners();
        return;
      }
      final me = UserModel.fromMap(myUid, mySnap.data()!);
      coupleId = me.coupleId;
      if (coupleId == null || coupleId!.isEmpty) {
        coupleId = await _fs.recoverCoupleId(myUid);
      }
      if (coupleId == null) {
        isLoading = false;
        notifyListeners();
        return;
      }

      final coupleSnap = await _fs
          .doc('couples/$coupleId')
          .get()
          .timeout(const Duration(seconds: 12));
      if (!coupleSnap.exists || coupleSnap.data() == null) {
        isLoading = false;
        error = 'YOUR LINKED COUPLE COULD NOT BE FOUND.';
        notifyListeners();
        return;
      }
      final couple = CoupleModel.fromMap(coupleId!, coupleSnap.data()!);
      partnerUid = couple.partnerUid(myUid);
      isPlayerOne = couple.memberUids.isNotEmpty &&
          couple.memberUids.first == myUid;

      // The chest stream should not wait for this nonessential profile read.
      _subscribeCapsules();
      _scheduleAutoUnlockCheck();
      if (partnerUid.isNotEmpty) {
        _subscribePartnerProfile(partnerUid);
      }
    } catch (e) {
      debugPrint('VaultController.init error: $e');
      isLoading = false;
      error = _vaultErrorMessage(e);
      notifyListeners();
    }
  }

  void _subscribePartnerProfile(String uid) {
    _partnerProfileSub?.cancel();
    _partnerProfileSub = _fs.streamDoc('users/$uid').listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final name = UserModel.fromMap(uid, snap.data()!).displayName;
      if (name.isNotEmpty && !_disposed) {
        partnerName = name.toUpperCase();
        notifyListeners();
      }
    }, onError: (Object e) => debugPrint('Vault partner profile stream error: $e'));
  }

  Future<void> retry() => init();

  void _subscribeCapsules() {
    if (coupleId == null) return;
    _sealedCapsuleSub?.cancel();
    _unlockedCapsuleSub?.cancel();
    _partnerProfileSub?.cancel();
    _sealedCapsules.clear();
    _unlockedCapsules.clear();
    _pendingCapsuleTransitions.clear();
    _resolvingCapsuleTransitions.clear();
    _sealedSnapshotReceived = false;
    _unlockedSnapshotReceived = false;
    _sealedStreamFailed = false;
    _unlockedStreamFailed = false;
    _initialLoadExpired = false;
    _streamErrors.clear();
    isLoading = true;
    notifyListeners();

    _initialLoadTimeout = Timer(const Duration(seconds: 15), () {
      if (_disposed || !isLoading) return;
      if (_sealedSnapshotReceived || _unlockedSnapshotReceived) {
        if (!_sealedSnapshotReceived) _sealedStreamFailed = true;
        if (!_unlockedSnapshotReceived) _unlockedStreamFailed = true;
        _mergeCapsuleSnapshots();
        return;
      }
      _initialLoadExpired = true;
      isLoading = false;
      error = 'THE VAULT DID NOT RETURN CHESTS. TAP RETRY.';
      if (_streamErrors.isNotEmpty) {
        error = '$error ${_streamErrors.join(' ')}';
      }
      notifyListeners();
    });

    // Keep the status constraints used by the vault's existing Firestore
    // access path. An unrestricted collection read can be rejected by rules
    // that allow only sealed and unlocked capsule documents.
    _sealedCapsuleSub = _fs
        .streamCollection(
          'couples/$coupleId/capsules',
          whereEquals: [('status', CapsuleStatus.sealed.name)],
        )
        .listen(
      (snap) {
        final incoming = <String, CapsuleModel>{
          for (final d in snap.docs) d.id: CapsuleModel.fromMap(d.id, d.data()),
        };
        final removed = _sealedCapsules.entries
            .where((entry) => !incoming.containsKey(entry.key))
            .toList(growable: false);
        _sealedCapsules
          ..clear()
          ..addAll(incoming);
        for (final entry in removed) {
          if (!_unlockedCapsules.containsKey(entry.key)) {
            _pendingCapsuleTransitions.putIfAbsent(entry.key, () => entry.value);
            _resolveCapsuleTransition(entry.key);
          }
        }
        _sealedSnapshotReceived = true;
        _mergeCapsuleSnapshots();
      },
      onError: (Object e) => _handleCapsuleStreamError(e, sealed: true),
    );

    _unlockedCapsuleSub = _fs
        .streamCollection(
          'couples/$coupleId/capsules',
          whereEquals: [('status', CapsuleStatus.unlocked.name)],
        )
        .listen(
      (snap) {
        _unlockedCapsules
          ..clear()
          ..addEntries(snap.docs.map((d) => MapEntry(
                d.id,
                CapsuleModel.fromMap(d.id, d.data()),
              )));
        for (final id in _unlockedCapsules.keys) {
          _pendingCapsuleTransitions.remove(id);
        }
        _unlockedSnapshotReceived = true;
        _mergeCapsuleSnapshots();
      },
      onError: (Object e) => _handleCapsuleStreamError(e, sealed: false),
    );
  }

  void _mergeCapsuleSnapshots() {
    _allCapsules = [
      ..._pendingCapsuleTransitions.values,
      ..._sealedCapsules.values,
      ..._unlockedCapsules.values,
    ]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final sealedSettled = _sealedSnapshotReceived || _sealedStreamFailed;
    final unlockedSettled = _unlockedSnapshotReceived || _unlockedStreamFailed;
    final allSettled = sealedSettled && unlockedSettled;
    final hasAnySnapshot = _sealedSnapshotReceived || _unlockedSnapshotReceived;
    isLoading = !allSettled && !_initialLoadExpired;
    if (allSettled) {
      _initialLoadTimeout?.cancel();
      error = hasAnySnapshot
          ? null
          : 'COULD NOT LOAD THE VAULT. CHECK YOUR CONNECTION AND RETRY.';
      if (!hasAnySnapshot && _streamErrors.isNotEmpty) {
        error = '$error ${_streamErrors.join(' ')}';
      }
    } else if (hasAnySnapshot) {
      // Keep usable chests visible while the other status stream is pending.
      error = null;
    }
    notifyListeners();
    _checkAutoUnlock();
  }

  void _handleCapsuleStreamError(Object e, {required bool sealed}) {
    debugPrint('Vault stream error: $e');
    _streamErrors.add(_vaultErrorMessage(e));
    if (sealed) {
      _sealedStreamFailed = true;
    } else {
      _unlockedStreamFailed = true;
    }
    _mergeCapsuleSnapshots();
  }

  String _vaultErrorMessage(Object error) {
    if (error is FirebaseException) {
      return 'FIRESTORE ${error.code}: ${error.message ?? 'UNKNOWN ERROR'}';
    }
    return error.toString();
  }

  /// Checks if any sealed date-release capsule has passed its unlock date
  /// and flips it to "unlocked" in Firestore.
  void _scheduleAutoUnlockCheck() {
    _unlockTimer?.cancel();
    _unlockTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAutoUnlock());
    _checkAutoUnlock();
  }

  Future<void> _checkAutoUnlock() async {
    if (coupleId == null) return;
    for (final id in List<String>.of(_pendingCapsuleTransitions.keys)) {
      _resolveCapsuleTransition(id);
    }
    final now = DateTime.now();
    for (final capsule in List.of(_allCapsules)) {
      if (capsule.triggerMode == CapsuleTriggerMode.dateRelease &&
          capsule.status == CapsuleStatus.sealed &&
          capsule.unlockDate != null &&
          !capsule.unlockDate!.isAfter(now) &&
          _unlockingCapsuleIds.add(capsule.capsuleId)) {
        try {
          await _fs.updateDoc(
            'couples/$coupleId/capsules/${capsule.capsuleId}',
            {'status': CapsuleStatus.unlocked.name, 'openedAt': now},
          );
        } catch (e) {
          debugPrint('Auto-unlock failed for ${capsule.capsuleId}: $e');
        } finally {
          _unlockingCapsuleIds.remove(capsule.capsuleId);
        }
      }
    }
  }

  Future<void> _resolveCapsuleTransition(String capsuleId) async {
    final path = coupleId;
    if (path == null ||
        !_pendingCapsuleTransitions.containsKey(capsuleId) ||
        !_resolvingCapsuleTransitions.add(capsuleId)) {
      return;
    }
    try {
      final snapshot = await _fs
          .doc('couples/$path/capsules/$capsuleId')
          .get()
          .timeout(const Duration(seconds: 8));
      // A listener may have delivered the new status during the read.
      if (_unlockedCapsules.containsKey(capsuleId)) {
        _pendingCapsuleTransitions.remove(capsuleId);
      } else if (!snapshot.exists || snapshot.data() == null) {
        _pendingCapsuleTransitions.remove(capsuleId);
      } else {
        final current = CapsuleModel.fromMap(capsuleId, snapshot.data()!);
        _pendingCapsuleTransitions.remove(capsuleId);
        switch (current.status) {
          case CapsuleStatus.sealed:
            _sealedCapsules[capsuleId] = current;
            break;
          case CapsuleStatus.unlocked:
            _unlockedCapsules[capsuleId] = current;
            break;
          case CapsuleStatus.cancelled:
            _sealedCapsules.remove(capsuleId);
            _unlockedCapsules.remove(capsuleId);
            break;
        }
      }
    } catch (e) {
      // Keep the last known chest in the combined list and retry on the next
      // unlock tick. A transient read failure must not make it disappear.
      debugPrint('Vault transition refresh failed for $capsuleId: $e');
    } finally {
      _resolvingCapsuleTransitions.remove(capsuleId);
      _mergeCapsuleSnapshots();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sealedCapsuleSub?.cancel();
    _unlockedCapsuleSub?.cancel();
    _partnerProfileSub?.cancel();
    _unlockTimer?.cancel();
    _initialLoadTimeout?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Create chest helpers (used by CreateCapsuleModal)
  // ─────────────────────────────────────────────

  void setDraftTrigger(CapsuleTriggerMode mode) {
    draftTrigger = mode;
    notifyListeners();
  }

  Future<void> pickChestPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file == null) return;
      draftPhotoBytes = await file.readAsBytes();
      notifyListeners();
    } catch (e) {
      debugPrint('Photo pick error: $e');
    }
  }

  void clearChestPhoto() {
    draftPhotoBytes = null;
    notifyListeners();
  }

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    isRecording = true;
    notifyListeners();
  }

  Future<void> stopRecording() async {
    final path = await _recorder.stop();
    isRecording = false;
    draftVoiceNotePath = path;
    notifyListeners();
  }

  void clearVoiceNote() {
    draftVoiceNotePath = null;
    isRecording = false;
    notifyListeners();
  }

  /// Called by the modal's Save button.
  Future<String?> createCapsule({
    required String title,
    required String secretNote,
    DateTime? unlockDate,
  }) async {
    if (coupleId == null) return 'NO PARTNER LINKED YET.';
    if (title.trim().isEmpty) return 'GIVE YOUR CHEST A NAME.';
    if (draftTrigger == CapsuleTriggerMode.dateRelease && unlockDate == null) {
      return 'SET AN UNLOCK DATE.';
    }

    isSaving = true;
    saveError = null;
    notifyListeners();

    try {
      final capsuleId =
          '${myUid}_${DateTime.now().millisecondsSinceEpoch}';

      // Upload photo if present
      String? photoUrl;
      if (draftPhotoBytes != null) {
        try {
          photoUrl = await _storage.uploadChestPhoto(
            coupleId: coupleId!,
            capsuleId: capsuleId,
            bytes: draftPhotoBytes!,
          );
        } catch (e) {
          debugPrint('Chest photo upload failed: $e');
          isSaving = false;
          notifyListeners();
          return _photoErr;
        }
      }

      // Upload voice note if present
      String? voiceUrl;
      if (draftVoiceNotePath != null) {
        try {
          voiceUrl = await _storage.uploadVoiceNote(
            coupleId: coupleId!,
            capsuleId: capsuleId,
            filePath: draftVoiceNotePath!,
          );
        } catch (e) {
          debugPrint('Voice upload failed: $e');
          isSaving = false;
          notifyListeners();
          return _voiceErr;
        }
      }

      final capsule = CapsuleModel(
        capsuleId: capsuleId,
        creatorUid: myUid,
        title: title.trim(),
        triggerMode: draftTrigger,
        unlockDate: unlockDate,
        dualTapState: draftTrigger == CapsuleTriggerMode.dualTapSync
            ? DualTapState()
            : null,
        secretNote: secretNote.trim(),
        photoUrl: photoUrl,
        voiceNoteUrl: voiceUrl,
        status: CapsuleStatus.sealed,
        createdAt: DateTime.now(),
      );

      await _fs.setDoc(
        'couples/$coupleId/capsules/$capsuleId',
        capsule.toMap(),
        merge: false,
      );

      // Reset draft state
      draftPhotoBytes = null;
      draftVoiceNotePath = null;
      draftTrigger = CapsuleTriggerMode.dateRelease;
      isSaving = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('createCapsule failed: $e');
      isSaving = false;
      notifyListeners();
      return _saveErr;
    }
  }

  // ─────────────────────────────────────────────
  // Dual-tap unlock
  // ─────────────────────────────────────────────

  Future<String?> tapUnlock(CapsuleModel capsule) async {
    if (coupleId == null) return 'NO PARTNER LINKED YET.';
    try {
      await _fs.tapCapsuleUnlock(
        coupleId: coupleId!,
        capsuleId: capsule.capsuleId,
        uid: myUid,
        isPlayerOne: isPlayerOne,
      );
      return null;
    } catch (e) {
      debugPrint('tapUnlock failed: $e');
      return "COULDN'T TAP UNLOCK. TRY AGAIN.";
    }
  }

  // ─────────────────────────────────────────────
  // Cancel chest (creator only)
  // ─────────────────────────────────────────────

  Future<String?> cancelCapsule(CapsuleModel capsule) async {
    if (coupleId == null) return 'NO PARTNER LINKED YET.';
    if (capsule.creatorUid != myUid) {
      return 'YOU CAN ONLY CANCEL YOUR OWN CHESTS.';
    }
    try {
      await _fs.updateDoc(
        'couples/$coupleId/capsules/${capsule.capsuleId}',
        {'status': CapsuleStatus.cancelled.name},
      );
      return null;
    } catch (e) {
      debugPrint('cancelCapsule failed: $e');
      return _saveErr;
    }
  }

  Future<String?> setArchived(CapsuleModel capsule, bool archived) async {
    if (coupleId == null) return 'NO PARTNER LINKED YET.';
    try {
      await _fs.updateDoc('couples/$coupleId/capsules/${capsule.capsuleId}', {'isArchived': archived});
      return null;
    } catch (e) {
      debugPrint('archive capsule failed: $e');
      return _saveErr;
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  bool isMyChest(CapsuleModel capsule) => capsule.creatorUid == myUid;

  String creatorLabel(CapsuleModel capsule) =>
      capsule.creatorUid == myUid ? 'YOU' : partnerName;

  String recipientLabel(CapsuleModel capsule) =>
      capsule.creatorUid == myUid ? partnerName : 'YOU';

  bool myTapDone(CapsuleModel capsule) {
    final dt = capsule.dualTapState;
    if (dt == null) return false;
    return isPlayerOne ? dt.p1TappedAt != null : dt.p2TappedAt != null;
  }

  bool partnerTapDone(CapsuleModel capsule) {
    final dt = capsule.dualTapState;
    if (dt == null) return false;
    return isPlayerOne ? dt.p2TappedAt != null : dt.p1TappedAt != null;
  }
}
