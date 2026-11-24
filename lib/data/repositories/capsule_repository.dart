import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/capsule_model.dart';
import '../firestore_helpers.dart';

typedef CapsuleList = ({List<CapsuleModel> capsules, bool fromCache});

/// Vault chests (`couples/{coupleId}/capsules`).
class CapsuleRepository {
  CapsuleRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Json> _capsules(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('capsules');

  /// A unique id, created up front so retrying a save can't duplicate it.
  String newId(String coupleId) => _capsules(coupleId).doc().id;

  /// Live sealed and unlocked chests, newest first. `fromCache` is true until
  /// the server has confirmed the list.
  Stream<CapsuleList> watch(String coupleId) => _capsules(coupleId)
      .where('status', whereIn: [
        CapsuleStatus.sealed.name,
        CapsuleStatus.unlocked.name,
      ])
      .snapshots(includeMetadataChanges: true)
      .map((snap) => (
            capsules: parseDocs(snap, CapsuleModel.fromMap)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
            fromCache: snap.metadata.isFromCache,
          ));

  Future<void> create(String coupleId, CapsuleModel capsule) => settleWrite(
      _capsules(coupleId).doc(capsule.capsuleId).set(capsule.toMap()));

  Future<void> unlock(String coupleId, String id) => _update(coupleId, id, {
        'status': CapsuleStatus.unlocked.name,
        'openedAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancel(String coupleId, String id) =>
      _update(coupleId, id, {'status': CapsuleStatus.cancelled.name});

  Future<void> setArchived(String coupleId, String id, bool archived) =>
      _update(coupleId, id, {'isArchived': archived});

  /// Records this partner's tap; the second tap unlocks the chest.
  Future<void> tap(String coupleId, String id, {required bool isPlayerOne}) =>
      onlineOnly(_db.runTransaction<void>((tx) async {
        final ref = _capsules(coupleId).doc(id);
        final data = (await tx.get(ref)).data();
        if (data == null) return;
        final capsule = CapsuleModel.fromMap(id, data);
        if (capsule.status != CapsuleStatus.sealed) return;

        final taps = capsule.dualTapState;
        final otherTapped =
            (isPlayerOne ? taps?.p2TappedAt : taps?.p1TappedAt) != null;
        final myField = isPlayerOne ? 'p1TappedAt' : 'p2TappedAt';
        tx.update(ref, {
          'dualTapState.$myField': FieldValue.serverTimestamp(),
          if (otherTapped) ...{
            'status': CapsuleStatus.unlocked.name,
            'openedAt': FieldValue.serverTimestamp(),
          },
        });
      }));

  Future<void> _update(String coupleId, String id, Json data) =>
      settleWrite(_capsules(coupleId).doc(id).update(data));
}
