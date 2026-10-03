import 'dart:io';

import 'package:concapt/capture/capture_source.dart';
import 'package:concapt/capture/window_capture_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('concapt/window_capture');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory dir;
  late List<MethodCall> calls;
  String? error;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('concapt');
    calls = [];
    error = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (error != null) throw PlatformException(code: error!);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    dir.deleteSync(recursive: true);
  });

  WindowCaptureSource source(int handle) =>
      WindowCaptureSource(() => handle, directory: () async => dir);

  test('captures the current window into the cache folder', () async {
    final path = await source(42).capture();

    expect(path, '${dir.path}${Platform.pathSeparator}capture.png');
    final args = calls.single.arguments as Map;
    expect(args['handle'], 42);
    expect(args['path'], path);
  });

  test('a closed or minimized window becomes WindowUnavailableException', () async {
    error = 'closed';
    await expectLater(
      source(1).capture(),
      throwsA(
        isA<WindowUnavailableException>().having(
          (e) => e.reason,
          'reason',
          WindowUnavailableReason.closed,
        ),
      ),
    );
    error = 'minimized';
    await expectLater(
      source(1).capture(),
      throwsA(
        isA<WindowUnavailableException>().having(
          (e) => e.reason,
          'reason',
          WindowUnavailableReason.minimized,
        ),
      ),
    );
  });

  test('other failures pass through', () async {
    error = 'no_frame';
    await expectLater(source(1).capture(), throwsA(isA<PlatformException>()));
  });
}
