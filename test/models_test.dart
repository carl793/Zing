import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zing/core/constants/sprite_options.dart';
import 'package:zing/core/models/capsule_model.dart';
import 'package:zing/core/models/couple_model.dart';
import 'package:zing/core/models/room_model.dart';
import 'package:zing/core/models/user_model.dart';

void main() {
  group('UserModel.fromMap', () {
    test('reads a GeoPoint home location', () {
      final user = UserModel.fromMap('u1', {
        'displayName': 'KARL',
        'homeCity': 'DAVAO',
        'homeLocation': GeoPoint(7.07, 125.61),
      });
      expect(user.displayName, 'KARL');
      expect(user.homeCity, 'DAVAO');
      expect(user.homeLocation?.latitude, 7.07);
      expect(user.homeLocation?.longitude, 125.61);
    });

    test('accepts the legacy {name, lat, lng} location map', () {
      final user = UserModel.fromMap('u1', {
        'homeLocation': {'name': 'MANILA', 'lat': 14.6, 'lng': 121.0},
      });
      expect(user.homeCity, 'MANILA');
      expect(user.homeLocation?.latitude, 14.6);
      expect(user.homeLocation?.longitude, 121.0);
    });

    test('fills defaults for a brand-new profile', () {
      final user = UserModel.fromMap('u1', {'coupleId': null});
      expect(user.displayName, '');
      expect(user.coupleId, isNull);
      expect(user.locationEnabled, isFalse);
      expect(user.homeLocation, isNull);
    });
  });

  group('CoupleModel', () {
    final couple = CoupleModel.fromMap('c1', {
      'memberUids': ['p1', 'p2'],
      'pairingCode': '123456',
      'linkedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
      'unitPref': 'mi',
      'reunionQuest': {'status': 'accepted', 'destination': 'DAVAO'},
    });

    test('parses fields, the nested quest and default settings', () {
      expect(couple.unitPref, 'mi');
      expect(couple.status, CoupleStatus.active);
      expect(couple.reunionQuest.status, ReunionQuestStatus.accepted);
      expect(couple.reunionQuest.destination, 'DAVAO');
      expect(couple.settings.reunionAlerts, isTrue);
    });

    test('partnerUid returns the other member', () {
      expect(couple.partnerUid('p1'), 'p2');
      expect(couple.partnerUid('p2'), 'p1');
    });

    // Regression: Settings used to round-trip through a toMap() that stored
    // linkedAt as a DateTime, which fromMap then failed to cast.
    test('copyWith changes only the given fields', () {
      final updated = couple.copyWith(unitPref: 'km');
      expect(updated.unitPref, 'km');
      expect(updated.linkedAt, couple.linkedAt);
      expect(updated.memberUids, couple.memberUids);
      expect(updated.reunionQuest.destination, 'DAVAO');
    });
  });

  group('CapsuleModel.fromMap', () {
    test('falls back to defaults for unknown values', () {
      final capsule = CapsuleModel.fromMap('x', {
        'triggerMode': 'teleport',
        'status': 'melted',
      });
      expect(capsule.triggerMode, CapsuleTriggerMode.dateRelease);
      expect(capsule.status, CapsuleStatus.sealed);
      expect(capsule.isArchived, isFalse);
    });

    test('reads the dual-tap state', () {
      final capsule = CapsuleModel.fromMap('x', {
        'triggerMode': 'dualTapSync',
        'dualTapState': {
          'p1TappedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        },
      });
      expect(capsule.triggerMode, CapsuleTriggerMode.dualTapSync);
      expect(capsule.dualTapState?.p1TappedAt, isNotNull);
      expect(capsule.dualTapState?.bothTapped, isFalse);
    });
  });

  test('RoomModel.isExpired compares against expiresAt', () {
    Map<String, dynamic> room(Duration fromNow) => {
          'createdByUid': 'p1',
          'status': 'pending',
          'createdAt': Timestamp.now(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(fromNow)),
        };
    expect(RoomModel.fromMap('1', room(const Duration(hours: 1))).isExpired,
        isFalse);
    expect(RoomModel.fromMap('1', room(const Duration(hours: -1))).isExpired,
        isTrue);
  });

  test('SpriteOptions.resolve handles current, legacy and unknown ids', () {
    expect(SpriteOptions.resolve('monster_guy').label, 'MONSTER GUY');
    expect(SpriteOptions.resolve('\u{1F47B}').label, 'GHOST');
    expect(SpriteOptions.resolve('nope').id, SpriteOptions.fallback);
    expect(SpriteOptions.resolve(null).id, SpriteOptions.fallback);
  });
}
