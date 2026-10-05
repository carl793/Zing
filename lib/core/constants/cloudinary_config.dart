/// Cloudinary settings for memory photo uploads.
///
/// Neither value is a secret (unsigned uploads need only these two), but never
/// put your Cloudinary API key or API secret in the app.
class CloudinaryConfig {
  CloudinaryConfig._();

  /// Shown on your Cloudinary dashboard home page.
  static const String cloudName = 'dnvtlc1ms';

  /// The unsigned upload preset created in Settings → Upload → Upload presets.
  static const String uploadPreset = 'zing_memories';
}