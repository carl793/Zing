import 'package:cloud_firestore/cloud_firestore.dart';

enum CoupleStatus { active, unlinked }
enum ReunionQuestStatus { none, pending, accepted }

class ReunionQuest {
  final ReunionQuestStatus status;
  final String? destination;
  final DateTime? targetDate;
  final String? proposedByUid;
  final String? notes;

  ReunionQuest({
    this.status = ReunionQuestStatus.none,
    this.destination,
    this.targetDate,
    this.proposedByUid,
    this.notes,
  });

  factory ReunionQuest.fromMap(Map<String, dynamic>? data) {
    if (data == null) return ReunionQuest();
    return ReunionQuest(
      status: ReunionQuestStatus.values.firstWhere(
        (s) => s.name == (data['status'] ?? 'none'),
        orElse: () => ReunionQuestStatus.none,
      ),
      destination: data['destination'],
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      proposedByUid: data['proposedByUid'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'destination': destination,
        if (targetDate != null) 'targetDate': Timestamp.fromDate(targetDate!),
        'proposedByUid': proposedByUid,
        'notes': notes,
      };
}

class CoupleSettings {
  final bool chiptuneFx;
  final bool bgm;
  final bool reunionAlerts;

  CoupleSettings({this.chiptuneFx = true, this.bgm = false, this.reunionAlerts = true});

  factory CoupleSettings.fromMap(Map<String, dynamic>? data) => CoupleSettings(
        chiptuneFx: data?['chiptuneFx'] ?? true,
        bgm: data?['bgm'] ?? false,
        reunionAlerts: data?['reunionAlerts'] ?? true,
      );

  Map<String, dynamic> toMap() => {'chiptuneFx': chiptuneFx, 'bgm': bgm, 'reunionAlerts': reunionAlerts};
}

class CoupleModel {
  final String coupleId;
  final List<String> memberUids;
  final String pairingCode;
  final CoupleStatus status;
  final DateTime linkedAt;
  final DateTime? anniversaryDate;
  final String unitPref; // "km" | "mi"
  final ReunionQuest reunionQuest;
  final CoupleSettings settings;

  CoupleModel({
    required this.coupleId,
    required this.memberUids,
    required this.pairingCode,
    this.status = CoupleStatus.active,
    required this.linkedAt,
    this.anniversaryDate,
    this.unitPref = 'km',
    required this.reunionQuest,
    required this.settings,
  });

  factory CoupleModel.fromMap(String coupleId, Map<String, dynamic> data) => CoupleModel(
        coupleId: coupleId,
        memberUids: List<String>.from(data['memberUids'] ?? []),
        pairingCode: data['pairingCode'] ?? '',
        status: CoupleStatus.values.firstWhere(
          (s) => s.name == (data['status'] ?? 'active'),
          orElse: () => CoupleStatus.active,
        ),
        linkedAt: (data['linkedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        anniversaryDate: (data['anniversaryDate'] as Timestamp?)?.toDate(),
        unitPref: data['unitPref'] ?? 'km',
        reunionQuest: ReunionQuest.fromMap(data['reunionQuest']),
        settings: CoupleSettings.fromMap(data['settings']),
      );

  /// The other partner's uid, given the current user's uid.
  String partnerUid(String myUid) => memberUids.firstWhere((u) => u != myUid, orElse: () => '');
}