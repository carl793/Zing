import 'package:cloud_firestore/cloud_firestore.dart';

enum CoupleStatus { active, unlinked }
enum ReunionQuestStatus { none, pending, accepted }

class ReunionQuest {
  final ReunionQuestStatus status;
  final String? destination;
  final DateTime? targetDate;
  final String? proposedByUid;
  final String? notes;

  /// When the partner accepted; the countdown's progress starts here.
  final DateTime? acceptedAt;

  ReunionQuest({
    this.status = ReunionQuestStatus.none,
    this.destination,
    this.targetDate,
    this.proposedByUid,
    this.notes,
    this.acceptedAt,
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
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'destination': destination,
        'targetDate': _timestamp(targetDate),
        'proposedByUid': proposedByUid,
        'notes': notes,
        'acceptedAt': _timestamp(acceptedAt),
      };

  static Timestamp? _timestamp(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
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

  /// Who ended the link, once [status] is unlinked.
  final String? unlinkedByUid;

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
    this.unlinkedByUid,
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
        unlinkedByUid: data['unlinkedByUid'],
      );

  CoupleModel copyWith({
    CoupleStatus? status,
    String? unitPref,
    ReunionQuest? reunionQuest,
    CoupleSettings? settings,
  }) =>
      CoupleModel(
        coupleId: coupleId,
        memberUids: memberUids,
        pairingCode: pairingCode,
        status: status ?? this.status,
        linkedAt: linkedAt,
        anniversaryDate: anniversaryDate,
        unitPref: unitPref ?? this.unitPref,
        reunionQuest: reunionQuest ?? this.reunionQuest,
        settings: settings ?? this.settings,
        unlinkedByUid: unlinkedByUid,
      );

  /// The other partner's uid, given the current user's uid.
  String partnerUid(String myUid) => memberUids.firstWhere((u) => u != myUid, orElse: () => '');
}