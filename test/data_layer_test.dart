import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zing/app/session_controller.dart';
import 'package:zing/core/models/capsule_model.dart';
import 'package:zing/core/models/couple_model.dart';
import 'package:zing/core/models/memory_model.dart';
import 'package:zing/data/repositories/capsule_repository.dart';
import 'package:zing/data/repositories/couple_repository.dart';
import 'package:zing/data/repositories/memory_repository.dart';
import 'package:zing/data/repositories/pairing_repository.dart';
import 'package:zing/data/repositories/user_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late UserRepository users;
  late CoupleRepository couples;
  late PairingRepository pairing;

  setUp(() async {
    db = FakeFirebaseFirestore();
    users = UserRepository(db);
    couples = CoupleRepository(db);
    pairing = PairingRepository(users: users, couples: couples, db: db);
    for (final uid in ['alice', 'bob']) {
      await users.createIfMissing(
          uid: uid, email: '$uid@x.co', authProvider: 'password');
    }
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  Future<String> link() async {
    final code = await pairing.createRoom('alice');
    expect(await pairing.joinRoom(code: code, joinerUid: 'bob'),
        JoinRoomResult.success);
    return (await pairing.resolveActiveCouple('alice'))!;
  }

  group('pairing', () {
    test('creator and joiner end up in the same couple', () async {
      final id = await link();
      expect((await users.fetch('alice'))!.coupleId, id);
      expect((await users.fetch('bob'))!.coupleId, id);
      expect((await couples.fetch(id))!.memberUids, ['alice', 'bob']);
    });

    test('rejects unknown, own, used and expired codes', () async {
      expect(await pairing.joinRoom(code: '000000', joinerUid: 'bob'),
          JoinRoomResult.notFound);
      final code = await pairing.createRoom('alice');
      expect(await pairing.joinRoom(code: code, joinerUid: 'alice'),
          JoinRoomResult.selfJoin);
      await pairing.joinRoom(code: code, joinerUid: 'bob');
      expect(await pairing.joinRoom(code: code, joinerUid: 'carol'),
          JoinRoomResult.alreadyLinked);
      final old = await pairing.createRoom('alice');
      await db.doc('rooms/$old').update({'expiresAt': Timestamp(0, 0)});
      expect(await pairing.joinRoom(code: old, joinerUid: 'bob'),
          JoinRoomResult.expired);
    });

    test('an unlinked couple is cleared and never re-claimed', () async {
      final id = await link();
      await couples.unlink(id: id, myUid: 'alice');
      expect((await users.fetch('alice'))!.coupleId, isNull);
      expect(await pairing.resolveActiveCouple('alice'), isNull);
      expect(await pairing.resolveActiveCouple('bob', stored: id), isNull);
      expect((await users.fetch('bob'))!.coupleId, isNull);
    });
  });

  group('SessionController', () {
    SessionController session(String uid) =>
        SessionController(uid: uid, users: users, couples: couples);

    test('loads me, partner and couple, with player roles', () async {
      final id = await link();
      await users.saveProfile('bob', displayName: 'Bob', avatarSpriteId: 'x');
      final s = session('alice');
      await settle();
      expect(s.isReady, isTrue);
      expect(s.coupleId, id);
      expect(s.partnerName, 'BOB');
      expect(s.isPlayerOne, isTrue);
      s.dispose();
    });

    test('ends for both sides on unlink, saying who did it', () async {
      final id = await link();
      final a = session('alice');
      final b = session('bob');
      await settle();
      await couples.unlink(id: id, myUid: 'alice');
      await settle();
      expect(a.end, SessionEnd.unlinkedByMe);
      expect(b.end, SessionEnd.unlinkedByPartner);
      expect((await users.fetch('bob'))!.coupleId, isNull);
      a.dispose();
      b.dispose();
    });
  });

  test('quest: propose, accept keeps the details, clear', () async {
    final id = await link();
    await couples.proposeQuest(id,
        destination: 'DAVAO',
        targetDate: DateTime(2027),
        proposedByUid: 'alice');
    await couples.acceptQuest(id);
    var quest = (await couples.fetch(id))!.reunionQuest;
    expect(quest.status, ReunionQuestStatus.accepted);
    expect(quest.destination, 'DAVAO');
    expect(quest.acceptedAt, isNotNull);
    await couples.clearQuest(id);
    quest = (await couples.fetch(id))!.reunionQuest;
    expect(quest.status, ReunionQuestStatus.none);
    expect(quest.acceptedAt, isNull);
  });

  test('turning location off erases the last position', () async {
    await users.shareLocation('alice', location: const GeoPoint(7, 125));
    expect((await users.fetch('alice'))!.currentLocation, isNotNull);
    await users.stopSharingLocation('alice');
    final me = (await users.fetch('alice'))!;
    expect(me.locationEnabled, isFalse);
    expect(me.currentLocation, isNull);
  });

  group('memories', () {
    MemoryModel entry(String id, DateTime date) => MemoryModel(
        memoryId: id,
        authorUid: 'alice',
        date: date,
        title: id,
        createdAt: DateTime.now());

    test('year window, latest window, malformed documents skipped', () async {
      final repo = MemoryRepository(db);
      await repo.create('c', entry('last', DateTime.utc(2025, 12, 31)));
      await repo.create('c', entry('new', DateTime.utc(2026, 1, 1)));
      await repo.create('c', entry('late', DateTime.utc(2026, 12, 31)));
      await db.doc('couples/c/memories/bad').set(
          {'date': Timestamp.fromDate(DateTime.utc(2026, 5)), 'photoUrls': 7});
      final year = await repo.watchYear('c', 2026).first;
      expect(year.map((m) => m.memoryId), unorderedEquals(['new', 'late']));
      final latest =
          await repo.watchLatest('c', DateTime.utc(2026, 1, 1), limit: 1).first;
      expect(latest.single.memoryId, 'new');
    });

    test('editing a plan leaves its photos and pin alone', () async {
      final repo = MemoryRepository(db);
      await repo.create('c', entry('m', DateTime.utc(2026)));
      await db.doc('couples/c/memories/m').update({
        'photoUrls': ['u'],
      });
      await repo.updateContent('c', 'm',
          type: MemoryEntryType.plan, title: 'T', story: '', tag: 'X');
      final saved = (await repo.watchYear('c', 2026).first).single;
      expect(saved.title, 'T');
      expect(saved.photoUrls, ['u']);
    });
  });

  group('capsules', () {
    test('second dual tap unlocks; cancelled chests leave the list', () async {
      final repo = CapsuleRepository(db);
      for (final id in ['d', 'x']) {
        await repo.create(
            'c',
            CapsuleModel(
                capsuleId: id,
                creatorUid: 'alice',
                title: id,
                triggerMode: CapsuleTriggerMode.dualTapSync,
                dualTapState: DualTapState(),
                createdAt: DateTime.now()));
      }
      await repo.tap('c', 'd', isPlayerOne: true);
      await repo.cancel('c', 'x');
      var list = (await repo.watch('c').first).capsules;
      expect(list.single.status, CapsuleStatus.sealed);
      await repo.tap('c', 'd', isPlayerOne: false);
      list = (await repo.watch('c').first).capsules;
      expect(list.single.status, CapsuleStatus.unlocked);
      expect(list.single.dualTapState!.bothTapped, isTrue);
    });
  });
}
