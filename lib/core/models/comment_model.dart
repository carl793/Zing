import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String authorUid;
  final String text;
  final DateTime createdAt;

  CommentModel({required this.commentId, required this.authorUid, required this.text, required this.createdAt});

  factory CommentModel.fromMap(String id, Map<String, dynamic> data) => CommentModel(
        commentId: id,
        authorUid: data['authorUid'] ?? '',
        text: data['text'] ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'authorUid': authorUid, 'text': text, 'createdAt': FieldValue.serverTimestamp()};
}