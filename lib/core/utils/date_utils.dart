/// Calendar-day helpers shared across features.
///
/// Storage convention: a memory's `date` is saved to Firestore as a Timestamp
/// at UTC midnight of its calendar day, so both partners resolve the same
/// calendar day regardless of device timezone. Every "day" value used by the
/// calendar UI is a UTC-midnight DateTime built via [ZingDateUtils.day].
class ZingDateUtils {
  ZingDateUtils._();

  static const List<String> _monthNames = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  static const List<String> _monthAbbreviations = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  /// Today's local calendar day as a UTC-midnight DateTime.
  static DateTime today() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Builds a calendar day (UTC midnight).
  static DateTime day(int year, int month, int dayOfMonth) =>
      DateTime.utc(year, month, dayOfMonth);

  /// Converts a DateTime read back from Firestore into a UTC-midnight day.
  static DateTime fromStored(DateTime stored) {
    final utc = stored.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  /// Converts a locally picked DateTime (e.g. from showDatePicker) into a day.
  static DateTime fromLocal(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day);

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// Blank cells before day 1 in a Sunday-first grid.
  static int leadingBlanks(int year, int month) =>
      DateTime.utc(year, month, 1).weekday % 7;

  static String monthName(int month) => _monthNames[month - 1];

  static String monthAbbr(int month) => _monthAbbreviations[month - 1];

  /// "WED"
  static String weekday(DateTime day) =>
      const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][day.weekday - 1];

  /// "2026-09-16"
  static String isoDate(DateTime date) {
    final d = date.toUtc();
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  /// "SEP 05, 2026"
  static String shortLabel(DateTime date) {
    final d = date.toUtc();
    return '${monthAbbr(d.month)} ${_two(d.day)}, ${d.year}';
  }

  /// "SEPTEMBER 2026"
  static String monthYearLabel(DateTime date) {
    final d = date.toUtc();
    return '${monthName(d.month)} ${d.year}';
  }

  /// "SEP 16, 2026 AT 3:05 PM", on this phone's clock.
  static String dateTimeLabel(DateTime local) =>
      '${shortLabel(fromLocal(local))} AT ${timeLabel(local)}';

  /// "3:05 PM"
  static String timeLabel(DateTime local) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${_two(local.minute)} ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  /// How long until [moment], in its largest unit or two: "12 DAYS",
  /// "5H 20M", "UNDER 1 MIN".
  static String timeLeft(DateTime moment, {DateTime? now}) {
    final left = moment.difference(now ?? DateTime.now());
    if (left.inDays >= 2) return '${left.inDays} DAYS';
    if (left.inHours >= 24) return '1 DAY ${left.inHours - 24}H';
    if (left.inHours >= 1) return '${left.inHours}H ${left.inMinutes % 60}M';
    if (left.inMinutes >= 1) return '${left.inMinutes} MIN';
    return 'UNDER 1 MIN';
  }

  static int daysBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays;

  static String _two(int n) => n.toString().padLeft(2, '0');
}