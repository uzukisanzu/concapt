import 'package:concapt/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatInt rounds and groups thousands', () {
    expect(formatInt(null), '—');
    expect(formatInt(0), '0');
    expect(formatInt(999), '999');
    expect(formatInt(1000), '1,000');
    expect(formatInt(120918.4), '120,918');
    expect(formatInt(2.5), '3');
    expect(formatInt(-1234), '-1,234');
    expect(formatInt(-2.5), '-3');
  });

  test('formatInt shows a dash for values with no number', () {
    expect(formatInt(double.nan), '—');
    expect(formatInt(double.infinity), '—');
  });

  test('formatCompact shortens whole thousands', () {
    expect(formatCompact(115000), '115k');
    expect(formatCompact(2500), '2,500');
    expect(formatCompact(500), '500');
    expect(formatCompact(0), '0');
    expect(formatCompact(-3000), '-3k');
    expect(formatCompact(-2500), '-2,500');
  });

  test('formatTime shows month, day, and minutes', () {
    expect(formatTime(DateTime(2026, 1, 28, 8, 4, 17)), '01-28 08:04');
  });
}
