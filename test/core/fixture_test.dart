import 'dart:convert';
import 'dart:io';

import 'package:concapt/core/models.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

List<TextPiece> _pieces(Map<String, dynamic> json) => [
      for (final p in json['pieces'] as List) TextPiece.fromJson(p as Map<String, dynamic>),
    ];

Map<String, dynamic> _load(File f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

const _reference =
    'Screenshot_2026-10-02-12-29-20-517_com.bandainamcoent.idolmaster_gakuen';

/// The run in `ref-script/result-2026-10/$_reference.jpg`.
final _referenceScores = RunScores(const [
  StageScores(left: 734062, middle: 26201, right: 107547, bonus: 146812, total: 1014622),
  StageScores(left: 309349, middle: 98168, right: 70321, bonus: 61869, total: 539707),
  StageScores(left: 28951, middle: 121135, right: 44246, bonus: 24227, total: 218559),
]);

/// Real ML Kit output recorded from the corpus by integration_test/ocr_accuracy_test.dart.
void main() {
  final files = Directory('test/fixtures/ocr')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  test('fixtures are present', () => expect(files, isNotEmpty));

  test('reference screenshot parses to its known values', () {
    final json = _load(File('test/fixtures/ocr/$_reference.json'));
    final result = ResultParser.parse(_pieces(json));
    expect((result as ParsedRun).draft.toScores(), _referenceScores);
  });

  test('every capture that passed on the phone still passes', () {
    final regressions = <String>[];
    for (final f in files) {
      final json = _load(f);
      if (json['passed'] != true) continue;
      final result = ResultParser.parse(_pieces(json));
      final ok = result is ParsedRun && (result.draft.toScores()?.allSumsOk ?? false);
      if (!ok) regressions.add(f.uri.pathSegments.last);
    }
    expect(regressions, isEmpty);
  });
}
