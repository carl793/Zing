/// Sprite choices available in onboarding and Settings.
class SpriteOption {
  final String id;
  final String label;
  final String? assetPath;
  final String emojiFallback;
  final String? pngFallbackPath;

  const SpriteOption({
    required this.id,
    required this.label,
    this.assetPath,
    required this.emojiFallback,
    this.pngFallbackPath,
  });
}

class SpriteOptions {
  SpriteOptions._();

  static const List<SpriteOption> primary = [
    SpriteOption(
      id: 'mecha_rabbit',
      label: 'MECHA BUNNY',
      assetPath: 'assets/sprites/mecha_rabbit.svg',
      pngFallbackPath: 'assets/sprites/mecha_rabbit_96.png',
      emojiFallback: '\u{1F407}',
    ),
    SpriteOption(
      id: 'monster_guy',
      label: 'MONSTER GUY',
      assetPath: 'assets/sprites/monster_guy.svg',
      pngFallbackPath: 'assets/sprites/monster_guy_96.png',
      emojiFallback: '\u{1F47E}',
    ),
  ];

  static const List<SpriteOption> added = [
    SpriteOption(
      id: 'pixel_art_12',
      label: 'PIXEL ART 12',
      assetPath: 'assets/sprites/pixelArt-12.svg',
      emojiFallback: '\u{1F464}',
    ),
    SpriteOption(
      id: 'pixel_art_1',
      label: 'PIXEL ART 1',
      assetPath: 'assets/sprites/pixelArt-1.svg',
      emojiFallback: '\u{1F464}',
    ),
    SpriteOption(
      id: 'pixel_art_15',
      label: 'PIXEL ART 15',
      assetPath: 'assets/sprites/pixelArt-15.svg',
      emojiFallback: '\u{1F464}',
    ),
    SpriteOption(
      id: 'pixel_art_2',
      label: 'PIXEL ART 2',
      assetPath: 'assets/sprites/pixelArt-2.svg',
      emojiFallback: '\u{1F464}',
    ),
    SpriteOption(
      id: 'pixel_art_4',
      label: 'PIXEL ART 4',
      assetPath: 'assets/sprites/pixelArt-4.svg',
      emojiFallback: '\u{1F464}',
    ),
    SpriteOption(
      id: 'pixel_art_0',
      label: 'PIXEL ART 0',
      assetPath: 'assets/sprites/pixelArt-0.png',
      emojiFallback: '\u{1F464}',
    ),
  ];

  /// Kept so accounts that already chose an emoji continue to render.
  static const List<SpriteOption> emoji = [
    SpriteOption(id: '\u{1F407}', label: 'BUNNY', emojiFallback: '\u{1F407}'),
    SpriteOption(id: '\u{1F47B}', label: 'GHOST', emojiFallback: '\u{1F47B}'),
    SpriteOption(id: '\u{1F47E}', label: 'ALIEN', emojiFallback: '\u{1F47E}'),
    SpriteOption(id: '\u{1F98A}', label: 'FOX', emojiFallback: '\u{1F98A}'),
    SpriteOption(id: '\u{1F40D}', label: 'SNAKE', emojiFallback: '\u{1F40D}'),
    SpriteOption(id: '\u{1F984}', label: 'UNICORN', emojiFallback: '\u{1F984}'),
    SpriteOption(id: '\u{1F422}', label: 'TURTLE', emojiFallback: '\u{1F422}'),
    SpriteOption(id: '\u{1F31E}', label: 'SUN', emojiFallback: '\u{1F31E}'),
    SpriteOption(id: '\u{1F319}', label: 'MOON', emojiFallback: '\u{1F319}'),
    SpriteOption(
      id: '\u{1F321}\u{FE0F}',
      label: 'THERMOMETER',
      emojiFallback: '\u{1F321}\u{FE0F}',
    ),
  ];

  /// Choices shown in the compact sprite picker; legacy emojis remain hidden.
  static const List<SpriteOption> selectable = [...primary, ...added];
  static const List<SpriteOption> allOptions = [...selectable, ...emoji];
  static const List<String> all = [
    'mecha_rabbit',
    'monster_guy',
    'pixel_art_12',
    'pixel_art_1',
    'pixel_art_15',
    'pixel_art_2',
    'pixel_art_4',
    'pixel_art_0',
    '\u{1F407}',
    '\u{1F47B}',
    '\u{1F47E}',
    '\u{1F98A}',
    '\u{1F40D}',
    '\u{1F984}',
    '\u{1F422}',
    '\u{1F31E}',
    '\u{1F319}',
    '\u{1F321}\u{FE0F}',
  ];
  static const String fallback = 'mecha_rabbit';

  static SpriteOption resolve(String? id) {
    for (final option in allOptions) {
      if (option.id == id || option.emojiFallback == id) return option;
    }
    return primary.first;
  }
}
