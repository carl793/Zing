import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage access for memory photos. Photos live under
/// couples/{coupleId}/memories/{memoryId}/photos/ and their download URLs are
/// saved in the memory's `photoUrls` array.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads [photos] and returns their download URLs, in order.
  /// If any upload fails, files already uploaded in this call are removed
  /// and the error is rethrown.
  Future<List<String>> uploadMemoryPhotos({
    required String coupleId,
    required String memoryId,
    required List<Uint8List> photos,
  }) async {
    final uploaded = <Reference>[];
    try {
      final urls = <String>[];
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < photos.length; i++) {
        final ref = _storage
            .ref('couples/$coupleId/memories/$memoryId/photos/${stamp}_$i.jpg');
        await ref.putData(
          photos[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );
        uploaded.add(ref);
        urls.add(await ref.getDownloadURL());
      }
      return urls;
    } catch (_) {
      for (final ref in uploaded) {
        try {
          await ref.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Best-effort removal of photos by download URL. Never throws.
  Future<void> deletePhotosByUrl(Iterable<String> urls) async {
    for (final url in urls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {}
    }
  }
}