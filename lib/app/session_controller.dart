import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/couple_model.dart';
import '../core/models/user_model.dart';
import '../core/utils/safe_notifier.dart';
import '../data/repositories/couple_repository.dart';
import '../data/repositories/user_repository.dart';

/// Why the session can no longer stay inside the shell.
enum SessionEnd { unlinkedByMe, unlinkedByPartner }

/// The signed-in player, their partner and their couple, streamed once and
/// shared by every tab. Features read from here instead of each loading and
/// watching the same documents.
class SessionController extends SafeNotifier {
  SessionController({
    required this.uid,
    required this._users,
    required this._couples,
    this.retryDelay = const Duration(seconds: 4),
  }) {
    _watchMe();
  }

  final String uid;
  final Duration retryDelay;
  final UserRepository _users;
  final CoupleRepository _couples;

  UserModel? me;
  UserModel? partner;
  CoupleModel? couple;

  /// Set once, when the couple has been unlinked; the shell then leaves.
  SessionEnd? end;

  /// True while the profile or couple can't be loaded. Retries continue.
  bool loadFailed = false;

  StreamSubscription<UserModel?>? _meSub;
  StreamSubscription<UserModel?>? _partnerSub;
  StreamSubscription<CoupleModel?>? _coupleSub;
  final List<Timer> _retries = [];
  String? _watchedCouple;
  String? _watchedPartner;

  bool get isReady => me != null && couple != null;
  String? get coupleId => couple?.coupleId;
  String get partnerUid => couple?.partnerUid(uid) ?? '';
  String get partnerName {
    final name = partner?.displayName ?? '';
    return name.isEmpty ? 'PARTNER' : name.toUpperCase();
  }

  /// The first member of the couple is player one.
  bool get isPlayerOne => couple?.memberUids.firstOrNull == uid;

  void _watchMe() {
    _meSub?.cancel();
    _meSub = _users.watch(uid).listen((user) {
      if (user == null) return;
      me = user;
      loadFailed = false;
      final coupleId = user.coupleId;
      if (coupleId == null || coupleId.isEmpty) {
        _confirmUnlinked();
      } else if (coupleId != _watchedCouple) {
        _watchCouple(coupleId);
      }
      notifyListeners();
    }, onError: (Object e) => _retry('profile', e, _watchMe));
  }

  /// A profile without a couple may only be an outdated cached copy (right
  /// after pairing), so ask the server before leaving the shell.
  Future<void> _confirmUnlinked() async {
    try {
      final latest = await _users.fetch(uid);
      if (isDisposed || latest == null) return;
      if ((latest.coupleId ?? '').isNotEmpty) return;
      _finish(SessionEnd.unlinkedByMe);
      notifyListeners();
    } catch (e) {
      debugPrint('Could not confirm the link: $e');
    }
  }

  void _watchCouple(String id) {
    _watchedCouple = id;
    _coupleSub?.cancel();
    _coupleSub = _couples.watch(id).listen((value) {
      if (value == null) return;
      couple = value;
      loadFailed = false;
      if (value.status == CoupleStatus.unlinked) {
        _finish(value.unlinkedByUid == uid
            ? SessionEnd.unlinkedByMe
            : SessionEnd.unlinkedByPartner);
      } else if (partnerUid.isNotEmpty && partnerUid != _watchedPartner) {
        _watchPartner(partnerUid);
      }
      notifyListeners();
    }, onError: (Object e) => _retry('couple', e, () => _watchCouple(id)));
  }

  void _watchPartner(String id) {
    _watchedPartner = id;
    _partnerSub?.cancel();
    _partnerSub = _users.watch(id).listen((user) {
      if (user == null) return;
      partner = user;
      notifyListeners();
    }, onError: (Object e) => _retry('partner', e, () => _watchPartner(id)));
  }

  /// A listener stops for good after an error, so a new one is started.
  void _retry(String what, Object error, VoidCallback watch) {
    debugPrint('Session $what stream error: $error');
    if (isDisposed || end != null) return;
    if (!isReady) {
      loadFailed = true;
      notifyListeners();
    }
    _retries.removeWhere((timer) => !timer.isActive);
    _retries.add(Timer(retryDelay, () {
      if (!isDisposed && end == null) watch();
    }));
  }

  void _finish(SessionEnd reason) {
    if (end != null) return;
    end = reason;
    if (reason == SessionEnd.unlinkedByPartner) {
      // Best effort: the next launch clears it too.
      _users.setCoupleId(uid, null).catchError(
          (Object e) => debugPrint('Clearing the unlinked couple failed: $e'));
    }
  }

  @override
  void dispose() {
    _meSub?.cancel();
    _coupleSub?.cancel();
    _partnerSub?.cancel();
    for (final timer in _retries) {
      timer.cancel();
    }
    super.dispose();
  }
}
