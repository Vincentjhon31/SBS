/// App-wide date/time formatting. Everything user-facing shows a friendly
/// "month day" date and a 12-hour clock — never the raw 24-hour, dash-
/// separated numbers the app used to print. Deliberately dependency-free
/// (no intl) so there's nothing to initialize per-locale.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// "10:14 PM" — 12-hour clock, always, regardless of device setting.
String formatTime12h(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:${_twoDigits(dt.minute)} $period';
}

/// "Jul 24" — month + day, no year (for near-term, same-year contexts).
String formatDayMonth(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}';

/// "Jul 24, 2026" — month, day, year (for date-only displays).
String formatDate(DateTime dt) =>
    '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

/// "Jul 24, 10:14 PM" — the standard "month, date, time" the app uses for
/// timestamps (requests, evidence, reservations, activity).
String formatDateTime(DateTime dt) =>
    '${formatDayMonth(dt)}, ${formatTime12h(dt)}';

/// A short relative label ("just now", "5m ago", "3h ago", "2d ago") that
/// falls back to [formatDayMonth] past a week — for activity feeds.
String formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDayMonth(dt);
}
