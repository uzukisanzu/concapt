import 'package:concapt/core/models.dart';
import 'package:concapt/core/stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

void main() {
  test('empty series has n 0 and no values', () {
    final s = summarize(const []);
    expect(s.n, 0);
    expect([s.mean, s.median, s.min, s.max, s.p25, s.p75], everyElement(isNull));
  });

  test('single value fills every stat', () {
    final s = summarize(const [5]);
    expect([s.mean, s.median, s.min, s.max, s.p25, s.p75], everyElement(5));
  });

  test('even count matches PERCENTILE.INC', () {
    final s = summarize(const [4, 1, 3, 2]);
    expect(s.n, 4);
    expect(s.mean, 2.5);
    expect(s.median, 2.5);
    expect(s.min, 1);
    expect(s.max, 4);
    expect(s.p25, 1.75);
    expect(s.p75, 3.25);
  });

  test('odd count', () {
    final s = summarize(const [50, 10, 40, 20, 30]);
    expect(s.median, 30);
    expect(s.p25, 20);
    expect(s.p75, 40);
  });

  test('seriesValues picks one stage and slot from each run', () {
    final runs = [
      for (final (i, scores) in [referenceScores(), scoresWithLeft(100000)].indexed)
        RunRecord(id: i, seq: i + 1, capturedAt: DateTime(2026), edited: false, scores: scores),
    ];
    expect(seriesValues(runs, 0, 0), [120918, 100000]);
    expect(seriesValues(runs, 2, 1), [14862, 14862]);
  });
}
