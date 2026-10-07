import 'package:cloud_firestore/cloud_firestore.dart';

enum CapsuleTriggerMode { dateRelease, dualTapSync }
enum CapsuleStatus { sealed, unlocked, cancelled }

class DualTapState {
  final DateTime? p1TappedAt;
  final DateTime? p2TappedAt;
  DualTapState({this.p1TappedAt, this.p2TappedAt});

  factory DualTapState.fromMap(Map<String, dynamic>? data) => DualTapState(
        p1TappedAt: (data?['p1TappedAt'] as Timestamp?)?.toDate(),
        p2TappedAt: (data?['p2TappedAt'] as Timestamp?)?.toDate(),
      );

  bool get bothTapped => p1TappedAt != null && p2TappedAt != null;

  Map<String, dynamic> toMap() => {
        if (p1TappedAt != null) 'p1TappedAt': Timestamp.fromDate(p1TappedAt!),
        if (p2TappedAt != null) 'p2TappedAt': Timestamp.fromDate(p2TappedAt!),
      };
}

class CapsuleModel {
  final String capsuleId;
  final String creatorUid;
  final String title;
  final CapsuleTriggerMode triggerMode;
  final DateTime? unlockDate;
  final DualTapState? dualTapState;
  final String secretNote;
  final String? photoUrl;
  final String? voiceNoteUrl;
  final CapsuleStatus status;
  final DateTime? openedAt;
  final bool isArchived;
  final DateTime createdAt;

  CapsuleModel({
    required this.capsuleId,
    required this.creatorUid,
    required this.title,
    required this.triggerMode,
    this.unlockDate,
    this.dualTapState,
    this.secretNote = '',
    this.photoUrl,
    this.voiceNoteUrl,
    this.status = CapsuleStatus.sealed,
    this.openedAt,
    this.isArchived = false,
    required this.createdAt,
  });

  factory CapsuleModel.fromMap(String id, Map<String, dynamic> data) => CapsuleModel(
        capsuleId: id,
        creatorUid: data['creatorUid'] ?? '',
        title: data['title'] ?? '',
        triggerMode: CapsuleTriggerMode.values.firstWhere(
          (t) => t.name == (data['triggerMode'] ?? 'dateRelease'),
          orElse: () => CapsuleTriggerMode.dateRelease,
        ),
        unlockDate: (data['unlockDate'] as Timestamp?)?.toDate(),
        dualTapState: data['dualTapState'] != null ? DualTapState.fromMap(data['dualTapState']) : null,
        secretNote: data['secretNote'] ?? '',
        photoUrl: data['photoUrl'],
        voiceNoteUrl: data['voiceNoteUrl'],
        status: CapsuleStatus.values.firstWhere(
          (s) => s.name == (data['status'] ?? 'sealed'),
          orElse: () => CapsuleStatus.sealed,
        ),
        openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
        isArchived: data['isArchived'] as bool? ?? false,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'creatorUid': creatorUid,
        'title': title,
        'triggerMode': triggerMode.name,
        if (unlockDate != null) 'unlockDate': Timestamp.fromDate(unlockDate!),
        if (dualTapState != null) 'dualTapState': dualTapState!.toMap(),
        'secretNote': secretNote,
        'photoUrl': photoUrl,
        'voiceNoteUrl': voiceNoteUrl,
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
