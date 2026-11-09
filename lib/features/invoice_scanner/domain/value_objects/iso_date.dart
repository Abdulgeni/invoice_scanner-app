final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Strict `YYYY-MM-DD`. Returns UTC midnight, or null when malformed or not
/// a real calendar date (2023-02-29 is rejected, not rolled over).
DateTime? tryParseIsoDate(String? raw) {
  if (raw == null) return null;
  final RegExpMatch? m = _isoDate.firstMatch(raw.trim());
  if (m == null) return null;
  final int year = int.parse(m.group(1)!);
  final int month = int.parse(m.group(2)!);
  final int day = int.parse(m.group(3)!);
  final DateTime date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Date-only value from a picker result: UTC midnight of the same calendar day.
DateTime dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String formatIsoDate(DateTime value) {
  final String y = value.year.toString().padLeft(4, '0');
  final String m = value.month.toString().padLeft(2, '0');
  final String d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
