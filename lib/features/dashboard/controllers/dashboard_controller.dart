import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/foundation.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/couple_model.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/repositories/memory_repository.dart';
import '../../../data/repositories/user_repository.dart';

enum DistanceState { loading, failed, unknown, apart, together }

enum QuestState { none, pending, accepted }

class DashboardController extends SafeNotifier {
  DashboardController({
    required this.session,
    required this._users,
    required this._couples,
    required this._memories,
    required this._location,
  }) {
    session.addListener(_onSession);
    _onSession();
  }

  final SessionController session;
  final UserRepository _users;
  final CoupleRepository _couples;
  final MemoryRepository _memories;
  final LocationService _location;

  /// Positions older than this are shown as approximate.
  static const _freshFor = Duration(hours: 12);
  static const _togetherKm = 5;
  static const _refreshEvery = Duration(minutes: 5);

  static const _saveError =
      "COULDN'T SAVE THE QUEST. CHECK YOUR CONNECTION.";
  static const _notLinkedError = 'NO PARTNER LINKED YET.';

  UserModel? get me => session.me;
  UserModel? get partner => session.partner;
  CoupleModel? get couple => session.couple;

  void _onSession() {
    final coupleId = session.coupleId;
    if (coupleId != null && coupleId != _watchedCouple) {
      _watchedCouple = coupleId;
      _watchYear(coupleId);
    }
    // At launch, and whenever sharing is switched on (here or in Settings).
    if (isSharing != _wasSharing) {
      _wasSharing = isSharing;
      if (isSharing) refreshLocation();
    }
    _updateQuest();
    notifyListeners();
  }

  // ── Days together ──────────────────────────────────────────────────────

  int daysTogetherThisYear = 0;
  String? _watchedCouple;
  StreamSubscription<List<MemoryModel>>? _yearSub;

  void _watchYear(String coupleId) {
    _yearSub?.cancel();
    _yearSub = _memories.watchYear(coupleId, DateTime.now().year).listen(
      (entries) {
        daysTogetherThisYear = entries
            .where((e) => e.entryType == MemoryEntryType.memory)
            .map((e) => ZingDateUtils.isoDate(e.date))
            .toSet()
            .length;
        notifyListeners();
      },
      onError: (Object e) => debugPrint('Dashboard memories error: $e'),
    );
  }

  // ── Location ───────────────────────────────────────────────────────────

  /// Null until checked.
  LocationAccess? locationAccess;

  /// True while this phone's position is being read.
  bool locating = false;

  /// True when sharing is on but the phone gave no position.
  bool positionUnavailable = false;

  DateTime? _lastRefresh;
  bool _wasSharing = false;

  bool get isSharing => me?.locationEnabled == true;

  /// Sharing is on in Zing, but the phone no longer allows it.
  bool get sharingBlocked =>
      isSharing &&
      locationAccess != null &&
      locationAccess != LocationAccess.granted;

  /// Starts sharing. Call only once access has been granted.
  Future<void> startSharing() async {
    try {
      await _users.shareLocation(session.uid);
    } catch (e) {
      debugPrint('Sharing location failed: $e');
    }
    await refreshLocation();
  }

  /// Refreshes this phone's shared position, e.g. when the app is reopened.
  Future<void> refreshLocation({bool onlyIfStale = false}) async {
    if (!isSharing || locating) return;
    final last = _lastRefresh;
    if (onlyIfStale &&
        last != null &&
        !sharingBlocked &&
        DateTime.now().difference(last) < _refreshEvery) {
      return;
    }
    _lastRefresh = DateTime.now();
    locating = true;
    notifyListeners();
    try {
      locationAccess = await _location.access();
      if (locationAccess == LocationAccess.granted) {
        final position = await _location.currentPosition();
        positionUnavailable = position == null;
        // Sharing may have been turned off while waiting for the position.
        if (position != null && isSharing && !isDisposed) {
          await _users.shareLocation(session.uid, location: position);
        }
      }
    } catch (e) {
      debugPrint('Refreshing location failed: $e');
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  // ── Distance ───────────────────────────────────────────────────────────

  static bool _isLive(UserModel? user) {
    final at = user?.currentLocationUpdatedAt;
    return user != null &&
        user.locationEnabled &&
        user.currentLocation != null &&
        // Missing only while the server is still filling it in.
        (at == null || DateTime.now().difference(at) < _freshFor);
  }

  static GeoPoint? _pointOf(UserModel? user) => user == null
      ? null
      : (user.locationEnabled ? user.currentLocation : null) ??
          user.homeLocation;

  bool get isMyLocationLive => _isLive(me);
  bool get isPartnerLocationLive => _isLive(partner);
  bool get isApproximate => !isMyLocationLive || !isPartnerLocationLive;

  double? get distanceKm {
    final mine = _pointOf(me);
    final theirs = _pointOf(partner);
    if (mine == null || theirs == null) return null;
    return LocationService.distanceKm(mine, theirs);
  }

  String get distanceUnit => couple?.unitPref == 'mi' ? 'MI' : 'KM';

  double? get displayDistance {
    final km = distanceKm;
    return km == null || distanceUnit == 'KM' ? km : km * 0.621371;
  }

  DistanceState get distanceState {
    if (!session.isReady) {
      return session.loadFailed ? DistanceState.failed : DistanceState.loading;
    }
    final km = distanceKm;
    if (km == null) return DistanceState.unknown;
    return !isApproximate && km < _togetherKm
        ? DistanceState.together
        : DistanceState.apart;
  }

  /// Whose position is missing or out of date, if anyone's.
  String? get approximateReason {
    if (!isApproximate) return null;
    if (!isMyLocationLive && !isPartnerLocationLive) {
      return 'APPROX. BOTH LOCATIONS ARE NOT LIVE';
    }
    return isMyLocationLive
        ? "APPROX. ${session.partnerName}'S LOCATION IS NOT LIVE"
        : 'APPROX. YOUR LOCATION IS NOT LIVE';
  }

  // ── Reunion quest ──────────────────────────────────────────────────────

  Timer? _questTimer;
  String questCountdown = _zeroCountdown;
  double questProgress = 0;
  static const _zeroCountdown = '0D:00H:00M';

  QuestState get questState => switch (couple?.reunionQuest.status) {
        ReunionQuestStatus.pending => QuestState.pending,
        ReunionQuestStatus.accepted => QuestState.accepted,
        _ => QuestState.none,
      };

  bool get isQuestProposer =>
      couple?.reunionQuest.proposedByUid == session.uid;

  void _updateQuest() {
    _questTimer?.cancel();
    final quest = couple?.reunionQuest;
    final target = quest?.targetDate;
    if (quest == null || target == null || questState != QuestState.accepted) {
      return;
    }

    final remaining = target.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      questCountdown = _zeroCountdown;
      questProgress = 1;
      return;
    }
    String two(int n) => n.toString().padLeft(2, '0');
    questCountdown = '${remaining.inDays}D:${two(remaining.inHours % 24)}H:'
        '${two(remaining.inMinutes % 60)}M';

    // Progress runs from acceptance; quests accepted before that was recorded
    // fall back to the day the couple linked.
    final start = quest.acceptedAt ?? couple!.linkedAt;
    final total = target.difference(start).inSeconds;
    questProgress = total <= 0
        ? 0
        : (1 - remaining.inSeconds / total).clamp(0.0, 1.0).toDouble();

    // The display has no seconds, so wake only when its next minute starts.
    _questTimer = Timer(Duration(seconds: remaining.inSeconds % 60 + 1), () {
      _updateQuest();
      notifyListeners();
    });
  }

  // Each returns null on success, or a message to show.

  Future<String?> proposeQuest({
    required String destination,
    required DateTime targetDate,
    String? notes,
  }) =>
      _saveQuest((id) => _couples.proposeQuest(
            id,
            destination: destination,
            targetDate: targetDate,
            proposedByUid: session.uid,
            notes: notes,
          ));

  Future<String?> acceptQuest() => _saveQuest(_couples.acceptQuest);

  Future<String?> cancelQuest() => _saveQuest(_couples.clearQuest);

  Future<String?> _saveQuest(Future<void> Function(String id) write) async {
    final id = session.coupleId;
    if (id == null) return _notLinkedError;
    try {
      await write(id);
      return null;
    } catch (e) {
      debugPrint('Saving the quest failed: $e');
      return _saveError;
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    _yearSub?.cancel();
    _questTimer?.cancel();
    super.dispose();
  }
}
