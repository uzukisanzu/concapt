import 'package:concapt/core/histogram.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nice steps', () {
    test('niceStep rounds up to 1, 2, or 5 times a power of ten', () {
      expect(niceStep(0.3), 1);
      expect(niceStep(1.5), 2);
      expect(niceStep(1000), 1000);
      expect(niceStep(1001), 2000);
      expect(niceStep(2300), 5000);
      expect(niceStep(9500), 10000);
    });

    test('larger and smaller steps walk the sequence', () {
      expect(largerNiceStep(1), 2);
      expect(largerNiceStep(2), 5);
      expect(largerNiceStep(5), 10);
      expect(largerNiceStep(50000), 100000);
      expect(smallerNiceStep(1), isNull);
      expect(smallerNiceStep(2), 1);
      expect(smallerNiceStep(10), 5);
      expect(smallerNiceStep(1000), 500);
    });
  });

  test('histograms with the same bins are equal', () {
    expect(buildHistogram(const [1, 5, 9]), buildHistogram(const [1, 5, 9]));
    expect(buildHistogram(const [1, 5, 9]) == buildHistogram(const [1, 5, 10]), isFalse);
  });

  test('empty input gives no bins', () {
    expect(buildHistogram(const []).counts, isEmpty);
  });

  test('all values equal gives a single bar', () {
    final h = buildHistogram(const [5, 5, 5]);
    expect(h.start, 5);
    expect(h.step, 1);
    expect(h.end, 6);
    expect(h.counts, [3]);
  });

  test('a range narrower than the minimum gives one bin per value', () {
    final h = buildHistogram(const [10, 12, 12, 12, 13]);
    expect(h.step, 1);
    expect(h.counts, [1, 0, 3, 1]);
    expect(h.lowerEdge(2), 12);
  });

  test('negative values align to the step', () {
    final values = [for (var i = 0; i < 40; i++) -95 + i * 5];
    final h = buildHistogram(values);
    expect(h.start % h.step, 0);
    expect(h.start, lessThanOrEqualTo(-95));
    expect(h.end, greaterThan(100));
    expect(h.counts.reduce((a, b) => a + b), values.length);
  });

  test('zero IQR with spread still bins', () {
    final h = buildHistogram(const [100, 100, 100, 100, 200]);
    expect(h.step, 10);
    expect(h.counts.length, 11);
    expect(h.counts.first, 4);
    expect(h.counts.last, 1);
  });

  test('too few bins shrinks the step to reach the minimum', () {
    final h = buildHistogram(const [0, 1000]);
    expect(h.step, 100);
    expect(h.counts.length, 11);
    expect(h.counts.first, 1);
    expect(h.counts.last, 1);
  });

  test('an outlier widens the step to stay under the maximum', () {
    final values = [for (var i = 0; i < 500; i++) 100000 + i * 2, 1000000];
    final h = buildHistogram(values);
    expect(h.step, 50000);
    expect(h.counts.length, 19);
    expect(h.counts.length, lessThanOrEqualTo(maxBins));
  });

  test('edges align to the step and cover every value', () {
    final values = [for (var i = 0; i < 300; i++) 113000 + (i * 7919) % 15000];
    final h = buildHistogram(values);
    expect(h.start % h.step, 0);
    expect(h.start, lessThanOrEqualTo(values.reduce((a, b) => a < b ? a : b)));
    expect(h.end, greaterThan(values.reduce((a, b) => a > b ? a : b)));
    expect(h.counts.reduce((a, b) => a + b), values.length);
    expect(h.counts.length, inInclusiveRange(minBins, maxBins));
  });
}
