import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/couple_model.dart';
import '../../core/models/room_model.dart';
import '../firestore_helpers.dart';
import 'couple_repository.dart';
import 'user_repository.dart';

enum JoinRoomResult { success, notFound, expired, alreadyLinked, selfJoin, error }

/// Pairing rooms (`rooms/{code}`) and linking two accounts through them.
class PairingRepository {
  PairingRepository({
    required this._users,
    required this._couples,
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  final UserRepository _users;
  final CoupleRepository _couples;
  final FirebaseFirestore _db;
  final Random _random = Random.secure();

  static const codeLifetime = Duration(hours: 24);

  DocumentReference<Json> _room(String code) =>
      _db.collection('rooms').doc(code);

  Future<String> createRoom(String creatorUid) =>
      onlineOnly(_createRoom(creatorUid));

  Future<String> _createRoom(String creatorUid) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = (_random.nextInt(900000) + 100000).toString();
      // An existing room keeps its code, even an expired one: rooms are only
      // ever created, never overwritten.
      if ((await _room(code).get()).exists) continue;
      await _room(code).set({
        'createdByUid': creatorUid,
        'status': RoomStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(codeLifetime)),
      });
      return code;
    }
    throw StateError('No free room code found.');
  }

  Stream<RoomModel?> watchRoom(String code) => _room(code).snapshots().map(
        (snap) => snap.exists ? RoomModel.fromMap(code, snap.data()!) : null,
      );

  Future<void> cancelRoom(String code) =>
      settleWrite(_room(code).update({'status': RoomStatus.cancelled.name}));

  /// Links [joinerUid] with the room's creator, creating their couple.
  Future<JoinRoomResult> joinRoom({
    required String code,
    required String joinerUid,
  }) async {
    try {
      return await onlineOnly(_db.runTransaction<JoinRoomResult>((tx) async {
        final snap = await tx.get(_room(code));
        if (!snap.exists) return JoinRoomResult.notFound;
        final room = RoomModel.fromMap(code, snap.data()!);
        if (room.createdByUid == joinerUid) return JoinRoomResult.selfJoin;
        if (room.status == RoomStatus.linked) return JoinRoomResult.alreadyLinked;
        if (room.status != RoomStatus.pending || room.isExpired) {
          return JoinRoomResult.expired;
        }

        final couple = _db.collection('couples').doc();
        tx.set(couple, {
          'memberUids': [room.createdByUid, joinerUid],
          'pairingCode': code,
          'status': CoupleStatus.active.name,
          'linkedAt': FieldValue.serverTimestamp(),
          'unitPref': 'km',
          'reunionQuest': ReunionQuest().toMap(),
          'settings': CoupleSettings().toMap(),
        });
        tx.update(_room(code), {
          'status': RoomStatus.linked.name,
          'coupleId': couple.id,
        });
        // Only the joiner's own profile: the creator claims the same couple
        // from the room (see resolveActiveCouple and PairingController).
        tx.set(
          _db.collection('users').doc(joinerUid),
          {'coupleId': couple.id},
          SetOptions(merge: true),
        );
        return JoinRoomResult.success;
      }));
    } catch (e) {
      debugPrint('joinRoom failed: $e');
      return JoinRoomResult.error;
    }
  }

  /// The active couple [uid] belongs to, or null while unpaired. [stored] is
  /// the link on the account's own profile.
  ///
  /// - A link to a couple that has been unlinked is cleared.
  /// - An account that was closed while its partner joined has no link yet;
  ///   the room it created carries the couple id, which is claimed here.
  ///
  /// Never throws. If the couple can't be checked, a stored link is trusted.
  Future<String?> resolveActiveCouple(String uid, {String? stored}) async {
    try {
      if (stored != null && stored.isNotEmpty) {
        if (await _couples.statusOf(stored) != CoupleStatus.unlinked) {
          return stored;
        }
        await _users.setCoupleId(uid, null);
        return null;
      }

      final rooms = await _db
          .collection('rooms')
          .where('createdByUid', isEqualTo: uid)
          .get();
      final linked = parseDocs(rooms, RoomModel.fromMap)
          .where((r) => r.status == RoomStatus.linked && r.coupleId != null)
          .toList()
        // Newest first. Sorting server-side would need a composite index.
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final room in linked) {
        final status = await _couples.statusOf(room.coupleId!);
        if (status != CoupleStatus.active) continue;
        await _users.setCoupleId(uid, room.coupleId);
        return room.coupleId;
      }
    } catch (e) {
      debugPrint('resolveActiveCouple failed: $e');
    }
    return null;
  }
}
