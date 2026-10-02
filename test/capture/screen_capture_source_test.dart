import 'package:concapt/capture/capture_source.dart';
import 'package:concapt/capture/screen_capture_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('concapt/screen_capture');

  void answer(Object? Function(MethodCall call) handler) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => handler(call));

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('returns the frame path', () async {
    answer((call) => call.method == 'capture' ? '/cache/capture.png' : null);
    expect(await ScreenCaptureSource().capture(), '/cache/capture.png');
  });

  test('not_running becomes CaptureStoppedException', () async {
    answer((_) => throw PlatformException(code: 'not_running'));
    await expectLater(ScreenCaptureSource().capture(), throwsA(isA<CaptureStoppedException>()));
  });

  test('other failures pass through', () async {
    answer((_) => throw PlatformException(code: 'capture_failed'));
    await expectLater(
      ScreenCaptureSource().capture(),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'capture_failed')),
    );
  });
}
