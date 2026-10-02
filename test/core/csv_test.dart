import 'package:concapt/core/csv.dart';
import 'package:concapt/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

const header = 'run,captured_at,'
    's1_left,s1_middle,s1_right,s1_bonus,s1_total,'
    's2_left,s2_middle,s2_right,s2_bonus,s2_total,'
    's3_left,s3_middle,s3_right,s3_bonus,s3_total';

void main() {
  test('empty session exports the header only', () {
    expect(buildCsv(const []), '$header\n');
  });

  test('rows are raw values ordered by run number', () {
    final runs = [
      RunRecord(
        id: 9,
        seq: 2,
        capturedAt: DateTime(2026, 10, 2, 9, 0, 5),
        edited: true,
        scores: scoresWithLeft(100000),
      ),
      RunRecord(
        id: 4,
        seq: 1,
        capturedAt: DateTime(2026, 1, 28, 8, 34, 17),
        edited: false,
        scores: referenceScores(),
      ),
    ];
    final lines = buildCsv(runs).split('\n');
    expect(lines[0], header);
    expect(
      lines[1],
      '1,2026-01-28T08:34:17,'
      '120918,39482,30299,24183,214882,'
      '107065,39562,38123,21413,206163,'
      '125812,14862,15385,25162,181221',
    );
    expect(lines[2], startsWith('2,2026-10-02T09:00:05,100000,'));
    expect(lines[3], '');
  });

  test('runs sharing a number both export', () {
    RunRecord run(int id) => RunRecord(
          id: id,
          seq: 1,
          capturedAt: DateTime(2026, 10, 2),
          edited: false,
          scores: referenceScores(),
        );
    final rows = buildCsv([run(1), run(2)]).split('\n').where((l) => l.startsWith('1,'));
    expect(rows, hasLength(2));
  });
}
