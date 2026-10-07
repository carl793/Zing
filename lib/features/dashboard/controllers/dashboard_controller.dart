import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/couple_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/couple_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';

enum DistanceState { loading, bothLive, partial, bothOff, together, networkFail }
enum QuestState { none, pending, accepted }

class DashboardController extends ChangeNotifier {
  DashboardController(this._fs, this._loc, this._coupleService,
      {required this.myUid});

  final FirestoreService _fs;
  final LocationService _loc;
  final CoupleService _coupleService;
  final String myUid;

  // ── User & couple data ──
  UserModel? me;
  UserModel? partner;
  CoupleModel? couple;
  StreamSubscription? _coupleSub;
  StreamSubscription? _meSub;
  StreamSubscription? _partnerSub;

  // ── Distance state ──
  DistanceState distanceState = DistanceState.loading;
  double? distanceKm;
  String myCity = '';
  String partnerCity = '';
  DateTime? lastUpdated;
  int daysTogetherthisYear = 0;

  // ── Reunion Quest countdown ──
  Timer? _questTimer;
  Duration _questRemaining = Duration.zero;
  double questProgress = 0;

  bool _disposed = false;

  String get questCountdown {
    if (_questRemaining == Duration.zero) return '0D:00H:00M';
    final d = _questRemaining.inDays;
    final h = _questRemaining.inHours % 24;
    final m = _questRemaining.inMinutes % 60;
    return '${d}D:${h.toString().padLeft(2, '0')}H:${m.toString().padLeft(2, '0')}M';
  }

  QuestState get questState {
    final q = couple?.reunionQuest;
    if (q == null || q.status == ReunionQuestStatus.none) return QuestState.none;
    if (q.status == ReunionQuestStatus.pending) return QuestState.pending;
    return QuestState.accepted;
  }

  bool get isQuestProposer =>
      couple?.reunionQuest.proposedByUid == myUid;

  String get distanceUnit => couple?.unitPref == 'mi' ? 'MI' : 'KM';
  double? get displayDistance => distanceKm == null
      ? null
      : distanceUnit == 'MI'
          ? distanceKm! * 0.621371
          : distanceKm;
  bool get isApproximateDistance =>
      (me?.currentLocation == null || me?.locationEnabled != true) ||
      (partner?.currentLocation == null || partner?.locationEnabled != true);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> init() async {
    final mySnap = await _fs.doc('users/$myUid').get();
    me = UserModel.fromMap(myUid, mySnap.data()!);
    _meSub = _fs.streamDoc('users/$myUid').listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final oldEnabled = me?.locationEnabled ?? false;
      me = UserModel.fromMap(myUid, snap.data()!);
      _recalculateDistance();
      if (!oldEnabled && me!.locationEnabled) refreshMyLocation();
      notifyListeners();
    });
    if (me!.coupleId == null) return;

    _coupleSub = _fs.streamDoc('couples/${me!.coupleId}').listen((snap) {
      if (!snap.exists) return;
      couple = CoupleModel.fromMap(snap.id, snap.data()!);
      _updateQuestCountdown();
      notifyListeners();
    });

    final coupleSnap = await _fs.doc('couples/${me!.coupleId}').get();
    couple = CoupleModel.fromMap(me!.coupleId!, coupleSnap.data()!);
    final partnerUid = couple!.partnerUid(myUid);

    _partnerSub = _fs.streamDoc('users/$partnerUid').listen((snap) {
      if (!snap.exists) return;
      partner = UserModel.fromMap(partnerUid, snap.data()!);
      _recalculateDistance();
      notifyListeners();
    });

    await refreshMyLocation();
    _loadDaysTogetherThisYear();
  }

  Future<void> _loadDaysTogetherThisYear() async {
    if (me?.coupleId == null) return;
    try {
      final year = DateTime.now().year;
      // Query by date range only (single-field index) and filter
      // entryType client-side — a server-side entryType + date filter
      // would need a composite index that is not deployed.
      final snap = await FirebaseFirestore.instance
          .collection('couples/${me!.coupleId}/memories')
          .where('date', isGreaterThanOrEqualTo: DateTime(year, 1, 1))
          .where('date', isLessThan: DateTime(year + 1, 1, 1))
          .get();
      // Count distinct days
      final days = snap.docs
          .where((d) => d.data()['entryType'] == 'memory')
          .map((d) => (d.data()['date'] as dynamic)?.toString().substring(0, 10))
          .toSet()
          .length;
      daysTogetherthisYear = days;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshMyLocation() async {
    if (me?.locationEnabled == true) {
      try {
        final pos = await _loc.updateCurrentLocation(myUid);
        if (pos != null) {
          me = UserModel.fromMap(myUid, {...me!.toMap(), 'currentLocation': pos});
        }
      } catch (_) {
        distanceState = DistanceState.networkFail;
        notifyListeners();
        return;
      }
    }
    _recalculateDistance();
    notifyListeners();
  }

  Future<void> enableLocation() async {
    try {
      final granted = await _loc.requestPermission();
      if (!granted) return;
      await _fs.updateDoc('users/$myUid', {'locationEnabled': true});
      me = UserModel.fromMap(myUid, {...me!.toMap(), 'locationEnabled': true});
      await refreshMyLocation();
    } catch (e) {
      debugPrint('Enable location failed: $e');
      distanceState = DistanceState.networkFail;
      notifyListeners();
    }
  }

  void _recalculateDistance() {
    myCity = me?.homeCity ?? '';
    partnerCity = partner?.homeCity ?? '';
    final myLoc = me?.locationEnabled == true
        ? me?.currentLocation ?? me?.homeLocation
        : me?.homeLocation;
    final partnerLoc = partner?.locationEnabled == true
        ? partner?.currentLocation ?? partner?.homeLocation
        : partner?.homeLocation;

    if (myLoc == null && partnerLoc == null) {
      distanceKm = null;
      distanceState = DistanceState.bothOff;
      notifyListeners();
      return;
    }

    if (me?.locationEnabled == true && partner?.locationEnabled == true) {
      distanceState = DistanceState.bothLive;
    } else {
      distanceState = DistanceState.partial;
    }

    if (myLoc != null && partnerLoc != null) {
      distanceKm = LocationService.distanceBetween(myLoc, partnerLoc);
      if (me?.locationEnabled == true &&
          partner?.locationEnabled == true &&
          me?.currentLocation != null &&
          partner?.currentLocation != null &&
          distanceKm! < 5) {
        distanceState = DistanceState.together;
      }
    } else {
      distanceKm = null;
    }

    lastUpdated = me?.currentLocationUpdatedAt;
    notifyListeners();
  }

  void _updateQuestCountdown() {
    _questTimer?.cancel();
    final target = couple?.reunionQuest.targetDate;
    if (target == null || questState != QuestState.accepted) return;

    final linked = couple!.linkedAt;
    final total = target.difference(linked).inSeconds;

    _questTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = target.difference(DateTime.now());
      if (remaining.isNegative) {
        _questRemaining = Duration.zero;
        questProgress = 1.0;
        _questTimer?.cancel();
      } else {
        _questRemaining = remaining;
        final elapsed = total - remaining.inSeconds;
        questProgress =
            (total > 0 ? elapsed / total : 0.0).clamp(0.0, 1.0).toDouble();
      }
      notifyListeners();
    });
  }

  // ── Quest actions ──

  Future<void> proposeQuest({
    required String destination,
    required DateTime targetDate,
    String? notes,
  }) async {
    if (couple == null) return;
    final quest = ReunionQuest(
      status: ReunionQuestStatus.pending,
      destination: destination,
      targetDate: targetDate,
      proposedByUid: myUid,
      notes: notes,
    );
    await _fs.updateDoc('couples/${me!.coupleId}', {'reunionQuest': quest.toMap()});
  }

  Future<void> acceptQuest() async {
    if (couple == null) return;
    final current = couple!.reunionQuest;
    final updated = ReunionQuest(
      status: ReunionQuestStatus.accepted,
      destination: current.destination,
      targetDate: current.targetDate,
      proposedByUid: current.proposedByUid,
      notes: current.notes,
    );
    await _fs.updateDoc('couples/${me!.coupleId}', {'reunionQuest': updated.toMap()});
  }

  Future<void> cancelQuest() async {
    if (couple == null || me?.coupleId == null) return;
    await _coupleService.clearReunionQuest(me!.coupleId!);
  }

  @override
  void dispose() {
    _disposed = true;
    _coupleSub?.cancel();
    _meSub?.cancel();
    _partnerSub?.cancel();
    _questTimer?.cancel();
    super.dispose();
  }
}
