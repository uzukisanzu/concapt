import 'dart:convert';
import 'dart:io';

import 'package:concapt/capture/windows_ocr_text_reader.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Reads every corpus image with Windows OCR, records the output as
/// fixtures, and reports how many pass the sum check. The corpus crops are
/// harder than live windows, so the rate is a regression measure, not a gate.
///
///     flutter test integration_test/windows_ocr_accuracy_test.dart -d windows
///
/// Reads ref-script/result/ (PC crops) and ref-script/result-2026-10/ (phone
/// captures). Fixtures land in test/fixtures/ocr-windows/, the report in
/// build/windows_ocr_report.txt. If the app doesn't start in the repo root,
/// add `--dart-define=REPO=<repo path>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows OCR accuracy over the rehearsal corpus', (tester) async {
    const repo = String.fromEnvironment('REPO', defaultValue: '.');
    final images = [
      for (final folder in ['result', 'result-2026-10'])
        ...Directory('$repo/ref-script/$folder')
            .listSync()
            .whereType<File>()
            .where((f) => _image.hasMatch(f.path)),
    ]..sort((a, b) => a.path.compareTo(b.path));
    expect(images, isNotEmpty, reason: 'No corpus under ${Directory(repo).absolute.path}');

    final out = Directory('$repo/test/fixtures/ocr-windows')..createSync(recursive: true);
    final reader = WindowsOcrTextReader();
    var passed = 0;
    final failures = <String>[];
    for (final image in images) {
      final name = image.uri.pathSegments.last.replaceFirst(_image, '');
      final pieces = await reader.read(image.path);
      final result = ResultParser.parse(pieces);
      final ok = result is ParsedRun && (result.draft.toScores()?.allSumsOk ?? false);
      if (ok) {
        passed++;
      } else {
        failures.add('$name: ${_describe(result)}');
      }
      File('${out.path}/$name.json').writeAsStringSync(
        jsonEncode({
          'passed': ok,
          'pieces': [for (final piece in pieces) piece.toJson()],
        }),
      );
    }

    final rate = passed / images.length;
    final report =
        'Passed $passed/${images.length} (${(rate * 100).toStringAsFixed(1)}%)\n'
        '${failures.join('\n')}\n';
    File('$repo/build/windows_ocr_report.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(report);
    debugPrint(report);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

final _image = RegExp(r'\.(png|jpe?g)$', caseSensitive: false);

String _describe(ParseResult result) => switch (result) {
  NoResultScreen() => 'no totals',
  IncompleteScreen(:final totalsFound) => '$totalsFound totals',
  ParsedRun(:final draft) =>
    'stages ${draft.invalidStages.map((i) => i + 1).join(',')} invalid: '
        '${[for (final s in draft.stages) s.fields].join(' | ')}',
};
