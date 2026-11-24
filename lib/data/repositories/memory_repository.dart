import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/comment_model.dart';
import '../../core/models/memory_model.dart';
import '../firestore_helpers.dart';

/// Calendar entries (memories and plans) and their comments.
class MemoryRepository {
  MemoryRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Json> _memories(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('memories');

  /// A unique id, created up front so retrying a save can't duplicate it.
  String newId(String coupleId) => _memories(coupleId).doc().id;

  /// Every entry of one calendar year. The dashboard and calendar both watch
  /// this, and Firestore shares one query between identical listeners.
  Stream<List<MemoryModel>> watchYear(String coupleId, int year) =>
      _memories(coupleId)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.utc(year)))
          .where('date', isLessThan: Timestamp.fromDate(DateTime.utc(year + 1)))
          .snapshots()
          .map((snap) => parseDocs(snap, MemoryModel.fromMap));

  /// The most recent entries up to and including [day].
  Stream<List<MemoryModel>> watchLatest(
    String coupleId,
    DateTime day, {
    int limit = 30,
  }) =>
      _memories(coupleId)
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(day))
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => parseDocs(snap, MemoryModel.fromMap));

  Future<void> create(String coupleId, MemoryModel memory) => settleWrite(
      _memories(coupleId).doc(memory.memoryId).set(memory.toMap()));

  /// Saves an entry's content, converting a plan when [type] is memory.
  /// [pin] and [photoUrls] are only written for memories.
  Future<void> updateContent(
    String coupleId,
    String memoryId, {
    required MemoryEntryType type,
    required String title,
    required String story,
    required String tag,
    LocationPin? pin,
    List<String>? photoUrls,
  }) =>
      settleWrite(_memories(coupleId).doc(memoryId).update({
        'entryType': type.name,
        'title': title,
        'story': story,
        'tagCategory': tag,
        if (type == MemoryEntryType.memory)
          'locationPin': pin?.toMap() ?? FieldValue.delete(),
        'photoUrls': ?photoUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      }));

  Future<void> delete(String coupleId, String memoryId) =>
      settleWrite(_memories(coupleId).doc(memoryId).delete());

  Stream<List<CommentModel>> watchComments(String coupleId, String memoryId) =>
      _memories(coupleId)
          .doc(memoryId)
          .collection('comments')
          .orderBy('createdAt')
          .snapshots()
          .map((snap) => parseDocs(snap, CommentModel.fromMap));

  Future<void> addComment(
    String coupleId,
    String memoryId, {
    required String authorUid,
    required String text,
  }) =>
      settleWrite(
        _memories(coupleId).doc(memoryId).collection('comments').doc().set({
          'authorUid': authorUid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
}
