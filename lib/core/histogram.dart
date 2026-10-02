import 'dart:math' as math;

import 'stats.dart';

const minBins = 8;
const maxBins = 40;

/// Equal-width bins: bin `i` covers `[start + i*step, start + (i+1)*step)`.
class Histogram {
  const Histogram({required this.start, required this.step, required this.counts});

  static const empty = Histogram(start: 0, step: 1, counts: []);

  final int start;
  final int step;
  final List<int> counts;

  int lowerEdge(int bin) => start + bin * step;
  int get end => lowerEdge(counts.length);
}

/// Freedman–Diaconis width, rounded up to a nice step, clamped to 8–40 bins.
Histogram buildHistogram(List<int> values) {
  if (values.isEmpty) return Histogram.empty;
  final sorted = [...values]..sort();
  final lo = sorted.first;
  final hi = sorted.last;
  if (lo == hi) return Histogram(start: lo, step: 1, counts: [sorted.length]);

  final iqr = percentile(sorted, 0.75) - percentile(sorted, 0.25);
  final raw = iqr > 0 ? 2 * iqr / math.pow(sorted.length, 1 / 3) : (hi - lo) / minBins;
  var step = niceStep(raw);
  while (_binCount(lo, hi, step) > maxBins) {
    step = largerNiceStep(step);
  }
  while (_binCount(lo, hi, step) < minBins) {
    final smaller = smallerNiceStep(step);
    if (smaller == null || _binCount(lo, hi, smaller) > maxBins) break;
    step = smaller;
  }

  final start = _floorDiv(lo, step) * step;
  final counts = List<int>.filled(_binCount(lo, hi, step), 0);
  for (final v in sorted) {
    counts[(v - start) ~/ step]++;
  }
  return Histogram(start: start, step: step, counts: counts);
}

int _binCount(int lo, int hi, int step) => _floorDiv(hi, step) - _floorDiv(lo, step) + 1;

/// Division rounding toward negative infinity, so bins below zero align too.
int _floorDiv(int a, int b) => (a - a % b) ~/ b;

/// Smallest 1, 2, or 5 × 10^k that is at least [raw], and at least 1.
int niceStep(double raw) {
  if (raw <= 1) return 1;
  var magnitude = 1;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  for (final m in const [1, 2, 5]) {
    if (m * magnitude >= raw) return m * magnitude;
  }
  return 10 * magnitude;
}

int largerNiceStep(int step) {
  final magnitude = _magnitude(step);
  return switch (step ~/ magnitude) {
    1 => 2 * magnitude,
    2 => 5 * magnitude,
    _ => 10 * magnitude,
  };
}

int? smallerNiceStep(int step) {
  if (step <= 1) return null;
  final magnitude = _magnitude(step);
  return switch (step ~/ magnitude) {
    1 => magnitude ~/ 10 * 5,
    2 => magnitude,
    _ => 2 * magnitude,
  };
}

int _magnitude(int step) {
  var magnitude = 1;
  while (magnitude * 10 <= step) {
    magnitude *= 10;
  }
  return magnitude;
}
