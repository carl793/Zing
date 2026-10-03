import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_service.dart';

class LocationService {
  final FirestoreService _fs;
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
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.medium),
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

  Future<void> disableLocation(String uid) => _fs.updateDoc('users/$uid', {
    'locationEnabled': false,
    'currentLocation': null,
  });
}
