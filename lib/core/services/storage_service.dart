import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/cloudinary_config.dart';

/// Media hosting via Cloudinary (unsigned upload preset).
///
/// Uploads can't be deleted from the app: that needs the API secret, which must
/// never ship inside it.
class StorageService {
  static const _base =
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}';
  static const _timeout = Duration(seconds: 90);

  Future<String> uploadPhoto(Uint8List bytes) =>
      _upload('image', bytes, filename: 'photo.jpg');

  /// Uploads together; the urls keep the order of [photos].
  Future<List<String>> uploadPhotos(List<Uint8List> photos) =>
      Future.wait(photos.map(uploadPhoto));

  /// Cloudinary files audio under its "video" type.
  Future<String> uploadVoiceNote(String filePath) async =>
      _upload('video', await File(filePath).readAsBytes(),
          filename: 'voice.m4a');

  Future<String> _upload(
    String type,
    Uint8List bytes, {
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/$type/upload'))
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    final response = await request.send().timeout(_timeout);
    final body = await response.stream.bytesToString().timeout(_timeout);
    if (response.statusCode != 200) {
      throw HttpException('Upload failed (${response.statusCode}): $body');
    }
    final url = (jsonDecode(body) as Map<String, dynamic>)['secure_url'];
    if (url is! String) throw const HttpException('Upload returned no url');
    return url;
  }
}
