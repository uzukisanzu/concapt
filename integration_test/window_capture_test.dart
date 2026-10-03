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
