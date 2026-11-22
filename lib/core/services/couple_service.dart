import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/couple_model.dart';
import 'firestore_service.dart';

/// Handles couple-level business logic: reunion quest lifecycle and unlink.
class CoupleService {
  CoupleService(this._fs);
  final FirestoreService _fs;

  /// Clears an expired/resolved reunion quest.
  Future<void> clearReunionQuest(String coupleId) async {
    await _fs.updateDoc('couples/$coupleId', {
      'reunionQuest': ReunionQuest().toMap(),
    });
  }

  /// Soft unlink: every memory and chest is kept. Marks the couple unlinked
  /// and clears this account's own link.
  ///
  /// Rules only let an account write its own profile, so the partner's link
  /// is cleared by the partner's app once it sees the couple's new status
  /// (CoupleLinkGuard while it's open, recoverCoupleId at its next launch).
  Future<void> unlink({required String coupleId, required String myUid}) {
    final batch = _fs.batch()
      ..update(_fs.doc('couples/$coupleId'), {
        'status': CoupleStatus.unlinked.name,
        'unlinkedByUid': myUid,
        'unlinkedAt': FieldValue.serverTimestamp(),
      })
      ..set(
        _fs.doc('users/$myUid'),
        {'coupleId': null},
        SetOptions(merge: true),
      );
    return batch.commit();
  }
}
