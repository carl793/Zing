import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zing/app/session_controller.dart';
import 'package:zing/core/models/capsule_model.dart';
import 'package:zing/core/permissions/permission_flows.dart';
import 'package:zing/core/services/location_service.dart';
import 'package:zing/core/services/storage_service.dart';
import 'package:zing/core/theme/app_theme.dart';
import 'package:zing/core/utils/date_utils.dart';
import 'package:zing/core/widgets/remote_photo.dart';
import 'package:zing/data/repositories/capsule_repository.dart';
import 'package:zing/data/repositories/couple_repository.dart';
import 'package:zing/data/repositories/memory_repository.dart';
import 'package:zing/data/repositories/user_repository.dart';
import 'package:zing/features/calendar/controllers/calendar_controller.dart';
import 'package:zing/features/calendar/screens/calendar_screen.dart';
import 'package:zing/features/dashboard/controllers/dashboard_controller.dart';
import 'package:zing/features/dashboard/widgets/distance_card.dart';
import 'package:zing/features/settings/controllers/settings_controller.dart';
import 'package:zing/features/settings/screens/settings_screen.dart';
import 'package:zing/features/vault/controllers/vault_controller.dart';
import 'package:zing/features/vault/screens/vault_screen.dart';

/// A phone whose location answers are set by the test.
class FakeLocation extends LocationService {
  LocationAccess now = LocationAccess.denied;
  LocationAccess afterPrompt = LocationAccess.granted;
  GeoPoint? position = const GeoPoint(7, 125);
  GeoPoint? city;
  int prompts = 0;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> access({bool request = false}) async {
    if (request && now == LocationAccess.denied) {
      prompts++;
      now = afterPrompt;
    }
    return now;
  }

  @override
  Future<GeoPoint?> currentPosition() async => position;
  @override
  Future<GeoPoint?> findCity(String city) async => this.city;
  @override
  Future<void> openAppSettings() async => settingsOpened++;
  @override
  Future<void> openLocationSettings() async => settingsOpened++;
}

void main() {
  late FakeFirebaseFirestore db;
  late UserRepository users;
  late CoupleRepository couples;
  late SessionController session;
  late FakeLocation location;

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

  Future<void> setUpCouple() async {
    db = FakeFirebaseFirestore();
    users = UserRepository(db);
    couples = CoupleRepository(db);
    location = FakeLocation();
    for (final uid in ['me', 'you']) {
      await db.doc('users/$uid').set({
        'displayName': uid,
        'avatarSpriteId': 'monster_guy',
        'coupleId': 'c',
        'homeCity': '$uid CITY',
        'locationEnabled': false,
      });
    }
    await db.doc('couples/c').set({
      'memberUids': ['me', 'you'],
      'pairingCode': '123456',
      'status': 'active',
      'linkedAt': Timestamp.now(),
    });
    session = SessionController(uid: 'me', users: users, couples: couples);
    await settle();
  }

  DashboardController dashboard() => DashboardController(
        session: session,
        users: users,
        couples: couples,
        memories: MemoryRepository(db),
        location: location,
      );

  Future<void> locate(String uid, GeoPoint point, {Duration age = Duration.zero}) =>
      db.doc('users/$uid').update({
        'locationEnabled': true,
        'currentLocation': point,
        'currentLocationUpdatedAt':
            Timestamp.fromDate(DateTime.now().subtract(age)),
      });

  group('dashboard distance', () {
    test('only the partner shares: says whose location is missing', () async {
      await setUpCouple();
      await locate('you', const GeoPoint(7, 125));
      await db.doc('users/me').update({'homeLocation': const GeoPoint(8, 125)});
      await settle();
      final ctrl = dashboard();
      expect(ctrl.distanceState, DistanceState.apart);
      expect(ctrl.isSharing, isFalse);
      expect(ctrl.approximateReason, 'APPROX. YOUR LOCATION IS NOT LIVE');
      ctrl.dispose();
    });

    test('a day-old position is approximate and never "together"', () async {
      await setUpCouple();
      location.now = LocationAccess.granted;
      await locate('me', const GeoPoint(7, 125));
      await locate('you', const GeoPoint(7, 125), age: const Duration(days: 1));
      await settle();
      final ctrl = dashboard();
      await settle();
      expect(ctrl.distanceState, DistanceState.apart);
      expect(ctrl.approximateReason, "APPROX. YOU'S LOCATION IS NOT LIVE");
      await locate('you', const GeoPoint(7, 125));
      await settle();
      expect(ctrl.distanceState, DistanceState.together);
      ctrl.dispose();
    });

    test('access revoked in settings is reported, sharing resumes after', () async {
      await setUpCouple();
      location.now = LocationAccess.blocked;
      await db.doc('users/me').update({'locationEnabled': true});
      await settle();
      final ctrl = dashboard();
      await settle();
      expect(ctrl.sharingBlocked, isTrue);
      location.now = LocationAccess.granted;
      await ctrl.refreshLocation(onlyIfStale: true);
      expect(ctrl.sharingBlocked, isFalse);
      expect((await users.fetch('me'))!.currentLocation, isNotNull);
      ctrl.dispose();
    });

    test('no position available offers a retry', () async {
      await setUpCouple();
      location
        ..now = LocationAccess.granted
        ..position = null;
      final ctrl = dashboard();
      await ctrl.startSharing();
      await settle();
      expect(ctrl.positionUnavailable, isTrue);
      ctrl.dispose();
    });
  });

  group('location permission', () {
    Future<bool?> run(WidgetTester tester, String? tap) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await ensureLocationAccess(context, location),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      if (tap != null) {
        await tester.ensureVisible(find.text(tap));
        await tester.tap(find.text(tap));
        await tester.pumpAndSettle();
      }
      return result;
    }

    setUp(() => location = FakeLocation());

    testWidgets('explains first, then asks the system', (tester) async {
      expect(await run(tester, '[ CONTINUE ]'), isTrue);
      expect(location.prompts, 1);
    });

    testWidgets('"not now" never reaches the system prompt', (tester) async {
      expect(await run(tester, '[ NOT NOW ]'), isFalse);
      expect(location.prompts, 0);
    });

    testWidgets('a refusal is accepted with a fallback', (tester) async {
      location.afterPrompt = LocationAccess.denied;
      expect(await run(tester, '[ CONTINUE ]'), isFalse);
      expect(find.textContaining('HOME CITY'), findsOneWidget);
    });

    for (final access in [LocationAccess.blocked, LocationAccess.serviceOff]) {
      testWidgets('$access leads to settings', (tester) async {
        location.now = access;
        expect(await run(tester, '[ OPEN SETTINGS ]'), isFalse);
        expect(location.settingsOpened, 1);
        expect(location.prompts, 0);
      });
    }

    testWidgets('already granted asks nothing', (tester) async {
      location.now = LocationAccess.granted;
      expect(await run(tester, null), isTrue);
    });
  });

  group('vault', () {
    Future<void> chest(String id, Map<String, dynamic> extra) =>
        db.doc('couples/c/capsules/$id').set({
          'creatorUid': 'me',
          'title': id,
          'triggerMode': 'dateRelease',
          'status': 'sealed',
          'createdAt': Timestamp.now(),
          ...extra,
        });

    test('opens due chests only, filters, hides cancelled', () async {
      await setUpCouple();
      final repo = CapsuleRepository(db);
      DateTime at(int h) => DateTime.now().add(Duration(hours: h));
      await chest('due', {'unlockDate': Timestamp.fromDate(at(-1))});
      await chest('later', {'unlockDate': Timestamp.fromDate(at(5))});
      await chest('gone', {'status': 'cancelled'});
      await chest('theirs', {'creatorUid': 'you', 'triggerMode': 'dualTapSync'});
      final ctrl = VaultController(session, repo, StorageService());
      await settle();
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.totalCount, 3);
      expect(ctrl.capsuleById('due')!.status, CapsuleStatus.unlocked);
      expect(ctrl.capsuleById('later')!.status, CapsuleStatus.sealed);
      ctrl.setSenderFilter(VaultSenderFilter.byPartner);
      expect(ctrl.capsules.single.capsuleId, 'theirs');
      expect(await ctrl.cancelCapsule(ctrl.capsules.single), isNotNull);
      ctrl.dispose();
    });
  });

  group('calendar', () {
    Future<void> entry(String id, DateTime day, {String type = 'memory'}) =>
        db.doc('couples/c/memories/$id').set({
          'authorUid': 'me',
          'date': Timestamp.fromDate(day),
          'entryType': type,
          'title': id,
        });

    test('stats, month browsing, and today while viewing another year', () async {
      await setUpCouple();
      final today = ZingDateUtils.today();
      await entry('a', today);
      await entry('b', DateTime.utc(today.year - 1, 3, 4));
      final ctrl =
          CalendarController(session, MemoryRepository(db), StorageService());
      await settle();
      expect(ctrl.daysTogetherThisMonth, 1);
      expect(ctrl.daysSinceLastMeetup, 0);
      ctrl.jumpTo(today.year - 1, 3);
      await settle();
      expect(ctrl.daysTogetherThisMonth, 1);
      expect(ctrl.memoriesOn(DateTime.utc(today.year - 1, 3, 4)), hasLength(1));
      expect(ctrl.memoriesOn(today).single.memoryId, 'a');
      ctrl.dispose();
    });

    test("a partner's entry can't be changed", () async {
      await setUpCouple();
      await entry('a', ZingDateUtils.today());
      await db.doc('couples/c/memories/a').update({'authorUid': 'you'});
      final ctrl =
          CalendarController(session, MemoryRepository(db), StorageService());
      await settle();
      final memory = ctrl.memoriesOn(ZingDateUtils.today()).single;
      expect(await ctrl.deleteMemory(memory), isNotNull);
      expect(ctrl.memoriesOn(ZingDateUtils.today()), hasLength(1));
      ctrl.dispose();
    });
  });

  test('settings: an unfindable city is saved and reported', () async {
    await setUpCouple();
    final ctrl = SettingsController(
        session: session, users: users, couples: couples, location: location);
    var notFound = false;
    Future<String?> save(String city) => ctrl.saveProfile(
        name: 'ME',
        spriteId: 'monster_guy',
        city: city,
        onCityNotFound: () => notFound = true);
    expect(await save('ATLANTIS'), isNull);
    await settle();
    expect(notFound, isTrue);
    expect(session.me!.homeCity, 'ATLANTIS');
    location.city = const GeoPoint(1, 2);
    await save('DAVAO');
    await settle();
    expect(session.me!.homeLocation, const GeoPoint(1, 2));
    expect(await ctrl.setUnit('mi'), isNull);
    await settle();
    expect(ctrl.unit, 'mi');
    ctrl.dispose();
  });

  test('photo urls are resized only for Cloudinary images', () {
    expect(sizedPhotoUrl('https://res.cloudinary.com/x/image/upload/v1/a.jpg', 400),
        'https://res.cloudinary.com/x/image/upload/c_limit,w_400,q_auto/v1/a.jpg');
    expect(sizedPhotoUrl('https://example.com/a.jpg', 400),
        'https://example.com/a.jpg');
  });

  // Every tab builds and lays out, on a small phone and a large one.
  for (final size in [const Size(320, 640), const Size(412, 915)]) {
    testWidgets('screens lay out at $size', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(setUpCouple);

      Future<void> show(Widget child) async {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: session),
            Provider.value(value: users),
            Provider.value(value: couples),
            Provider.value(value: MemoryRepository(db)),
            Provider.value(value: CapsuleRepository(db)),
            Provider.value(value: StorageService()),
            Provider<LocationService>.value(value: location),
          ],
          child: MaterialApp(theme: AppTheme.dark, home: child),
        ));
        await tester.runAsync(settle);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$child');
      }

      final ctrl = dashboard();
      await show(Scaffold(
        body: SingleChildScrollView(child: DistanceCard(controller: ctrl)),
      ));
      expect(find.text('[ SHARE MY LOCATION ]'), findsOneWidget);
      await show(const CalendarScreen());
      await show(const VaultScreen());
      await show(const SettingsScreen());
      expect(find.text('SHARE MY LOCATION'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      ctrl.dispose();
    });
  }
}
