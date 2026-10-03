import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String avatarSpriteId;
  final String authProvider;
  final String? coupleId;
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
        homeLocation: data['homeLocation'] as GeoPoint?,
        currentLocation: data['currentLocation'] as GeoPoint?,
        currentLocationUpdatedAt: (data['currentLocationUpdatedAt'] as Timestamp?)?.toDate(),
        locationEnabled: data['locationEnabled'] ?? false,
        fcmToken: data['fcmToken'],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'avatarSpriteId': avatarSpriteId,
        'authProvider': authProvider,
        'coupleId': coupleId,
        if (homeLocation != null) 'homeLocation': homeLocation,
        if (currentLocation != null) 'currentLocation': currentLocation,
        if (currentLocationUpdatedAt != null)
          'currentLocationUpdatedAt': Timestamp.fromDate(currentLocationUpdatedAt!),
        'locationEnabled': locationEnabled,
        'fcmToken': fcmToken,
      };
}