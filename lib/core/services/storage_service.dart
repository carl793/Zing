import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/cloudinary_config.dart';

/// Media hosting via Cloudinary (unsigned upload preset).
///
/// Photos: uploaded as image/jpeg, stored in `photoUrls` or `photoUrl`.
/// Voice notes: uploaded as audio (Cloudinary resource_type=video handles audio),
/// stored in `voiceNoteUrl`.
class StorageService {
  static final Uri _imageUri = Uri.parse(
    'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
  );

  static final Uri _audioUri = Uri.parse(
    'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/video/upload',
  );

  static const Duration _timeout = Duration(seconds: 90);

  // ── Calendar memory photos ──────────────────────────────────────────────

  Future<List<String>> uploadMemoryPhotos({
    required String coupleId,
    required String memoryId,
    required List<Uint8List> photos,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < photos.length; i++) {
      urls.add(await _uploadImage(photos[i], i));
    }
    return urls;
  }

  // ── Vault chest single photo ─────────────────────────────────────────────

  Future<String> uploadChestPhoto({
    required String coupleId,
    required String capsuleId,
    required Uint8List bytes,
  }) async {
    return _uploadImage(bytes, 0);
  }

  // ── Vault chest voice note ───────────────────────────────────────────────

  /// [filePath] is the local path returned by the `record` package after
  /// recording stops.
  Future<String> uploadVoiceNote({
    required String coupleId,
    required String capsuleId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', _audioUri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['resource_type'] = 'video'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'voice_${capsuleId}_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
      );

    final response = await request.send().timeout(_timeout);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Voice upload failed (${response.statusCode}): $body');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null) throw Exception('No secure_url in voice upload response');
    return url;
  }

  // ── Shared ───────────────────────────────────────────────────────────────

  /// No-op for the same reason as before: deletion needs the API secret.
  Future<void> deletePhotosByUrl(Iterable<String> urls) async {}

  Future<String> _uploadImage(Uint8List bytes, int index) async {
    final request = http.MultipartRequest('POST', _imageUri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'photo_${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
        ),
      );

    final response = await request.send().timeout(_timeout);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Image upload failed (${response.statusCode}): $body');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null) throw Exception('No secure_url in image upload response');
    return url;
  }
}