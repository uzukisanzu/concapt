import 'dart:convert';
import 'dart:io';

import 'package:concapt/capture/mlkit_text_reader.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Reads every corpus image, records ML Kit's output as fixtures, and
/// reports how many pass the sum check.
///
/// `flutter test` reinstalls the app and wipes the corpus in its data
/// folder, so run this as an APK instead:
///
///     flutter build apk --debug -t integration_test/ocr_accuracy_test.dart
///     adb install -r build/app/outputs/flutter-apk/app-debug.apk
///     adb shell am start -n dev.concapt.app/.MainActivity
///
/// The result prints to `logcat -s flutter`. Fixtures and report.txt land in
/// /sdcard/Android/data/dev.concapt.app/files/fixtures; the corpus goes in
/// files/corpus beside it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR accuracy over the rehearsal corpus', (tester) async {
    final base = (await getExternalStorageDirectory())!;
    final corpus = Directory('${base.path}/corpus');
    final out = Directory('${base.path}/fixtures')..createSync(recursive: true);
    final images = corpus.existsSync()
        ? (corpus.listSync().whereType<File>().where((f) => _image.hasMatch(f.path)).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];
    expect(images, isNotEmpty, reason: 'Push the corpus to ${corpus.path} first');

    final reader = MlKitTextReader();
    var passed = 0;
    final failures = <String>[];
    try {
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
        File('${out.path}/$name.json').writeAsStringSync(jsonEncode({
          'passed': ok,
          'pieces': [for (final piece in pieces) piece.toJson()],
        }));
      }
    } finally {
      await reader.close();
    }

    final rate = passed / images.length;
    final report = 'Passed $passed/${images.length} (${(rate * 100).toStringAsFixed(1)}%)\n'
        '${failures.join('\n')}\n';
    File('${out.path}/report.txt').writeAsStringSync(report);
    debugPrint(report);
    expect(rate, greaterThanOrEqualTo(0.9), reason: report);
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
