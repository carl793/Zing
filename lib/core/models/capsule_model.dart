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

/// What is sealed inside a chest. Stored apart from it, so the server can keep
/// it from the partner until the chest is open.
class CapsuleContent {
  static const fields = ['secretNote', 'photoUrl', 'voiceNoteUrl'];

  final String secretNote;
  final String? photoUrl;
  final String? voiceNoteUrl;

  const CapsuleContent({
    this.secretNote = '',
    this.photoUrl,
    this.voiceNoteUrl,
  });

  factory CapsuleContent.fromMap(Map<String, dynamic> data) => CapsuleContent(
        secretNote: data['secretNote'] ?? '',
        photoUrl: _url(data['photoUrl']),
        voiceNoteUrl: _url(data['voiceNoteUrl']),
      );

  static String? _url(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  Map<String, dynamic> toMap() => {
        'secretNote': secretNote,
        'photoUrl': photoUrl,
        'voiceNoteUrl': voiceNoteUrl,
      };
}

/// A chest as both partners see it: its label, how it opens, whether it has.
class CapsuleModel {
  final String capsuleId;
  final String creatorUid;
  final String title;
  final CapsuleTriggerMode triggerMode;
  final DateTime? unlockDate;
  final DualTapState? dualTapState;
  final CapsuleStatus status;
  final DateTime? openedAt;
  final bool isArchived;
  final DateTime createdAt;

  /// Content stored in the chest itself, by builds that didn't keep it apart.
  final CapsuleContent? inlineContent;

  CapsuleModel({
    required this.capsuleId,
    required this.creatorUid,
    required this.title,
    required this.triggerMode,
    this.unlockDate,
    this.dualTapState,
    this.status = CapsuleStatus.sealed,
    this.openedAt,
    this.isArchived = false,
    required this.createdAt,
    this.inlineContent,
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
        status: CapsuleStatus.values.firstWhere(
          (s) => s.name == (data['status'] ?? 'sealed'),
          orElse: () => CapsuleStatus.sealed,
        ),
        openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
        isArchived: data['isArchived'] as bool? ?? false,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        inlineContent: CapsuleContent.fields.any(data.containsKey)
            ? CapsuleContent.fromMap(data)
            : null,
      );

  /// Never includes the content: see CapsuleRepository.create.
  Map<String, dynamic> toMap() => {
        'creatorUid': creatorUid,
        'title': title,
        'triggerMode': triggerMode.name,
        if (unlockDate != null) 'unlockDate': Timestamp.fromDate(unlockDate!),
        if (dualTapState != null) 'dualTapState': dualTapState!.toMap(),
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
