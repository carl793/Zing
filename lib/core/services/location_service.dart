import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Whether this app may read the phone's position right now.
enum LocationAccess {
  granted,

  /// Not granted yet; the system prompt can still be shown.
  denied,

  /// The system won't prompt again; only the app settings can grant it.
  blocked,

  /// Location is switched off for the whole phone.
  serviceOff,
}

/// Device location and city lookup. Knows nothing about profiles.
class LocationService {
  static double distanceKm(GeoPoint a, GeoPoint b) =>
      Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      ) /
      1000;

  /// Current access. With [request], shows the system prompt if it still can.
  Future<LocationAccess> access({bool request = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceOff;
      }
      var permission = await Geolocator.checkPermission();
      if (request && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return switch (permission) {
        LocationPermission.whileInUse ||
        LocationPermission.always =>
          LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.blocked,
        _ => LocationAccess.denied,
      };
    } catch (e) {
      debugPrint('Checking location access failed: $e');
      return LocationAccess.denied;
    }
  }

  /// The phone's position, or its last known one when a fix takes too long.
  /// Null when neither is available.
  Future<GeoPoint?> currentPosition() async {
    const accuracy = LocationAccuracy.medium;
    const limit = Duration(seconds: 20);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    try {
      final position = await Geolocator.getCurrentPosition(
        // The plain Android location manager also works on phones without
        // Google services (e.g. recent Huawei models).
        locationSettings: isAndroid
            ? AndroidSettings(
                accuracy: accuracy,
                forceLocationManager: true,
                timeLimit: limit,
              )
            : const LocationSettings(accuracy: accuracy, timeLimit: limit),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Getting a position failed: $e');
    }
    try {
      final last = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: isAndroid,
      );
      return last == null ? null : GeoPoint(last.latitude, last.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Approximate coordinates of a typed city, or null when it isn't found or
  /// this phone has no city lookup.
  Future<GeoPoint?> findCity(String city) async {
    final query = city.trim();
    if (query.isEmpty) return null;
    try {
      final matches = await Geocoding()
          .locationFromAddress(query)
          .timeout(const Duration(seconds: 12));
      if (matches.isEmpty) return null;
      return GeoPoint(matches.first.latitude, matches.first.longitude);
    } catch (e) {
      debugPrint('City lookup failed: $e');
      return null;
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
