// Dates written the way people read them (no extra package needed):
//
//   DateText.day(d)    "Today", "10 May", or "10 May 2025" for other years
//
// Used by History (the date headings) and My Activity.
class DateText {
  static const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// True when [a] and [b] fall on the same calendar day (the time is ignored).
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Today", "10 May", or "10 May 2025" when the year is not this year.
  /// [now] is only passed by tests; the app uses the real date.
  static String day(DateTime d, {DateTime? now}) {
    now ??= DateTime.now();
    if (sameDay(d, now)) return 'Today';

    final text = '${d.day} ${months[d.month - 1]}';
    return d.year == now.year ? text : '$text ${d.year}';
  }
}
