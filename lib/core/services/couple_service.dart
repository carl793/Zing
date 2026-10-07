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

  /// Soft-unlink: preserves all memories and capsules.
  /// Sets couple status to unlinked, clears coupleId on both users.
  Future<void> unlinkPartners({
    required String coupleId,
    required List<String> memberUids,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final coupleRef = FirebaseFirestore.instance.collection('couples').doc(coupleId);
    batch.update(coupleRef, {'status': 'unlinked'});
    for (final uid in memberUids) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'coupleId': null},
      );
    }
    await batch.commit();
  }
}