import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/user_model.dart';
import '../firestore_helpers.dart';

/// Player profiles (`users/{uid}`). An account may only write its own.
class UserRepository {
  UserRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Json> _doc(String uid) => _db.collection('users').doc(uid);

  UserModel? _parse(DocumentSnapshot<Json> snap) {
    final data = snap.data();
    return data == null ? null : UserModel.fromMap(snap.id, data);
  }

  Stream<UserModel?> watch(String uid) => _doc(uid).snapshots().map(_parse);

  Future<UserModel?> fetch(String uid) async => _parse(await _doc(uid).get());

  Future<void> createIfMissing({
    required String uid,
    required String email,
    required String authProvider,
  }) async {
    if ((await _doc(uid).get()).exists) return;
    await _doc(uid).set({
      'email': email,
      'displayName': '',
      'avatarSpriteId': '',
      'authProvider': authProvider,
      'coupleId': null,
      'locationEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Saves the name and sprite, and the home city when given. When the city
  /// changed, [clearHomeLocation] drops the old city's coordinates until the
  /// new ones are known.
  Future<void> saveProfile(
    String uid, {
    required String displayName,
    required String avatarSpriteId,
    String? homeCity,
    bool clearHomeLocation = false,
  }) =>
      _merge(uid, {
        'displayName': displayName,
        'avatarSpriteId': avatarSpriteId,
        'homeCity': ?homeCity,
        if (clearHomeLocation) 'homeLocation': FieldValue.delete(),
      });

  Future<void> setHomeLocation(String uid, GeoPoint location) =>
      _merge(uid, {'homeLocation': location});

  Future<void> shareLocation(String uid, {GeoPoint? location}) => _merge(uid, {
        'locationEnabled': true,
        if (location != null) ...{
          'currentLocation': location,
          'currentLocationUpdatedAt': FieldValue.serverTimestamp(),
        },
      });

  /// Turns sharing off and erases the last shared position.
  Future<void> stopSharingLocation(String uid) => _merge(uid, {
        'locationEnabled': false,
        'currentLocation': FieldValue.delete(),
        'currentLocationUpdatedAt': FieldValue.delete(),
      });

  /// Links this account to a couple, or clears the link with null.
  Future<void> setCoupleId(String uid, String? coupleId) =>
      _merge(uid, {'coupleId': coupleId});

  Future<void> _merge(String uid, Json data) =>
      settleWrite(_doc(uid).set(data, SetOptions(merge: true)));
}
