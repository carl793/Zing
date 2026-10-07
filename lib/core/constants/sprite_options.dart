/// Preset sprites offered at registration and in Settings.
/// Index 0–3 are "masculine-coded", 4–7 are "feminine-coded" — but the user
/// picks freely. Replace emoji strings with asset paths once pixel art assets
/// are ready (e.g. 'assets/images/sprite_0.png').
class SpriteOptions {
  SpriteOptions._();

  static const List<String> all = [
    '🐇', '👾', '🦊', '🐍',   // row 1
    '🦄', '🐢', '🌞', '🌙',   // row 2
  ];

  static const String fallback = '👾';
}