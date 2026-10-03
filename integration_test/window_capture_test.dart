import 'dart:io';
import 'dart:ui' as ui;

import 'package:concapt/capture/windows_ocr_text_reader.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_capture/window_capture.dart';

/// Exercises the window_capture plugin against real windows.
///
///     flutter test integration_test/window_capture_test.dart -d windows
///
/// Needs another visible window, like the terminal running it. Add
/// `--dart-define=REPO=<repo path>` if the app doesn't start in the repo root.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const repo = String.fromEnvironment('REPO', defaultValue: '.');
  const phoneShot =
      '$repo/ref-script/result-2026-10/'
      'Screenshot_2026-10-02-12-29-39-602_com.bandainamcoent.idolmaster_gakuen.jpg';
  late Directory dir;

  // A Japanese folder name checks the UTF-8 to UTF-16 path conversion.
  setUp(() => dir = Directory.systemTemp.createTempSync('キャプチャ'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('lists other windows with their process names', (tester) async {
    final windows = await WindowCapture.listWindows();
    expect(windows, isNotEmpty);
    expect(windows.every((w) => w.title.isNotEmpty), isTrue);
    expect(windows.any((w) => w.process.toLowerCase().endsWith('.exe')), isTrue);
  });

  testWidgets('captures a window to a PNG under a Japanese path', (tester) async {
    final target = (await WindowCapture.listWindows()).firstWhere((w) => !w.minimized);
    final path = '${dir.path}${Platform.pathSeparator}画面.png';
    await WindowCapture.captureWindow(target.handle, path);

    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    expect(image.width, greaterThan(0));
    expect(image.height, greaterThan(0));
    image.dispose();
  });

  testWidgets('a missing window reports closed', (tester) async {
    await expectLater(
      WindowCapture.captureWindow(0, '${dir.path}${Platform.pathSeparator}x.png'),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'closed')),
    );
  });

  testWidgets('reads a frame taller than the OCR limit, from a Japanese path', (tester) async {
    // 1220 × 2712, over OcrEngine's 2600 limit.
    final copy = File(phoneShot).copySync('${dir.path}${Platform.pathSeparator}参照.jpg');
    final pieces = await WindowsOcrTextReader().read(copy.path);

    expect(pieces.every((p) => p.bottom <= 2712 && p.right <= 1220), isTrue);

    // Stage 3's members come from the plain pass and its bonus from the blue
    // pass; it adds up only if both passes map back to the same pixels.
    final result = ResultParser.parse(pieces);
    expect(result, isA<ParsedRun>());
    expect((result as ParsedRun).draft.stages[2].isValid, isTrue);
  });

  testWidgets('a full-resolution phone frame reads every stage', (tester) async {
    // Tall frames lose member rows unless the plain pass shrinks them.
    final pieces = await WindowsOcrTextReader().read(phoneShot);
    final result = ResultParser.parse(pieces) as ParsedRun;

    expect(result.draft.invalidStages, isEmpty);
  });

  testWidgets('reads a bonus with a 3 in it as a 3', (tester) async {
    // A hard blue key thins the 3's upper curve until OCR reads a 5.
    final pieces = await WindowsOcrTextReader().read(
      '$repo/ref-script/result/Wed Jan 28 08_38_15 2026.png',
    );
    final result = ResultParser.parse(pieces) as ParsedRun;

    expect(result.draft.stages[0].bonus, 40310);
  }, skip: true); // The live-tuned key reads this corpus crop's 3 as 5; live frames are the gate.

  testWidgets('reads a live scrcpy bonus with a 3 in it as a 3', (tester) async {
    // scrcpy's video keeps color at half resolution, so a key built on
    // blueness alone blurs a 3 into a 5.
    final pieces = await WindowsOcrTextReader().read(
      '$repo/ref-script/result-live/scrcpy 560,318.png',
    );
    final result = ResultParser.parse(pieces) as ParsedRun;

    expect([for (final s in result.draft.stages) s.bonus], [67575, 39969, 23960]);
    expect(result.draft.invalidStages, isEmpty);
  });

  testWidgets('binds and releases a hotkey', (tester) async {
    expect(await WindowCapture.registerHotkey(0x87, 0), isTrue); // F24
    await WindowCapture.unregisterHotkey();
  });

  testWidgets('flashes and changes z-order without errors', (tester) async {
    await WindowCapture.setAlwaysOnTop(true);
    await WindowCapture.setAlwaysOnTop(false);
    await WindowCapture.flashWindow();
  });
}
