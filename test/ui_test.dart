import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zing/core/photos/photo_cache.dart';
import 'package:zing/core/photos/photo_carousel.dart';
import 'package:zing/core/photos/photo_viewer.dart';
import 'package:zing/core/photos/pixel_photo.dart';
import 'package:zing/core/services/auth_service.dart';
import 'package:zing/core/services/location_service.dart';
import 'package:zing/core/services/storage_service.dart';
import 'package:zing/core/theme/app_theme.dart';
import 'package:zing/core/utils/date_utils.dart';
import 'package:zing/core/widgets/pixel_button.dart';
import 'package:zing/core/widgets/pixel_clock.dart';
import 'package:zing/core/widgets/pixel_field.dart';
import 'package:zing/core/widgets/pixel_icon.dart';
import 'package:zing/core/widgets/pixel_modal_shell.dart';
import 'package:zing/core/widgets/pixel_toast.dart';
import 'package:zing/data/repositories/capsule_repository.dart';
import 'package:zing/data/repositories/couple_repository.dart';
import 'package:zing/data/repositories/memory_repository.dart';
import 'package:zing/data/repositories/user_repository.dart';
import 'package:zing/features/shell/shell_screen.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
}

class _FakeAuth extends Fake implements AuthService {
  @override
  User? get currentUser => _FakeUser();
}

class _NoLocation extends LocationService {
  @override
  Future<LocationAccess> access({bool request = false}) async =>
      LocationAccess.denied;
}

/// A plain picture of the given size.
Future<Uint8List> _picture(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(const Color(0xFF336699), BlendMode.src);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  setUp(() {
    // The voice recorder is made with the chest form.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (_) async => null,
    );
  });

  void useScreen(WidgetTester tester, Size size) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester, [int rounds = 5]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Widget app(Widget home, {double textScale = 1}) => MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      );

  group('photos', () {
    const shapes = {'wide': (800, 300), 'square': (400, 400), 'tall': (300, 900)};

    Future<void> showCarousel(WidgetTester tester) async {
      useScreen(tester, const Size(400, 800));
      final photos = (await tester.runAsync(() async => [
            for (final (w, h) in shapes.values)
              PhotoItem.bytes(await _picture(w, h)),
          ]))!;
      await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(child: PhotoCarousel(photos: photos)),
      )));
      await settle(tester);
    }

    Size frame(WidgetTester tester) => tester.getSize(find.byType(PageView));

    /// The sharp photo on screen, not its mosaic or thumbnail.
    Finder sharp() => find.descendant(
          of: find.byType(PageView),
          matching: find.byWidgetPredicate(
              (w) => w is RawImage && w.fit == BoxFit.contain),
        );

    testWidgets('every shape is shown whole, in a frame that fits it',
        (tester) async {
      await showCarousel(tester);
      final heights = <double>[];
      for (final (w, h) in shapes.values) {
        final box = frame(tester);
        heights.add(box.height);
        final images = tester.widgetList<RawImage>(sharp()).toList();
        expect(images, isNotEmpty);
        // The picture on this page keeps its own proportions...
        final own = images.where((i) =>
            ((i.image!.width / i.image!.height) - w / h).abs() < 0.02);
        expect(own, isNotEmpty, reason: '$w x $h');
        // ...and contain never crops, so it only has to have room.
        expect(box.height, greaterThanOrEqualTo(box.width * 0.5 - 1));
        expect(box.height, lessThanOrEqualTo(400));

        final next = find.bySemanticsLabel('Next photo');
        await tester.tap(next, warnIfMissed: false);
        await settle(tester, 6);
      }
      expect(heights[0], lessThan(heights[1]));
      expect(heights[1], lessThan(heights[2]));
    });

    testWidgets('the arrows stay where they are as the frame changes',
        (tester) async {
      await showCarousel(tester);
      final before = tester.getCenter(find.bySemanticsLabel('Next photo'));
      await tester.tap(find.bySemanticsLabel('Next photo'));
      await settle(tester, 6);
      expect(tester.getCenter(find.bySemanticsLabel('Next photo')), before);
    });

    testWidgets('opens full screen on the same photo and returns to the last',
        (tester) async {
      await showCarousel(tester);
      await tester.tap(find.byType(PhotoMosaic).first, warnIfMissed: false);
      await settle(tester);
      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);

      await tester.fling(find.byType(PhotoViewer), const Offset(-300, 0), 1500);
      await settle(tester, 8);
      expect(find.text('2/3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Rotate'));
      await settle(tester);
      expect(
        tester
            .widgetList<RotatedBox>(find.byType(RotatedBox))
            .any((box) => box.quarterTurns == 1),
        isTrue,
      );

      // Dragging it away closes it.
      await tester.drag(find.byType(PhotoViewer), const Offset(0, 300));
      await settle(tester, 8);
      expect(find.byType(PhotoViewer), findsNothing);
      expect(find.text('PHOTO 2 OF 3'), findsOneWidget);
    });

    testWidgets('double tap zooms in and out', (tester) async {
      await showCarousel(tester);
      await tester.tap(find.byType(PhotoMosaic).first, warnIfMissed: false);
      await settle(tester);

      Future<double> doubleTap() async {
        final center = tester.getCenter(find.byType(PhotoViewer));
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(center);
        await settle(tester, 6);
        return tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
            .transformationController!
            .value
            .getMaxScaleOnAxis();
      }

      expect(await doubleTap(), closeTo(2.5, 0.01));
      expect(await doubleTap(), closeTo(1, 0.01));
    });

    test('photos are asked for at the size they are shown', () {
      const item = PhotoItem.url(
          'https://res.cloudinary.com/x/image/upload/v1/a.jpg');
      final provider = item.sized(400) as ResizeImage;
      expect(provider.width, 400);
      expect((provider.imageProvider as CachedPhoto).url, contains('w_400'));
    });
  });

  group('sheets', () {
    Future<void> open(
      WidgetTester tester, {
      required TextEditingController text,
    }) async {
      useScreen(tester, const Size(400, 800));
      await tester.pumpWidget(app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPixelSheet<void>(
              context: context,
              isForm: true,
              builder: (_) => PixelModalShell(
                title: 'FORM',
                hasUnsavedWork: () => text.text.isNotEmpty,
                child: Column(children: [
                  PixelField(hint: 'WRITE', controller: text),
                  Builder(
                    builder: (inner) => PixelButton(
                      label: 'FAIL',
                      onPressed: () => showPixelToast(inner, 'IT FAILED'),
                    ),
                  ),
                ]),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      )));
      await tester.tap(find.text('go'));
      await settle(tester);
      expect(find.text('FORM'), findsOneWidget);
    }

    Future<void> back(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await settle(tester);
    }

    testWidgets('an untouched form just closes', (tester) async {
      await open(tester, text: TextEditingController());
      await back(tester);
      expect(find.text('FORM'), findsNothing);
    });

    testWidgets('a form with work in it asks before closing', (tester) async {
      await open(tester, text: TextEditingController());
      await tester.enterText(find.byType(TextField), 'our story');
      await back(tester);
      expect(find.text('NOT SAVED YET'), findsOneWidget);
      await tester.tap(find.text('KEEP WRITING'));
      await settle(tester);
      expect(find.text('our story'), findsOneWidget);

      // Tapping beside the sheet and the close key ask too.
      await tester.tapAt(const Offset(200, 20));
      await settle(tester);
      expect(find.text('NOT SAVED YET'), findsOneWidget);
      await tester.tap(find.text('DISCARD'));
      await settle(tester);
      expect(find.text('FORM'), findsNothing);
    });

    testWidgets('a message shows above the sheet, then leaves', (tester) async {
      await open(tester, text: TextEditingController());
      await tester.tap(find.text('FAIL'));
      await settle(tester);
      expect(find.text('IT FAILED').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(find.text('IT FAILED'), findsNothing);
    });

    testWidgets('the sheet and its keys fit above the keyboard on a small phone',
        (tester) async {
      await open(tester, text: TextEditingController());
      tester.view
        ..physicalSize = const Size(320, 568)
        ..viewInsets = const FakeViewPadding(bottom: 280);
      await settle(tester);
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(PixelModalShell));
      expect(tester.getRect(find.text('FORM')).bottom, lessThan(288));
      expect(sheet.top, greaterThanOrEqualTo(0));
    });
  });

  group('buttons', () {
    testWidgets('go down without moving anything, and only when usable',
        (tester) async {
      var presses = 0;
      Future<void> show({bool busy = false, bool enabled = true}) =>
          tester.pumpWidget(app(Scaffold(
            body: Center(
              child: PixelButton(
                label: 'PRESS',
                icon: PixelIcons.heart,
                busy: busy,
                onPressed: enabled ? () => presses++ : null,
              ),
            ),
          )));

      await show();
      final size = tester.getSize(find.byType(PixelButton));
      final up = tester.getCenter(find.text('PRESS'));
      expect(size.height, greaterThanOrEqualTo(48));

      final finger = await tester.startGesture(up);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getSize(find.byType(PixelButton)), size);
      expect(tester.getCenter(find.text('PRESS')).dy, greaterThan(up.dy));
      await finger.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getCenter(find.text('PRESS')), up);
      expect(presses, 1);

      await show(busy: true);
      await tester.tap(find.text('PRESS'));
      await show(enabled: false);
      await tester.tap(find.text('PRESS'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(presses, 1);
    });
  });

  group('shell', () {
    late FakeFirebaseFirestore db;

    Future<void> seed({Map<String, Object?>? quest, String name = 'MIKA'}) async {
      db = FakeFirebaseFirestore();
      for (final (uid, shown) in [('me', name), ('you', name)]) {
        await db.doc('users/$uid').set({
          'displayName': shown,
          'avatarSpriteId': 'monster_guy',
          'coupleId': 'c',
          'homeCity': 'A CITY WITH QUITE A LONG NAME, PHILIPPINES',
          'homeLocation': const GeoPoint(7, 125),
        });
      }
      await db.doc('couples/c').set({
        'memberUids': ['me', 'you'],
        'pairingCode': '123456',
        'status': 'active',
        'linkedAt': Timestamp.now(),
        'reunionQuest': ?quest,
      });
      final today = ZingDateUtils.today();
      for (final (i, by) in ['me', 'you'].indexed) {
        await db.doc('couples/c/memories/m$i').set({
          'authorUid': by,
          'date': Timestamp.fromDate(today),
          'entryType': 'memory',
          'title': 'A memory with a title that is long enough to wrap twice',
          'tagCategory': 'SPORTING EVENT',
        });
      }
      for (final (i, status) in ['sealed', 'unlocked'].indexed) {
        await db.doc('couples/c/capsules/k$i').set({
          'creatorUid': 'you',
          'title': 'A chest with a name that is long enough to wrap twice',
          'triggerMode': i == 0 ? 'dualTapSync' : 'dateRelease',
          'unlockDate': Timestamp.now(),
          'status': status,
          'createdAt': Timestamp.now(),
        });
      }
    }

    Future<void> show(
      WidgetTester tester, {
      Size size = const Size(360, 780),
      double textScale = 1,
      Map<String, Object?>? quest,
      String name = 'MIKA',
    }) async {
      useScreen(tester, size);
      await tester.runAsync(() => seed(quest: quest, name: name));
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => _FakeAuth()),
          Provider(create: (_) => UserRepository(db)),
          Provider(create: (_) => CoupleRepository(db)),
          Provider(create: (_) => MemoryRepository(db)),
          Provider(create: (_) => CapsuleRepository(db)),
          Provider(create: (_) => StorageService()),
          Provider<LocationService>(create: (_) => _NoLocation()),
        ],
        child: app(const ShellScreen(), textScale: textScale),
      ));
      await settle(tester);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 2);
    }

    testWidgets('LOG MEMORY and LOCK CHEST start what they say', (tester) async {
      await show(tester);
      await tester.tap(find.text('LOCK CHEST'));
      await settle(tester);
      expect(find.text('SEAL CHEST'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('SEAL CHEST'), findsNothing);

      // Both partners logged today, so it asks whose to open.
      await tester.tap(find.text('HOME'));
      await settle(tester);
      await tester.tap(find.text('LOG MEMORY'));
      await settle(tester);
      expect(find.text(ZingDateUtils.shortLabel(ZingDateUtils.today())),
          findsOneWidget);

      // It only starts once: coming back by the tab doesn't repeat it.
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('HOME'));
      await settle(tester);
      await tester.tap(find.text('CALENDAR').first);
      await settle(tester);
      expect(find.byType(PixelModalShell), findsNothing);
      await close(tester);
    });

    testWidgets('a quest whose day has come can be completed', (tester) async {
      await show(tester, size: const Size(360, 1400), quest: {
        'status': 'accepted',
        'destination': 'DAVAO',
        'targetDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 1))),
        'proposedByUid': 'you',
      });
      expect(find.text("IT'S THE DAY!"), findsOneWidget);
      await tester.tap(find.text('QUEST COMPLETE'));
      await settle(tester);
      expect(find.text('NO QUEST YET'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await close(tester);
    });

    testWidgets('a chest waiting for my tap is marked on the tab and at home',
        (tester) async {
      await show(tester);
      expect(find.text('WAITING FOR YOUR TAP'), findsOneWidget);
      expect(find.byType(PixelDot), findsOneWidget);
      await tester.runAsync(() => db.doc('couples/c/capsules/k0').update({
            'dualTapState': {'p1TappedAt': Timestamp.now()},
          }));
      await settle(tester);
      expect(find.text('WAITING FOR YOUR TAP'), findsNothing);
      expect(find.byType(PixelDot), findsNothing);
      await close(tester);
    });

    /// Nothing is written smaller than the pixel font can be read at.
    void expectReadable(WidgetTester tester, String where) {
      for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
        text.text.visitChildren((span) {
          final size = span.style?.fontSize;
          if (span is TextSpan && (span.text ?? '').trim().isNotEmpty) {
            expect(size, greaterThanOrEqualTo(8),
                reason: '"${span.text}" on $where');
          }
          return true;
        });
      }
    }

    // Small phone with large text and long names; then a normal phone.
    for (final (size, scale) in [
      (const Size(320, 568), 1.25),
      (const Size(412, 915), 1.0),
    ]) {
      testWidgets('every tab and form fits $size at text size $scale',
          (tester) async {
        await show(
          tester,
          size: size,
          textScale: scale,
          name: 'WOLFESCHLEGELSTEINER',
          quest: {
            'status': 'accepted',
            'destination': 'A PLACE WITH QUITE A LONG NAME',
            'targetDate': Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 400))),
            'proposedByUid': 'you',
          },
        );
        void check(String where) {
          expect(tester.takeException(), isNull, reason: where);
          expectReadable(tester, where);
        }

        check('HOME');
        for (final tab in ['CALENDAR', 'VAULT', 'CONFIG']) {
          await tester.tap(find.text(tab).last);
          await settle(tester);
          check(tab);
        }
        await tester.tap(find.text('VAULT').last);
        await settle(tester);
        await tester.tap(find.text('NEW CHEST'));
        await settle(tester);
        check('the chest form');
        await tester.binding.handlePopRoute();
        await settle(tester);
        await tester.tap(find.bySemanticsLabel('Filter chests'));
        await settle(tester);
        check('the filters');
        await tester.binding.handlePopRoute();
        await settle(tester);

        await tester.tap(find.text('CALENDAR').last);
        await settle(tester);
        await tester.tap(find.text('LOG TODAY'));
        await settle(tester);
        check('the day picker');
        await tester.tap(find
            .textContaining('A memory with a title')
            .hitTestable()
            .first);
        await settle(tester);
        check('a memory');
        await close(tester);
      });
    }
  });

  testWidgets('idle animations tick slowly, and not at all out of sight',
      (tester) async {
    var ticks = 0;
    Future<void> show({bool visible = true, bool still = false}) =>
        tester.pumpWidget(MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: TickerMode(
            enabled: visible,
            child: PixelClock(
              step: const Duration(milliseconds: 100),
              builder: (_, tick) => ValueListenableBuilder(
                valueListenable: tick,
                builder: (_, value, _) {
                  ticks = value;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ));

    await show();
    await tester.pump(const Duration(milliseconds: 1050));
    expect(ticks, 10);
    await show(visible: false);
    await tester.pump(const Duration(seconds: 2));
    expect(ticks, 10);
    await show(still: true);
    await tester.pump(const Duration(seconds: 2));
    expect(ticks, 10);
    await show();
    await tester.pump(const Duration(milliseconds: 250));
    expect(ticks, 12);

    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(ticks, 12);
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(milliseconds: 250));
    expect(ticks, 14);
    await tester.pumpWidget(const SizedBox());
  });

  test('time left reads in its largest units', () {
    final now = DateTime(2026, 1, 1);
    String left(Duration d) => ZingDateUtils.timeLeft(now.add(d), now: now);
    expect(left(const Duration(days: 12, hours: 5)), '12 DAYS');
    expect(left(const Duration(hours: 30)), '1 DAY 6H');
    expect(left(const Duration(hours: 5, minutes: 20)), '5H 20M');
    expect(left(const Duration(minutes: 9)), '9 MIN');
    expect(left(const Duration(seconds: 9)), 'UNDER 1 MIN');
    expect(ZingDateUtils.timeLabel(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    expect(ZingDateUtils.timeLabel(DateTime(2026, 1, 1, 15, 30)), '3:30 PM');
  });
}
