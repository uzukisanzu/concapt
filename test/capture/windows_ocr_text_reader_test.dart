import 'dart:io';

import 'package:concapt/capture/windows_ocr_text_reader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('concapt/window_capture');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return [
        {'text': '1,014,622Pt', 'l': 10.0, 't': 20.0, 'r': 110.0, 'b': 50.0},
      ];
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends an absolute path and maps words to pieces', () async {
    final pieces = await WindowsOcrTextReader().read('frame.png');

    final path = (calls.single.arguments as Map)['path'] as String;
    expect(File(path).isAbsolute, isTrue);
    final piece = pieces.single;
    expect(piece.text, '1,014,622Pt');
    expect([piece.left, piece.top, piece.right, piece.bottom], [10, 20, 110, 50]);
  });
}
