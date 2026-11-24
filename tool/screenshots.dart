// Renders the real screens to PNG files, without a phone or an emulator.
//
//   flutter test tool/screenshots.dart
//   flutter test tool/screenshots.dart --plain-name vault
//
// Images are written to build/screenshots/. Not part of the test suite.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zing/core/services/auth_service.dart';
import 'package:zing/core/services/location_service.dart';
import 'package:zing/core/services/storage_service.dart';
import 'package:zing/core/permissions/permission_sheets.dart';
import 'package:zing/core/photos/photo_cache.dart';
import 'package:zing/core/photos/pixel_photo.dart';
import 'package:zing/core/theme/app_colors.dart';
import 'package:zing/core/theme/app_theme.dart';
import 'package:zing/core/widgets/pixel_icon.dart';
import 'package:zing/core/widgets/splash_screen.dart';
import 'package:zing/data/repositories/capsule_repository.dart';
import 'package:zing/data/repositories/couple_repository.dart';
import 'package:zing/data/repositories/memory_repository.dart';
import 'package:zing/data/repositories/pairing_repository.dart';
import 'package:zing/data/repositories/user_repository.dart';
import 'package:zing/features/auth/controllers/auth_controller.dart';
import 'package:zing/features/auth/screens/forgot_password_screen.dart';
import 'package:zing/features/auth/screens/sprite_select_screen.dart';
import 'package:zing/features/auth/screens/welcome_screen.dart';
import 'package:zing/features/calendar/widgets/month_nav_bar.dart';
import 'package:zing/features/dashboard/widgets/overworld_scene.dart';
import 'package:zing/features/pairing/screens/pairing_screen.dart';
import 'package:zing/features/pairing/screens/pairing_success_screen.dart';
import 'package:zing/features/shell/shell_screen.dart';

const _out = 'build/screenshots';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
  @override
  String? get displayName => null;
  @override
  String? get email => null;
  @override
  List<UserInfo> get providerData => const [];
}

class FakeAuth extends Fake implements AuthService {
  @override
  User? get currentUser => FakeUser();
}

class FakeLocation extends LocationService {
  @override
  Future<LocationAccess> access({bool request = false}) async =>
      LocationAccess.granted;
  @override
  Future<GeoPoint?> currentPosition() async => const GeoPoint(7.07, 125.6);
}

/// Answers every photo request with a drawn picture, so its edges show
/// whether anything is cropped. The size is in the url: .../900x1600.jpg
class _Photos extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client();
}

Future<Uint8List> drawPhoto(String url) async {
  final m = RegExp(r'(\d+)x(\d+)').firstMatch(url);
  var w = double.parse(m?[1] ?? '1200');
  var h = double.parse(m?[2] ?? '900');
  final limit = RegExp(r'w_(\d+)').firstMatch(url);
  if (limit != null) {
    final scale = (double.parse(limit[1]!) / w).clamp(0.0, 1.0);
    w *= scale;
    h *= scale;
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, w, h);
  final seed = url.hashCode.abs() % 360;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
        HSVColor.fromAHSV(1, seed.toDouble(), .55, .95).toColor(),
        HSVColor.fromAHSV(1, (seed + 60) % 360, .7, .45).toColor(),
      ]),
  );
  canvas.drawCircle(Offset(w * .7, h * .3), w * .1,
      Paint()..color = const Color(0xFFFFF3C4));
  canvas.drawPath(
    Path()
      ..moveTo(0, h)
      ..lineTo(w * .35, h * .45)
      ..lineTo(w * .6, h * .8)
      ..lineTo(w * .8, h * .6)
      ..lineTo(w, h)
      ..close(),
    Paint()..color = const Color(0xFF233056),
  );
  // Corner markers: all four are visible only when nothing is cropped.
  for (final c in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
    canvas.drawCircle(c, w * .06, Paint()..color = const Color(0xFFFFFFFF));
  }
  final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Photos asked for and not drawn yet. Drawing needs real time, which only
/// [Shots.settle] has.
final List<(String, Completer<Uint8List>)> _wanted = [];

class _Client extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(url);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _Request(url);
  @override
  void close({bool force = false}) {}
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  String? value(String name) => null;
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.url);
  final Uri url;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async {
    final drawn = Completer<Uint8List>();
    _wanted.add((url.toString(), drawn));
    return _Response(await drawn.future);
  }
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  HttpHeaders get headers => _Headers();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

String photo(String name, String size) =>
    'https://res.cloudinary.com/x/image/upload/v1/$name-$size.jpg';

Future<void> loadFonts() async {
  final press = FontLoader('Press Start 2P')
    ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf'));
  await press.load();
  final icons = File('/c/flutter/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf');
  final windows =
      File(r'C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf');
  final file = windows.existsSync() ? windows : icons;
  if (file.existsSync()) {
    final data = file.readAsBytesSync();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(data))))
        .load();
  }
}

/// A couple with a realistic amount of everything.
Future<FakeFirebaseFirestore> seed({bool quest = true}) async {
  final db = FakeFirebaseFirestore();
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  Timestamp at(Duration d) => Timestamp.fromDate(now.add(d));
  await db.doc('users/me').set({
    'displayName': 'CARL',
    'avatarSpriteId': 'monster_guy',
    'coupleId': 'c',
    'homeCity': 'DAVAO CITY',
    'locationEnabled': true,
    'currentLocation': const GeoPoint(7.07, 125.6),
    'currentLocationUpdatedAt': Timestamp.now(),
  });
  await db.doc('users/you').set({
    'displayName': 'MIKA',
    'avatarSpriteId': 'mecha_rabbit',
    'coupleId': 'c',
    'homeCity': 'QUEZON CITY',
    'locationEnabled': true,
    'currentLocation': const GeoPoint(14.67, 121.04),
    'currentLocationUpdatedAt': Timestamp.now(),
  });
  await db.doc('couples/c').set({
    'memberUids': ['me', 'you'],
    'pairingCode': '482913',
    'status': 'active',
    'unitPref': 'km',
    'linkedAt': at(const Duration(days: -212)),
    if (quest)
      'reunionQuest': {
        'status': 'accepted',
        'destination': 'SIARGAO ISLAND',
        'targetDate': at(const Duration(days: 23, hours: 4)),
        'proposedByUid': 'you',
        'acceptedAt': at(const Duration(days: -40)),
      },
  });

  var n = 0;
  Future<void> entry(
    int day,
    String title, {
    String by = 'me',
    String type = 'memory',
    String tag = 'DATE NIGHT',
    String story = '',
    List<String> photos = const [],
    String? pin,
  }) =>
      db.doc('couples/c/memories/m${n++}').set({
        'authorUid': by,
        'date': Timestamp.fromDate(today.add(Duration(days: day))),
        'entryType': type,
        'title': title,
        'story': story,
        'tagCategory': tag,
        'photoUrls': photos,
        if (pin != null) 'locationPin': {'name': pin, 'lat': 0, 'lng': 0},
        'createdAt': at(Duration(days: day)),
      });
  await entry(
    -2,
    'Sunset coffee at the bay',
    tag: 'BEACH',
    pin: 'SEASIDE BLVD, DAVAO',
    story: 'We walked along the shore right before my flight back. '
        'You spilled the latte and laughed so hard the dog next to us '
        'started barking. I want to remember this one forever.',
    photos: [
      photo('sunset', '1600x1000'),
      photo('portrait', '1000x1600'),
      photo('square', '1200x1200'),
      photo('tall', '700x1900'),
    ],
  );
  await entry(-2, 'Latte disaster, 10/10', by: 'you', tag: 'BEACH',
      photos: [photo('tall', '900x1600')]);
  await entry(-6, 'Arcade rematch', tag: 'MALL', by: 'you',
      photos: [photo('arcade', '1600x900')]);
  await entry(-11, 'Movie marathon', tag: 'HOME VISIT');
  await entry(-13, 'Dinner plan', type: 'plan', by: 'you');
  await entry(3, 'Video call date night', type: 'plan');
  await entry(7, 'Order her cake', type: 'plan', tag: 'SURPRISE');
  for (final (by, text) in [
    ('you', 'I still owe you a new shirt haha'),
    ('you', 'That dog had better coffee manners than me.'),
  ]) {
    await db.collection('couples/c/memories/m0/comments').add({
      'authorUid': by,
      'text': text,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> chest(String id, Map<String, dynamic> extra) =>
      db.doc('couples/c/capsules/$id').set({
        'creatorUid': 'me',
        'title': id,
        'triggerMode': 'dateRelease',
        'status': 'sealed',
        'createdAt': at(const Duration(days: -9)),
        ...extra,
      });
  await chest('Open on your flight home', {
    'unlockDate': at(const Duration(days: 12, hours: 5)),
  });
  await chest('For a bad day', {
    'creatorUid': 'you',
    'triggerMode': 'dualTapSync',
    'dualTapState': {'p2TappedAt': Timestamp.now()},
  });
  await chest('Happy 6 months!', {
    'creatorUid': 'you',
    'status': 'unlocked',
    'unlockDate': at(const Duration(days: -1)),
    'openedAt': at(const Duration(days: -1)),
  });
  await chest('Read together', {
    'triggerMode': 'dualTapSync',
    'dualTapState': {'p1TappedAt': Timestamp.now()},
  });
  await chest('A very long chest name that has to wrap somewhere', {
    'creatorUid': 'you',
    'unlockDate': at(const Duration(days: 140)),
  });
  await db.doc('couples/c/capsules/Happy 6 months!/sealed/content').set({
    'creatorUid': 'you',
    'secretNote': 'Six months, two time zones, and you still answer on the '
        'first ring. Thank you for being my player two.',
    'photoUrl': photo('chest', '1000x1500'),
    'voiceNoteUrl': 'https://res.cloudinary.com/x/video/upload/v1/a.m4a',
  });
  return db;
}

final _boundary = GlobalKey();

class Shots {
  Shots(this.tester, this.db);
  final WidgetTester tester;
  final FakeFirebaseFirestore db;

  Future<void> settle([int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() async {
        while (_wanted.isNotEmpty) {
          final (url, drawn) = _wanted.removeAt(0);
          drawn.complete(await drawPhoto(url));
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> show(Widget home, {Size size = const Size(360, 780)}) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 90)
      ..viewPadding = const FakeViewPadding(top: 90);
    addTearDown(tester.view.reset);
    final users = UserRepository(db);
    final couples = CoupleRepository(db);
    await tester.pumpWidget(RepaintBoundary(
      key: _boundary,
      child: MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => FakeAuth()),
          Provider.value(value: users),
          Provider.value(value: couples),
          Provider(create: (_) => MemoryRepository(db)),
          Provider(create: (_) => CapsuleRepository(db)),
          Provider(
            create: (_) =>
                PairingRepository(users: users, couples: couples, db: db),
          ),
          Provider(create: (_) => StorageService()),
          Provider<LocationService>(create: (_) => FakeLocation()),
          ChangeNotifierProvider(
              create: (ctx) => AuthController(ctx.read<AuthService>())),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: home,
        ),
      ),
    ));
    await settle();
  }

  Future<void> save(String name) async {
    await settle(2);
    final boundary = _boundary.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> tap(Finder finder) async {
    for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      // Below what has been built so far.
      await drag(find.byType(ListView).first, -250);
    }
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(finder.first, warnIfMissed: false);
    await settle();
  }

  Future<void> drag(Finder finder, double dy) async {
    await tester.drag(finder.first, Offset(0, dy), warnIfMissed: false);
    await settle(3);
  }

  Future<void> close() async {
    // Nothing may stay half loaded for the next shot to wait on.
    await settle(4);
    await tester.pumpWidget(const SizedBox());
    await settle(2);
  }
}

void shot(String name, Future<void> Function(Shots s) body, {bool quest = true}) {
  testWidgets(name, (tester) async {
    HttpOverrides.global = _Photos();
    imageCache
      ..clear()
      ..clearLiveImages();
    for (final name in [
      'com.llfbandit.record/messages',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(name), (_) async => null);
    }
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final db = (await tester.runAsync(() async {
      await loadFonts();
      return seed(quest: quest);
    }))!;
    final s = Shots(tester, db);
    await body(s);
    await s.close();
    HttpOverrides.global = null;
  });
}

void main() {
  // Opened here, outside any test: a future made under one test's fake clock
  // never reaches the next.
  setUpAll(() => PhotoCache.instance
      .read('http://localhost/none')
      .then<void>((_) {}, onError: (_) {}));

  shot('icons', (s) async {
    await s.show(Scaffold(
      backgroundColor: AppColors.purple,
      body: SafeArea(
        child: GridView.count(
          crossAxisCount: 7,
          children: [
            for (final icon in PixelIcons.values)
              Center(child: PixelIcon(icon, size: 36, color: AppColors.yellow)),
          ],
        ),
      ),
    ));
    await s.save('icons');
  });

  // ── Tabs ──
  shot('home', (s) async {
    await s.show(const ShellScreen());
    await s.save('home');
    await s.drag(find.byType(SingleChildScrollView), -500);
    await s.save('home_bottom');
  });
  shot('home_empty', (s) async {
    await s.show(const ShellScreen());
    await s.save('home_empty');
    await s.tap(find.text('PROPOSE A QUEST'));
    await s.tap(find.text('PROPOSE QUEST'));
    await s.save('propose_quest');
  }, quest: false);
  shot('calendar', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('CALENDAR'));
    await s.save('calendar');
    await s.drag(find.byType(ListView), -700);
    await s.save('calendar_bottom');
  });
  shot('vault', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('VAULT'));
    await s.save('vault');
    await s.tap(find.bySemanticsLabel('Filter chests'));
    await s.save('vault_filter');
  });
  shot('config', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('CONFIG'));
    await s.save('config');
    await s.drag(find.byType(SingleChildScrollView), -900);
    await s.save('config_bottom');
    await s.tap(find.text('UNLINK PARTNER'));
    await s.save('dialog');
  });

  // ── Memories ──
  shot('memory', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('CALENDAR'));
    await s.tap(find.text('Sunset coffee at the bay'));
    await s.save('memory_landscape');
    for (final name in ['portrait', 'square', 'tall']) {
      await s.tap(find.bySemanticsLabel('Next photo'));
      await s.save('memory_$name');
    }
    await s.tap(find.byType(PhotoMosaic));
    await s.save('viewer');
    await s.tap(find.bySemanticsLabel('Rotate'));
    await s.save('viewer_rotated');
    await s.tap(find.bySemanticsLabel('Close').last);
    await s.drag(find.byType(SingleChildScrollView).last, -600);
    await s.save('memory_bottom');
    await s.tap(find.text('EDIT'));
    await s.save('edit_memory');
    await s.tap(find.text('BEACH').last);
    await s.save('tag_picker');
  });
  shot('day_picker', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('CALENDAR'));
    await s.tap(find.text('Latte disaster, 10/10'));
    await s.drag(find.byType(SingleChildScrollView).last, -600);
    await s.save('memory_partner');
  });
  shot('plan', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('CALENDAR'));
    await s.tap(find.text('Video call date night'));
    await s.save('plan');
  });
  shot('log_today', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('LOG MEMORY'));
    await s.save('log_today');
    await s.tap(find.text('SAVE MEMORY'));
    await s.tester.enterText(find.byType(TextField).at(1), 'A draft');
    await s.tap(find.bySemanticsLabel('Close').last);
    await s.save('discard');
  });
  shot('month_picker', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('CALENDAR'));
    await s.tap(find.byType(MonthNavBar));
    await s.save('month_picker');
  });

  // ── Chests ──
  shot('chest_date', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('VAULT'));
    await s.tap(find.text('Open on your flight home').last);
    await s.save('chest_date');
  });
  shot('chest_dual', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('VAULT'));
    await s.tap(find.text('For a bad day').last);
    await s.save('chest_dual');
  });
  shot('chest_open', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('VAULT'));
    await s.tap(find.text('Happy 6 months!').last);
    await s.save('chest_open');
    await s.drag(find.byType(SingleChildScrollView).last, -700);
    await s.save('chest_open_bottom');
  });
  shot('new_chest', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('LOCK CHEST'));
    await s.save('new_chest');
    await s.tap(find.text('SEAL CHEST'));
    await s.drag(find.byType(SingleChildScrollView).last, -600);
    await s.save('new_chest_bottom');
  });

  // ── Getting in ──
  shot('splash', (s) async {
    await s.show(SplashScreen(resolveRoute: (_) => Completer<String>().future));
    await s.save('splash');
  });
  shot('welcome', (s) async {
    await s.show(const WelcomeScreen());
    await s.save('welcome');
    await s.tap(find.text('REGISTER'));
    await s.tap(find.text('CREATE ACCOUNT'));
    await s.save('register');
  });
  shot('forgot', (s) async {
    await s.show(const ForgotPasswordScreen());
    await s.save('forgot');
  });
  shot('sprite', (s) async {
    await s.show(const SpriteSelectScreen());
    await s.save('sprite');
  });
  shot('pairing', (s) async {
    await s.show(const PairingScreen());
    await s.save('pairing');
    await s.tap(find.text('MAKE A CODE'));
    await s.save('pairing_code');
    await s.tap(find.text('JOIN'));
    await s.save('pairing_join');
  });
  shot('paired', (s) async {
    await s.show(const PairingSuccessScreen());
    await s.save('paired');
  });
  shot('permission', (s) async {
    await s.show(Scaffold(
      backgroundColor: AppColors.night,
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                showPermissionPrimer(context, PermissionKind.location),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await s.tap(find.text('go'));
    await s.save('permission');
  });
  shot('scenes', (s) async {
    await s.show(Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: ListView(
          children: [
            for (final hour in [6, 18, 22])
              OverworldScene(
                mySprite: 'monster_guy',
                partnerSprite: 'mecha_rabbit',
                together: hour == 18,
                value: hour == 18 ? "YOU'RE TOGETHER!" : '~12,345',
                caption: hour == 18 ? 'MAKE THIS ONE COUNT' : 'KM APART',
                hour: hour,
              ),
          ],
        ),
      ),
    ));
    await s.save('scenes');
  });
  shot('pickers', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('LOCK CHEST'));
    await s.tap(find.text('TAP TO CHOOSE WHEN'));
    await s.save('date_picker');
    await s.tap(find.text('OK'));
    await s.save('time_picker');
    await s.tap(find.text('OK'));
    await s.save('new_chest_dated');
  });
  shot('toast', (s) async {
    await s.show(const ShellScreen());
    await s.tap(find.text('CONFIG'));
    await s.tap(find.bySemanticsLabel('Copy room code'));
    await s.save('toast');
  });
  shot('small_phone', (s) async {
    const small = Size(320, 600);
    await s.show(const ShellScreen(), size: small);
    await s.save('small_home');
    await s.tap(find.text('CALENDAR'));
    await s.save('small_calendar');
    await s.tap(find.text('VAULT'));
    await s.save('small_vault');
  });
}
