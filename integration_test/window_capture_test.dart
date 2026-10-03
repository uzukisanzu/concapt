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

    // OCR reads it shrunk to 1300 px; boxes come back in the frame's pixels.
    expect(pieces.every((p) => p.bottom <= 2712 && p.right <= 1220), isTrue);
    expect(pieces.any((p) => p.bottom > 1300), isTrue);
  });

  testWidgets('a full-resolution phone frame reads every stage', (tester) async {
    // Tall frames lose member rows unless the plain pass shrinks them.
    final pieces = await WindowsOcrTextReader().read(phoneShot);
    final result = ResultParser.parse(pieces) as ParsedRun;

    expect(result.draft.invalidStages, isEmpty);
  });

  testWidgets('live scrcpy frames read every stage', (tester) async {
    for (final name in ['scrcpy 560,318', 'scrcpy 816,559']) {
      final pieces = await WindowsOcrTextReader().read('$repo/ref-script/result-live/$name.png');
      final result = ResultParser.parse(pieces) as ParsedRun;

      expect(result.draft.invalidStages, isEmpty, reason: name);
    }
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
