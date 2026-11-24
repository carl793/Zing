import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/couple_model.dart';
import '../firestore_helpers.dart';

/// The shared couple document (`couples/{coupleId}`): reunion quest, shared
/// settings and the link itself.
class CoupleRepository {
  CoupleRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Json> _doc(String id) => _db.collection('couples').doc(id);

  CoupleModel? _parse(DocumentSnapshot<Json> snap) {
    final data = snap.data();
    return data == null ? null : CoupleModel.fromMap(snap.id, data);
  }

  Stream<CoupleModel?> watch(String id) => _doc(id).snapshots().map(_parse);

  Future<CoupleModel?> fetch(String id) async => _parse(await _doc(id).get());

  /// The couple's status, or null when it can't be read right now (offline).
  /// A couple that is missing, or not this account's, counts as unlinked.
  Future<CoupleStatus?> statusOf(String id) async {
    try {
      return (await fetch(id))?.status ?? CoupleStatus.unlinked;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied' ? CoupleStatus.unlinked : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> proposeQuest(
    String id, {
    required String destination,
    required DateTime targetDate,
    required String proposedByUid,
    String? notes,
  }) =>
      _update(id, {
        'reunionQuest': ReunionQuest(
          status: ReunionQuestStatus.pending,
          destination: destination,
          targetDate: targetDate,
          proposedByUid: proposedByUid,
          notes: notes,
        ).toMap(),
      });

  Future<void> acceptQuest(String id) => _update(id, {
        'reunionQuest.status': ReunionQuestStatus.accepted.name,
        'reunionQuest.acceptedAt': FieldValue.serverTimestamp(),
      });

  Future<void> clearQuest(String id) =>
      _update(id, {'reunionQuest': ReunionQuest().toMap()});

  Future<void> setUnit(String id, String unit) =>
      _update(id, {'unitPref': unit});

  Future<void> setReunionAlerts(String id, bool enabled) =>
      _update(id, {'settings.reunionAlerts': enabled});

  /// Soft unlink: every memory and chest is kept. Marks the couple unlinked
  /// and clears this account's own link. The rules don't let one account write
  /// the other's profile, so the partner's app clears its own link when it
  /// sees the new status.
  Future<void> unlink({required String id, required String myUid}) {
    final batch = _db.batch()
      ..update(_doc(id), {
        'status': CoupleStatus.unlinked.name,
        'unlinkedByUid': myUid,
        'unlinkedAt': FieldValue.serverTimestamp(),
      })
      ..set(
        _db.collection('users').doc(myUid),
        {'coupleId': null},
        SetOptions(merge: true),
      );
    return settleWrite(batch.commit());
  }

  Future<void> _update(String id, Json data) =>
      settleWrite(_doc(id).update(data));
}
