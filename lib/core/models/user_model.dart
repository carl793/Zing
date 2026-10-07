import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String avatarSpriteId;
  final String authProvider;
  final String? coupleId;
  final String homeCity;
  final GeoPoint? homeLocation;
  final GeoPoint? currentLocation;
  final DateTime? currentLocationUpdatedAt;
  final bool locationEnabled;
  final String? fcmToken;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.avatarSpriteId,
    required this.authProvider,
    this.coupleId,
    this.homeCity = '',
    this.homeLocation,
    this.currentLocation,
    this.currentLocationUpdatedAt,
    this.locationEnabled = false,
    this.fcmToken,
    required this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) => UserModel(
        uid: uid,
        email: data['email'] ?? '',
        displayName: data['displayName'] ?? '',
        avatarSpriteId: data['avatarSpriteId'] ?? '',
        authProvider: data['authProvider'] ?? 'password',
        coupleId: data['coupleId'],
        homeCity: (data['homeCity'] as String?) ??
            _legacyCityName(data['homeLocation']),
        homeLocation: _parseLocation(data['homeLocation']),
        currentLocation: _parseLocation(data['currentLocation']),
        currentLocationUpdatedAt:
            (data['currentLocationUpdatedAt'] as Timestamp?)?.toDate(),
        locationEnabled: data['locationEnabled'] ?? false,
        fcmToken: data['fcmToken'],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  /// A stored location is normally a GeoPoint, but an older settings
  /// save wrote it as a map ({name, lat, lng}). Read both shapes so a
  /// legacy document does not crash every screen that loads the user.
  static GeoPoint? _parseLocation(dynamic value) {
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = (value['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (value['lng'] as num?)?.toDouble() ?? 0.0;
      if (lat != 0 || lng != 0) return GeoPoint(lat, lng);
    }
    return null;
  }

  static String _legacyCityName(dynamic value) {
    if (value is Map) {
      final name = value['name'];
      if (name is String) return name;
    }
    return '';
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'avatarSpriteId': avatarSpriteId,
        'authProvider': authProvider,
        'coupleId': coupleId,
        'homeCity': homeCity,
        if (homeLocation != null) 'homeLocation': homeLocation,
        if (currentLocation != null) 'currentLocation': currentLocation,
        if (currentLocationUpdatedAt != null)
          'currentLocationUpdatedAt': Timestamp.fromDate(currentLocationUpdatedAt!),
        'locationEnabled': locationEnabled,
        'fcmToken': fcmToken,
      };
}