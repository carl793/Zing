import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  List<CapsuleModel> _sealedCapsules = [];
  List<CapsuleModel> _unlockedCapsules = [];
  VaultFilter filter = VaultFilter.all;
  bool isLoading = true;
  String? error;

  // ── Create form transient state ──
  CapsuleTriggerMode draftTrigger = CapsuleTriggerMode.dateRelease;
  Uint8List? draftPhotoBytes;
  String? draftVoiceNotePath;
  bool isRecording = false;
  bool isSaving = false;
  String? saveError;

  StreamSubscription? _capsuleSub;
  final AudioRecorder _recorder = AudioRecorder();
  bool _disposed = false;

  static const _saveErr = "COULDN'T SAVE. CHECK YOUR CONNECTION.";
  static const _photoErr = 'PHOTO UPLOAD FAILED. CHECK YOUR CONNECTION.';
  static const _voiceErr = 'VOICE UPLOAD FAILED. CHECK YOUR CONNECTION.';

  // ─────────────────────────────────────────────
  // Filtered list
  // ─────────────────────────────────────────────

  List<CapsuleModel> get capsules {
    return switch (filter) {
      VaultFilter.all => _allCapsules,
      VaultFilter.dateLocked => _allCapsules
          .where((c) => c.triggerMode == CapsuleTriggerMode.dateRelease)
          .toList(),
      VaultFilter.dualTap => _allCapsules
          .where((c) => c.triggerMode == CapsuleTriggerMode.dualTapSync)
          .toList(),
    };
  }

  /// Total capsule count across every filter.
  int get totalCount => _allCapsules.length;

  /// True when this couple has no capsules at all.
  bool get isEmpty => _allCapsules.isEmpty;

  void setFilter(VaultFilter f) {
    filter = f;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  Future<void> init() async {
    try {
      final mySnap = await _fs.doc('users/$myUid').get();
      if (!mySnap.exists) {
        isLoading = false;
        notifyListeners();
        return;
      }
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
      isPlayerOne = couple.memberUids.isNotEmpty &&
          couple.memberUids.first == myUid;

      if (partnerUid.isNotEmpty) {
        final pSnap = await _fs.doc('users/$partnerUid').get();
        if (pSnap.exists) {
          final n = UserModel.fromMap(partnerUid, pSnap.data()!).displayName;
          if (n.isNotEmpty) partnerName = n.toUpperCase();
        }
      }

      _subscribeCapsules();
      // Auto-unlock date-based chests that have passed their date.
      _scheduleAutoUnlockCheck();
    } catch (e) {
      debugPrint('VaultController.init error: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  /// Rebuilds the display list from the two per-status subscriptions so
  /// neither stream clobbers the other's capsules.
  void _mergeCapsules() {
    _allCapsules = [..._sealedCapsules, ..._unlockedCapsules]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _subscribeCapsules() {
    if (coupleId == null) return;
    _capsuleSub?.cancel();
    isLoading = true;
    notifyListeners();

    _capsuleSub = _fs
        .streamCollection(
          'couples/$coupleId/capsules',
          orderBy: 'createdAt',
          whereEquals: [
            ('status', CapsuleStatus.sealed.name),
          ],
        )
        .listen(
      (snap) {
        _sealedCapsules =
            snap.docs.map((d) => CapsuleModel.fromMap(d.id, d.data())).toList();
        _mergeCapsules();
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Vault stream error: $e');
        isLoading = false;
        notifyListeners();
      },
    );

    // Separate subscription for unlocked capsules
    _fs
        .streamCollection(
          'couples/$coupleId/capsules',
          whereEquals: [('status', CapsuleStatus.unlocked.name)],
          orderBy: 'createdAt',
        )
        .listen(
      (snap) {
        _unlockedCapsules =
            snap.docs.map((d) => CapsuleModel.fromMap(d.id, d.data())).toList();
        _mergeCapsules();
        notifyListeners();
      },
      onError: (e) => debugPrint('Vault unlocked stream error: $e'),
    );
  }

  /// Checks if any sealed date-release capsule has passed its unlock date
  /// and flips it to "unlocked" in Firestore.
  void _scheduleAutoUnlockCheck() {
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      await _checkAutoUnlock();
    });
    _checkAutoUnlock();
  }

  Future<void> _checkAutoUnlock() async {
    if (coupleId == null) return;
    final now = DateTime.now();
    for (final capsule in List.of(_allCapsules)) {
      if (capsule.triggerMode == CapsuleTriggerMode.dateRelease &&
          capsule.status == CapsuleStatus.sealed &&
          capsule.unlockDate != null &&
          capsule.unlockDate!.isBefore(now)) {
        try {
          await _fs.updateDoc(
            'couples/$coupleId/capsules/${capsule.capsuleId}',
            {'status': CapsuleStatus.unlocked.name, 'openedAt': now},
          );
        } catch (e) {
          debugPrint('Auto-unlock failed for ${capsule.capsuleId}: $e');
        }
      }
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _capsuleSub?.cancel();
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