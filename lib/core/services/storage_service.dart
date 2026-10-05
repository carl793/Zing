import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/cloudinary_config.dart';

/// Memory photo hosting via Cloudinary (unsigned upload preset).
///
/// Public API is unchanged from the previous Firebase Storage version, so the
/// calendar controller and modals need no changes. Returned download URLs are
/// saved in the memory's `photoUrls` array exactly as before.
class StorageService {
  static final Uri _uploadUri = Uri.parse(
    'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
  );

  static const Duration _timeout = Duration(seconds: 60);

  /// Uploads [photos] one by one and returns their HTTPS URLs, in order.
  /// Throws if any upload fails. [coupleId] and [memoryId] are unused here
  /// (kept so the signature matches the controller's calls).
  Future<List<String>> uploadMemoryPhotos({
    required String coupleId,
    required String memoryId,
    required List<Uint8List> photos,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < photos.length; i++) {
      urls.add(await _uploadOne(photos[i], i));
    }
    return urls;
  }

  /// Intentionally a no-op: deleting from Cloudinary requires the API secret,
  /// which must not live inside the app. Removed photos stay in the Cloudinary
  /// library but disappear from Zing. Can be cleaned up later server-side.
  Future<void> deletePhotosByUrl(Iterable<String> urls) async {}

  Future<String> _uploadOne(Uint8List bytes, int index) async {
    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'memory_photo_$index.jpg',
        ),
      );

    final response = await request.send().timeout(_timeout);
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${response.statusCode}): $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null) {
      throw Exception('Cloudinary response had no secure_url: $body');
    }
    return url;
  }
}