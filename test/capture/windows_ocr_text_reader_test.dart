import 'dart:io';

import 'package:concapt/capture/windows_ocr_text_reader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('concapt/window_capture');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Map<Object?, Object?>> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map<Object?, Object?>;
      calls.add(args);
      return [
        {'text': '1,014,622Pt', 'l': 10.0, 't': 20.0, 'r': 110.0, 'b': 50.0},
      ];
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reads the frame once, from an absolute path', () async {
    final pieces = await WindowsOcrTextReader().read('frame.png');

    expect(calls, hasLength(1));
    expect(File(calls.single['path']! as String).isAbsolute, isTrue);
    expect(calls.single.containsKey('blueOnly'), isFalse);
    final total = pieces.single;
    expect(total.text, '1,014,622Pt');
    expect([total.left, total.top, total.right, total.bottom], [10, 20, 110, 50]);
  });
}
