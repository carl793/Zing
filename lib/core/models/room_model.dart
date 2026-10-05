import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus { pending, linked, expired, cancelled }

class RoomModel {
  final String code;
  final String createdByUid;
  final RoomStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Set once the room is linked. Carries the id of the couple document so
  /// the creator can claim the link from their own account document.
  final String? coupleId;

  RoomModel({
    required this.code,
    required this.createdByUid,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.coupleId,
  });

  factory RoomModel.fromMap(String code, Map<String, dynamic> data) => RoomModel(
        code: code,
        createdByUid: data['createdByUid'],
        status: RoomStatus.values.firstWhere(
          (s) => s.name == (data['status'] ?? 'pending'),
          orElse: () => RoomStatus.pending,
        ),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        expiresAt: (data['expiresAt'] as Timestamp).toDate(),
        coupleId: data['coupleId'] as String?,
      );

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}