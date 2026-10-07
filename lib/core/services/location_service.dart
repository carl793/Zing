import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

import 'firestore_service.dart';

class LocationService {
  final FirestoreService _fs;
  final Geocoding _geocoding = Geocoding();
  LocationService(this._fs);

  /// Returns distance in km between two GeoPoints.
  static double distanceBetween(GeoPoint a, GeoPoint b) {
    return Geolocator.distanceBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        ) /
        1000;
  }

  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  /// Gets current GPS position and writes it to Firestore.
  Future<GeoPoint?> updateCurrentLocation(String uid) async {
    try {
      final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.medium,
              forceLocationManager: true,
              timeLimit: const Duration(seconds: 20),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            );
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      final gp = GeoPoint(pos.latitude, pos.longitude);
      await _fs.updateDoc('users/$uid', {
        'currentLocation': gp,
        'currentLocationUpdatedAt': FieldValue.serverTimestamp(),
        'locationEnabled': true,
      });
      return gp;
    } catch (_) {
      return null;
    }
  }

  /// Turns the user's saved city into an approximate coordinate for the
  /// dashboard fallback. Uses the platform geocoder, so no API key is stored.
  Future<GeoPoint?> geocodeHomeCity(String city) async {
    final query = city.trim();
    if (query.isEmpty) return null;
    try {
      final matches = await _geocoding.locationFromAddress(query)
          .timeout(const Duration(seconds: 12));
      if (matches.isEmpty) return null;
      return GeoPoint(matches.first.latitude, matches.first.longitude);
    } catch (e) {
      debugPrint('Home city geocoding failed: $e');
      return null;
    }
  }

  Future<void> disableLocation(String uid) => _fs.updateDoc('users/$uid', {
    'locationEnabled': false,
    'currentLocation': null,
  });
}
