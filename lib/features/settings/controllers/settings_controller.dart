import 'package:flutter/foundation.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/couple_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// Profile and couple settings. Values come from the live session, so a change
/// shows up at once here and on every other screen.
class SettingsController extends SafeNotifier {
  SettingsController({
    required this._session,
    required this._users,
    required this._couples,
    required this._location,
  }) {
    _session.addListener(notifyListeners);
  }

  final SessionController _session;
  final UserRepository _users;
  final CoupleRepository _couples;
  final LocationService _location;

  static const _offline = 'CHECK YOUR CONNECTION AND TRY AGAIN.';

  UserModel? get me => _session.me;
  CoupleModel? get couple => _session.couple;
  bool get loadFailed => _session.loadFailed;
  String get unit => couple?.unitPref ?? 'km';
  bool get alertsOn => couple?.settings.reunionAlerts ?? true;
  bool get isSharingLocation => me?.locationEnabled ?? false;

  bool saving = false;
  int _cityLookup = 0;

  // Each returns null on success, or a message to show.

  /// Saves the profile. A changed city is then looked up in the background;
  /// [onCityNotFound] runs if that fails.
  Future<String?> saveProfile({
    required String name,
    required String spriteId,
    required String city,
    required VoidCallback onCityNotFound,
  }) async {
    final profile = me;
    if (profile == null) return 'STILL LOADING. $_offline';
    if (name.isEmpty) return 'NAME CANNOT BE EMPTY.';
    final cityChanged = city.toLowerCase() != profile.homeCity.toLowerCase();
    final needsLookup =
        city.isNotEmpty && (cityChanged || profile.homeLocation == null);

    saving = true;
    notifyListeners();
    final error = await _try(
      'COULD NOT SAVE SETTINGS.',
      () => _users.saveProfile(
        profile.uid,
        displayName: name,
        avatarSpriteId: spriteId,
        homeCity: city,
        clearHomeLocation: cityChanged,
      ),
    );
    saving = false;
    notifyListeners();
    if (error == null && needsLookup) {
      _lookUpCity(profile.uid, city, onCityNotFound);
    }
    return error;
  }

  Future<void> _lookUpCity(
    String uid,
    String city,
    VoidCallback onNotFound,
  ) async {
    final lookup = ++_cityLookup;
    final location = await _location.findCity(city);
    // A newer save wins, and so does a city changed on another phone.
    if (isDisposed || lookup != _cityLookup) return;
    if (location == null) return onNotFound();
    if (await _try('', () => _users.setHomeLocation(uid, location)) != null &&
        !isDisposed) {
      onNotFound();
    }
  }

  Future<String?> setUnit(String value) async {
    final id = couple?.coupleId;
    if (id == null || value == unit) return null;
    return _try('COULD NOT SAVE THE UNIT.', () => _couples.setUnit(id, value));
  }

  Future<String?> setAlerts(bool enabled) async {
    final id = couple?.coupleId;
    if (id == null) return null;
    return _try(
      'COULD NOT SAVE ALERTS.',
      () => _couples.setReunionAlerts(id, enabled),
    );
  }

  /// Turns sharing on. Call only once access has been granted; the dashboard
  /// then reads and shares the position.
  Future<String?> shareLocation() => _try(
        'COULD NOT TURN ON SHARING.',
        () => _users.shareLocation(_session.uid),
      );

  Future<String?> stopSharingLocation() => _try(
        'COULD NOT TURN OFF SHARING.',
        () => _users.stopSharingLocation(_session.uid),
      );

  /// The session notices and leaves for pairing, on both phones.
  Future<String?> unlink() async {
    final id = couple?.coupleId;
    if (id == null) return 'COULD NOT UNLINK. $_offline';
    return _try(
      'COULD NOT UNLINK.',
      () => _couples.unlink(id: id, myUid: _session.uid),
    );
  }

  Future<String?> _try(String failure, Future<void> Function() write) async {
    try {
      await write();
      return null;
    } catch (e) {
      debugPrint('Settings write failed: $e');
      return '$failure $_offline';
    }
  }

  @override
  void dispose() {
    _session.removeListener(notifyListeners);
    super.dispose();
  }
}
