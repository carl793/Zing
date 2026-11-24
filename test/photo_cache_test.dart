import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zing/core/photos/photo_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a photo is downloaded once, then read from the phone', () async {
    final folder = await Directory.systemTemp.createTemp('zing_photos');
    addTearDown(() => folder.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => folder.path,
    );

    var downloads = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      downloads++;
      final missing = request.uri.path.contains('missing');
      request.response
        ..statusCode = missing ? 404 : 200
        ..add(missing ? [] : [1, 2, 3])
        ..close();
    });
    final base = 'http://${server.address.host}:${server.port}';

    await HttpOverrides.runZoned(() async {
      final cache = PhotoCache.instance;
      final url = '$base/image/upload/c_limit,w_400,q_auto/v1/a.jpg';
      // Asked for twice at once, as by a thumbnail and its mosaic.
      final both = await Future.wait([cache.read(url), cache.read(url)]);
      expect(both, everyElement([1, 2, 3]));
      expect(downloads, 1);

      final stored = Directory('${folder.path}/photos');
      for (var i = 0; i < 50; i++) {
        if (stored.listSync().any((f) => f.path.endsWith('a.jpg'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await cache.read(url), [1, 2, 3]);
      expect(downloads, 1);

      // Another size of the same photo is its own file.
      await cache.read(url.replaceFirst('w_400', 'w_800'));
      expect(downloads, 2);

      // A failure is reported, and not remembered.
      await expectLater(cache.read('$base/missing.jpg'), throwsException);
      await expectLater(cache.read('$base/missing.jpg'), throwsException);
      expect(downloads, 4);

      // Offline, what was seen before can still be seen.
      await server.close(force: true);
      expect(await cache.read(url), [1, 2, 3]);
    }, createHttpClient: (context) => _RealOverrides().createHttpClient(context));
  });
}

/// The test binding blocks real requests; this allows them again.
class _RealOverrides extends HttpOverrides {}
