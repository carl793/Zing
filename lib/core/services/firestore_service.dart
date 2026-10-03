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

        tx.update(roomRef, {'status': 'linked'});
        tx.update(
          _db.collection('users').doc(room.createdByUid),
          {'coupleId': coupleRef.id},
        );
        tx.update(
          _db.collection('users').doc(joinerUid),
          {'coupleId': coupleRef.id},
        );

        return JoinRoomResult.success;
      });
    } catch (e, stack) {
      debugPrint('══════════════════════════════');
      debugPrint('joinRoom FAILED');
      debugPrint('Code attempted: $code');
      debugPrint('Joiner UID: $joinerUid');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      debugPrint('══════════════════════════════');
      return JoinRoomResult.error;
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