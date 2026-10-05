import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/couple_model.dart';
import '../models/capsule_model.dart';

enum JoinRoomResult { success, notFound, expired, alreadyLinked, selfJoin, error }

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- Generic primitives ----------

  DocumentReference<Map<String, dynamic>> doc(String path) => _db.doc(path);

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDoc(String path) =>
      _db.doc(path).snapshots();

  Future<void> setDoc(String path, Map<String, dynamic> data,
          {bool merge = true}) =>
      _db.doc(path).set(data, SetOptions(merge: merge));

  Future<void> updateDoc(String path, Map<String, dynamic> data) =>
      _db.doc(path).update(data);

  Future<void> deleteDoc(String path) => _db.doc(path).delete();

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String path, {
    List<(String field, dynamic value)> whereEquals = const [],
    (String field, DateTime start, DateTime end)? whereDateRange,
    String? orderBy,
  }) {
    Query<Map<String, dynamic>> q = _db.collection(path);
    for (final (field, value) in whereEquals) {
      q = q.where(field, isEqualTo: value);
    }
    if (whereDateRange != null) {
      final (field, start, end) = whereDateRange;
      q = q
          .where(field,
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where(field, isLessThan: Timestamp.fromDate(end));
    }
    if (orderBy != null) q = q.orderBy(orderBy);
    return q.snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addToCollection(
          String path, Map<String, dynamic> data) =>
      _db.collection(path).add(data);

  // ---------- Pairing: room creation + atomic join ----------

  String _generateCode() =>
      (Random().nextInt(900000) + 100000).toString();

  Future<String> createRoom(String creatorUid) async {
    for (int attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final ref = _db.collection('rooms').doc(code);
      final existing = await ref.get();
      if (existing.exists &&
          !RoomModel.fromMap(code, existing.data()!).isExpired) continue;

      await ref.set({
        'createdByUid': creatorUid,
        'status': RoomStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24))),
      });
      return code;
    }
    throw Exception('Could not generate a unique room code — try again.');
  }

  Stream<RoomModel?> streamRoom(String code) =>
      _db.collection('rooms').doc(code).snapshots().map(
            (snap) =>
                snap.exists ? RoomModel.fromMap(code, snap.data()!) : null,
          );

  Future<void> cancelRoom(String code) => _db
      .collection('rooms')
      .doc(code)
      .update({'status': RoomStatus.cancelled.name});

  Future<JoinRoomResult> joinRoom(
      {required String code, required String joinerUid}) async {
    final roomRef = _db.collection('rooms').doc(code);

    try {
      return await _db.runTransaction<JoinRoomResult>((tx) async {
        final roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) return JoinRoomResult.notFound;

        final room = RoomModel.fromMap(code, roomSnap.data()!);
        if (room.createdByUid == joinerUid) return JoinRoomResult.selfJoin;
        if (room.status == RoomStatus.linked) return JoinRoomResult.alreadyLinked;
        if (room.status != RoomStatus.pending || room.isExpired) {
          return JoinRoomResult.expired;
        }

        final coupleRef = _db.collection('couples').doc();
        tx.set(coupleRef, {
          'memberUids': [room.createdByUid, joinerUid],
          'pairingCode': code,
          'status': 'active',
          'linkedAt': FieldValue.serverTimestamp(),
          'unitPref': 'km',
          'reunionQuest': {
            'status': 'none',
            'destination': null,
            'targetDate': null,
            'proposedByUid': null,
            'notes': null,
          },
          'settings': {
            'chiptuneFx': true,
            'bgm': false,
            'reunionAlerts': true,
          },
        });

        tx.update(roomRef, {
          'status': RoomStatus.linked.name,
          'coupleId': coupleRef.id,
        });

        // Only the joining account's own document is written from this client:
        // Firestore rules only let an account write itself, so writing the
        // partner's document here rejected the whole transaction and the UI
        // reported it as "no connection". The creator claims the same couple id
        // from the room instead — see claimCoupleId / recoverCoupleId.
        tx.set(
          _db.collection('users').doc(joinerUid),
          {'coupleId': coupleRef.id},
          SetOptions(merge: true),
        );

        return JoinRoomResult.success;
      });
    } catch (e, stack) {
      final reason = e is FirebaseException ? ' [${e.code}]' : '';
      debugPrint('══════════════════════════════');
      debugPrint('joinRoom FAILED$reason');
      debugPrint('Code attempted: $code');
      debugPrint('Joiner UID: $joinerUid');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      debugPrint('══════════════════════════════');
      return JoinRoomResult.error;
    }
  }

  // ---------- Pairing: claiming your own link ----------

  /// Writes [coupleId] to the caller's own user document. Merging means this
  /// never fails on a missing document, and it is safe to call more than once.
  Future<void> claimCoupleId({required String uid, required String coupleId}) =>
      setDoc('users/$uid', {'coupleId': coupleId});

  /// Returns the couple [uid] is linked to, or null while still unpaired.
  ///
  /// A link is only ever written by the account that performed it, so an
  /// account that was signed out while its partner joined has no `coupleId` of
  /// its own yet. The room it created carries the id, so the link is claimed
  /// here. Never throws: routing must not break if the lookup fails.
  Future<String?> recoverCoupleId(String uid) async {
    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      final stored = userSnap.data()?['coupleId'] as String?;
      if (stored != null && stored.isNotEmpty) return stored;

      final rooms = await _db
          .collection('rooms')
          .where('createdByUid', isEqualTo: uid)
          .limit(10)
          .get();

      for (final room in rooms.docs) {
        final data = room.data();
        if (data['status'] != RoomStatus.linked.name) continue;
        final coupleId = data['coupleId'] as String?;
        if (coupleId == null || coupleId.isEmpty) continue;
        await claimCoupleId(uid: uid, coupleId: coupleId);
        return coupleId;
      }
      return null;
    } catch (e) {
      debugPrint('recoverCoupleId failed for $uid: $e');
      return null;
    }
  }

  // ---------- Couples: unlink ----------

  Future<void> unlinkCouple(String coupleId) async {
    final coupleRef = _db.collection('couples').doc(coupleId);
    final snap = await coupleRef.get();
    if (!snap.exists) return;
    final couple = CoupleModel.fromMap(coupleId, snap.data()!);

    final batch = _db.batch();
    batch.update(coupleRef, {'status': CoupleStatus.unlinked.name});
    for (final uid in couple.memberUids) {
      batch.update(_db.collection('users').doc(uid), {'coupleId': null});
    }
    await batch.commit();
  }

  // ---------- Capsules: atomic dual-tap unlock ----------

  Future<void> tapCapsuleUnlock({
    required String coupleId,
    required String capsuleId,
    required String uid,
    required bool isPlayerOne,
  }) async {
    final ref = _db
        .collection('couples')
        .doc(coupleId)
        .collection('capsules')
        .doc(capsuleId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final capsule = CapsuleModel.fromMap(capsuleId, snap.data()!);
      if (capsule.status != CapsuleStatus.sealed) return;

      final now = Timestamp.now();
      final field =
          isPlayerOne ? 'dualTapState.p1TappedAt' : 'dualTapState.p2TappedAt';
      tx.update(ref, {field: now});

      final otherAlreadyTapped = isPlayerOne
          ? capsule.dualTapState?.p2TappedAt != null
          : capsule.dualTapState?.p1TappedAt != null;
      if (otherAlreadyTapped) {
        tx.update(ref, {
          'status': CapsuleStatus.unlocked.name,
          'openedAt': now,
        });
      }
    });
  }
}