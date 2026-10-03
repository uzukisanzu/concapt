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
      return args['blueOnly'] == true
          ? [
              {'text': '+24183', 'l': 12.0, 't': 60.0, 'r': 80.0, 'b': 76.0},
            ]
          : [
              {'text': '1,014,622Pt', 'l': 10.0, 't': 20.0, 'r': 110.0, 'b': 50.0},
            ];
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reads the plain frame, then its blue text, from an absolute path', () async {
    final pieces = await WindowsOcrTextReader().read('frame.png');

    expect(calls.map((c) => c['blueOnly']), [false, true]);
    expect(calls.every((c) => File(c['path']! as String).isAbsolute), isTrue);
    expect(pieces.map((p) => p.text), ['1,014,622Pt', '+24183']);
    final bonus = pieces.last;
    expect([bonus.left, bonus.top, bonus.right, bonus.bottom], [12, 60, 80, 76]);
  });
}
