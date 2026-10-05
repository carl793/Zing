/// Preset tags offered when logging a memory or plan. Users can also type a
/// custom tag. Tags are stored as uppercase strings in `tagCategory`.
class TagCategories {
  TagCategories._();

  static const List<String> presets = [
    'BEACH',
    'DATE NIGHT',
    'AIRPORT',
    'ROADTRIP',
    'HOME VISIT',
    'PARK',
    'SPORTING EVENT',
    'MALL',
  ];

  static const String defaultTag = 'DATE NIGHT';
}