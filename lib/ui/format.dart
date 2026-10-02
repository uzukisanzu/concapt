import '../core/digits.dart';

export '../core/digits.dart';

/// Rounds to a whole number with thousands separators; null shows as a dash.
String formatInt(num? value) {
  if (value == null || !value.isFinite) return '—';
  final n = value.round();
  final digits = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Axis label: whole thousands as `115k`, anything else in full.
String formatCompact(int value) =>
    value != 0 && value % 1000 == 0 ? '${value ~/ 1000}k' : formatInt(value);

String formatTime(DateTime t) =>
    '${twoDigits(t.month)}-${twoDigits(t.day)} ${twoDigits(t.hour)}:${twoDigits(t.minute)}';
