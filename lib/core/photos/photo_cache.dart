import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Keeps downloaded photos on the phone, so opening a memory again needs no
/// data and works offline. The system may clear it at any time.
class PhotoCache {
  PhotoCache._();
  static final PhotoCache instance = PhotoCache._();

  static const _maxBytes = 150 * 1024 * 1024;
  static const _timeout = Duration(seconds: 30);

  late final Future<Directory?> _folder = _open();
  final Map<String, Future<Uint8List>> _reading = {};

  /// The photo's bytes, from the phone if it's there. Throws when it must be
  /// downloaded and can't be.
  Future<Uint8List> read(String url) =>
      _reading[url] ??= _read(url).whenComplete(() {
        _reading.remove(url);
      });

  Future<Uint8List> _read(String url) async {
    final folder = await _folder;
    final file = folder == null ? null : File('${folder.path}/${_name(url)}');
    if (file != null) {
      try {
        final bytes = await file.readAsBytes();
        // Marks it as recently used; see _prune.
        unawaited(file.setLastModified(DateTime.now()).catchError((_) {}));
        if (bytes.isNotEmpty) return bytes;
      } on FileSystemException {
        // Not stored yet.
      }
    }
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw HttpException('Photo download failed (${response.statusCode})');
    }
    if (file != null) unawaited(_store(file, response.bodyBytes));
    return response.bodyBytes;
  }

  /// Written beside and then moved, so a half-written photo is never read.
  Future<void> _store(File file, Uint8List bytes) async {
    try {
      final part = File('${file.path}.part');
      await part.writeAsBytes(bytes);
      await part.rename(file.path);
    } catch (e) {
      debugPrint('Keeping a photo failed: $e');
    }
  }

  /// Photo urls never change, so each one is its own file name.
  static String _name(String url) {
    final safe = url.replaceAll(RegExp('[^A-Za-z0-9.]+'), '_');
    return safe.length <= 160 ? safe : safe.substring(safe.length - 160);
  }

  Future<Directory?> _open() async {
    try {
      final base = await getTemporaryDirectory();
      final folder = await Directory('${base.path}/photos').create();
      unawaited(_prune(folder));
      return folder;
    } catch (e) {
      debugPrint('No photo cache: $e');
      return null;
    }
  }

  /// Once per launch: throws away the photos not seen for longest.
  static Future<void> _prune(Directory folder) async {
    try {
      final files = <(File, FileStat)>[];
      var total = 0;
      await for (final entry in folder.list()) {
        if (entry is! File) continue;
        final stat = await entry.stat();
        files.add((entry, stat));
        total += stat.size;
      }
      if (total <= _maxBytes) return;
      files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (file, stat) in files) {
        if (total <= _maxBytes * 0.8) break;
        await file.delete();
        total -= stat.size;
      }
    } catch (e) {
      debugPrint('Clearing old photos failed: $e');
    }
  }
}

/// A photo read through the [PhotoCache]. When [url] fails, [fallback] is
/// tried once.
@immutable
class CachedPhoto extends ImageProvider<CachedPhoto> {
  final String url;
  final String? fallback;
  const CachedPhoto(this.url, {this.fallback});

  @override
  Future<CachedPhoto> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedPhoto key,
    ImageDecoderCallback decode,
  ) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: 1,
        debugLabel: url,
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    try {
      return await _decode(url, decode);
    } catch (e) {
      debugPrint('Photo failed: $e');
      final other = fallback;
      try {
        if (other == null || other == url) rethrow;
        return await _decode(other, decode);
      } catch (_) {
        // Forget the failure, so looking again tries again.
        scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
        rethrow;
      }
    }
  }

  static Future<ui.Codec> _decode(
    String url,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await PhotoCache.instance.read(url);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is CachedPhoto && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
