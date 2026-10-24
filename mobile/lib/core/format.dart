import 'package:intl/intl.dart';

String _p(int n) => n.toString().padLeft(2, '0');

String nowDay([DateTime? d]) {
  d ??= DateTime.now();
  return '${d.year}-${_p(d.month)}-${_p(d.day)}';
}

String nowTime([DateTime? d]) {
  d ??= DateTime.now();
  return '${_p(d.hour)}:${_p(d.minute)}';
}

/// The device's local day/time, so the server computes "today" in the user's timezone.
Map<String, String> nowQuery() => {'day': nowDay(), 'time': nowTime()};

/// "13:00" -> "1:00 PM" (or "01:00 PM" with [pad]).
String fmtTime(String? hhmm, {bool pad = false}) {
  if (hhmm == null || hhmm.length < 5) return hhmm ?? '';
  final h = int.tryParse(hhmm.substring(0, 2));
  final m = hhmm.substring(3, 5);
  if (h == null) return hhmm;
  final ap = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${pad ? _p(h12) : h12}:$m $ap';
}

DateTime? _parseDay(String day) {
  final p = day.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// "2026-09-27" -> Today / Yesterday / "Sep 27, 2026".
String dayLabel(String day) {
  final d = _parseDay(day);
  if (d == null) return day;
  final today = DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  final diff = t0.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('MMM d, y').format(d);
}

/// Format a stored date that may be ISO ("2026-09-24") or free text ("March 14, 1991").
String prettyDate(String raw) {
  final d = _parseDay(raw);
  return d == null ? raw : DateFormat('MMM d, y').format(d);
}

/// ISO timestamp -> "Today · 09:12 AM" / "Yesterday · 08:15 PM" / "Sep 27 · 04:20 PM".
String relTime(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final today = DateTime.now();
  final diff = DateTime(today.year, today.month, today.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  final time = fmtTime(nowTime(t), pad: true);
  if (diff == 0) return 'Today \u00b7 $time';
  if (diff == 1) return 'Yesterday \u00b7 $time';
  return '${DateFormat('MMM d').format(t)} \u00b7 $time';
}

/// Short form for list trailing: time today, otherwise the day.
String shortTime(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final today = DateTime.now();
  final diff = DateTime(today.year, today.month, today.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (diff == 0) return fmtTime(nowTime(t), pad: true);
  if (diff == 1) return 'Yesterday';
  return DateFormat('MMM d').format(t);
}

String longToday() => DateFormat('EEEE, MMMM d').format(DateTime.now());

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

String firstName(String name) {
  final parts = name.replaceFirst(RegExp(r'^Dr\.?\s+', caseSensitive: false), '').trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? name : parts.first;
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
