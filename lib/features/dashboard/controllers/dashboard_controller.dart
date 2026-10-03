import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/couple_model.dart';

enum DistanceState { loading, bothLive, partial, bothOff, together, networkFail }
enum QuestState { none, pending, accepted }

class DashboardController extends ChangeNotifier {
  final FirestoreService _fs;
  final LocationService _loc;
  final String myUid;

  DashboardController(this._fs, this._loc, {required this.myUid});

  // ── User & couple data ──
  UserModel? me;
  UserModel? partner;
  CoupleModel? couple;
  StreamSubscription? _coupleSub;
  StreamSubscription? _partnerSub;

  // ── Distance state ──
  DistanceState distanceState = DistanceState.loading;
  double? distanceKm;
  String myCity = '';
  String partnerCity = '';
  DateTime? lastUpdated;

  // ── Reunion Quest countdown ──
  Timer? _questTimer;
  Duration _questRemaining = Duration.zero;
  double questProgress = 0;

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

  Future<void> init() async {
    // Load my user doc
    final mySnap = await _fs.doc('users/$myUid').get();
    me = UserModel.fromMap(myUid, mySnap.data()!);
    if (me!.coupleId == null) return;

    // Stream couple doc for live reunion quest updates
    _coupleSub = _fs.streamDoc('couples/${me!.coupleId}').listen((snap) {
      if (!snap.exists) return;
      couple = CoupleModel.fromMap(snap.id, snap.data()!);
      _updateQuestCountdown();
      notifyListeners();
    });

    // Load partner once
    final coupleSnap = await _fs.doc('couples/${me!.coupleId}').get();
    couple = CoupleModel.fromMap(me!.coupleId!, coupleSnap.data()!);
    final partnerUid = couple!.partnerUid(myUid);

    // Stream partner user for live location changes
    _partnerSub = _fs.streamDoc('users/$partnerUid').listen((snap) {
      if (!snap.exists) return;
      partner = UserModel.fromMap(partnerUid, snap.data()!);
      _recalculateDistance();
      notifyListeners();
    });

    await refreshMyLocation();
  }

  Future<void> refreshMyLocation() async {
    if (me?.locationEnabled == true) {
      final pos = await _loc.updateCurrentLocation(myUid);
      if (pos != null) {
        me = UserModel.fromMap(myUid, {...me!.toMap(), 'currentLocation': pos});
      }
    }
    _recalculateDistance();
    notifyListeners();
  }

  Future<void> enableLocation() async {
    final granted = await _loc.requestPermission();
    if (!granted) return;
    await _fs.updateDoc('users/$myUid', {'locationEnabled': true});
    me = UserModel.fromMap(myUid,
        {...me!.toMap(), 'locationEnabled': true});
    await refreshMyLocation();
  }

  void _recalculateDistance() {
    final myLoc = me?.currentLocation ?? me?.homeLocation;
    final partnerLoc = partner?.currentLocation ?? partner?.homeLocation;

    if (myLoc == null && partnerLoc == null) {
      distanceState = DistanceState.bothOff;
      notifyListeners();
      return;
    }

    if (myLoc == null || partnerLoc == null) {
      // One location missing — try with what we have
      distanceState = DistanceState.partial;
    } else if (me?.locationEnabled == true && partner?.locationEnabled == true) {
      distanceState = DistanceState.bothLive;
    } else {
      distanceState = DistanceState.partial;
    }

    if (myLoc != null && partnerLoc != null) {
      distanceKm = LocationService.distanceBetween(myLoc, partnerLoc);
      if ((distanceKm ?? 999) < 5) {
        distanceState = DistanceState.together;
      }
    }

    lastUpdated = me?.currentLocationUpdatedAt;
    notifyListeners();
  }

  void _updateQuestCountdown() {
    _questTimer?.cancel();
    final target = couple?.reunionQuest.targetDate;
    if (target == null || questState != QuestState.accepted) return;

    final linkedAt = couple!.linkedAt;
    final total = target.difference(linkedAt).inSeconds;

    _questTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = target.difference(DateTime.now());
      if (remaining.isNegative) {
        _questRemaining = Duration.zero;
        questProgress = 1.0;
        _questTimer?.cancel();
      } else {
        _questRemaining = remaining;
        final elapsed = total - remaining.inSeconds;
        questProgress = (elapsed / total).clamp(0.0, 1.0);
      }
      notifyListeners();
    });
  }

  // ── Reunion Quest actions ──

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
    if (couple == null) return;
    await _fs.updateDoc('couples/${me!.coupleId}', {
      'reunionQuest': ReunionQuest().toMap(),
    });
  }

  @override
  void dispose() {
    _coupleSub?.cancel();
    _partnerSub?.cancel();
    _questTimer?.cancel();
    super.dispose();
  }
}