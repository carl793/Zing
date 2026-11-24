import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zing/core/services/auth_service.dart';
import 'package:zing/core/services/location_service.dart';
import 'package:zing/core/services/storage_service.dart';
import 'package:zing/core/theme/app_theme.dart';
import 'package:zing/data/repositories/capsule_repository.dart';
import 'package:zing/data/repositories/couple_repository.dart';
import 'package:zing/data/repositories/memory_repository.dart';
import 'package:zing/data/repositories/user_repository.dart';
import 'package:zing/features/shell/shell_screen.dart';
import 'package:zing/features/vault/screens/vault_screen.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
}

class _FakeAuth extends Fake implements AuthService {
  @override
  User? get currentUser => _FakeUser();
}

void main() {
  late FakeFirebaseFirestore db;

  Future<void> chest(String id, DateTime unlockDate) =>
      db.doc('couples/c/capsules/$id').set({
        'creatorUid': 'you',
        'title': id,
        'triggerMode': 'dateRelease',
        'unlockDate': Timestamp.fromDate(unlockDate),
        'status': 'sealed',
        'createdAt': Timestamp.now(),
      });

  Future<String> statusOf(WidgetTester tester, String id) async =>
      (await tester.runAsync(
        () async =>
            (await db.doc('couples/c/capsules/$id').get()).data()!['status']
                as String,
      ))!;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
  }

  testWidgets('date chests open without the Vault tab ever being shown',
      (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    db = FakeFirebaseFirestore();
    await tester.runAsync(() async {
      for (final uid in ['me', 'you']) {
        await db.doc('users/$uid').set({
          'displayName': uid,
          'avatarSpriteId': 'monster_guy',
          'coupleId': 'c',
        });
      }
      await db.doc('couples/c').set({
        'memberUids': ['me', 'you'],
        'status': 'active',
        'linkedAt': Timestamp.now(),
      });
      final now = DateTime.now();
      await chest('due', now.subtract(const Duration(minutes: 1)));
      await chest('later', now.add(const Duration(hours: 3)));
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => _FakeAuth()),
        Provider(create: (_) => UserRepository(db)),
        Provider(create: (_) => CoupleRepository(db)),
        Provider(create: (_) => MemoryRepository(db)),
        Provider(create: (_) => CapsuleRepository(db)),
        Provider(create: (_) => StorageService()),
        Provider(create: (_) => LocationService()),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const ShellScreen()),
    ));
    await settle(tester);

    expect(find.byType(VaultScreen, skipOffstage: false), findsNothing);
    expect(await statusOf(tester, 'due'), 'unlocked');
    expect(await statusOf(tester, 'later'), 'sealed');

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
