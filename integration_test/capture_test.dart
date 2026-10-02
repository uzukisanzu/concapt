import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:screen_capture/screen_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the screen after consent and stops cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Tap "Start now" on the phone'))),
    ));

    expect(await ScreenCapture.requestConsent(), isTrue,
        reason: 'Choose "Entire screen" and tap Start on the consent dialog');
    expect(await ScreenCapture.isRunning(), isTrue);

    final path = await ScreenCapture.capture();
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    final image = (await codec.getNextFrame()).image;
    final physical = tester.view.physicalSize;
    expect(image.width, physical.width.round());
    expect(image.height, greaterThanOrEqualTo(physical.height.round()));

    final pixels = (await image.toByteData())!.buffer.asUint32List();
    expect(pixels.toSet().length, greaterThan(1), reason: 'Frame is a single color');

    final stopped = ScreenCapture.events.first;
    await ScreenCapture.stop();
    expect(await stopped.timeout(const Duration(seconds: 5)), 'stopped');
    expect(await ScreenCapture.isRunning(), isFalse);
    await expectLater(
      ScreenCapture.capture(),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'not_running')),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
