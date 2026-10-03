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

const _reference = 'Screenshot_2026-10-02-12-29-20-517_com.bandainamcoent.idolmaster_gakuen';

/// The run in `ref-script/result-2026-10/$_reference.jpg`.
final _referenceScores = RunScores(const [
  StageScores(left: 734062, middle: 26201, right: 107547, total: 1014622),
  StageScores(left: 309349, middle: 98168, right: 70321, total: 539707),
  StageScores(left: 28951, middle: 121135, right: 44246, total: 218559),
]);

/// Real OCR output recorded from the corpus: ML Kit's by
/// integration_test/ocr_accuracy_test.dart, Windows OCR's by
/// integration_test/windows_ocr_accuracy_test.dart.
void main() {
  for (final dir in ['test/fixtures/ocr', 'test/fixtures/ocr-windows']) {
    final files = Directory(
      dir,
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();

    group(dir, () {
      test('fixtures are present', () => expect(files, isNotEmpty));

      test('every capture that passed when recorded still passes', () {
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

      test('stage bounds stack top to bottom without overlapping', () {
        for (final f in files) {
          final json = _load(f);
          if (json['passed'] != true) continue;
          final bounds = (ResultParser.parse(_pieces(json)) as ParsedRun).stageBounds;
          final name = f.uri.pathSegments.last;
          for (var i = 0; i < bounds.length; i++) {
            expect(bounds[i].width, greaterThan(0), reason: name);
            expect(bounds[i].height, greaterThan(0), reason: name);
            if (i + 1 < bounds.length) {
              expect(bounds[i].bottom, lessThanOrEqualTo(bounds[i + 1].top), reason: name);
            }
          }
        }
      });
    });
  }

  test('reference screenshot parses to its known values', () {
    final json = _load(File('test/fixtures/ocr/$_reference.json'));
    final result = ResultParser.parse(_pieces(json));
    expect((result as ParsedRun).draft.toScores(), _referenceScores);
  });
}
