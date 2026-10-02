import 'package:concapt/core/pixel_rect.dart';
import 'package:concapt/overlay/capture_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('a strip spans the width at its crop ratio and collapses on tap', (tester) async {
    final image = (await tester.runAsync(() => createTestImage(width: 1000, height: 2000)))!;
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: CaptureStrip(image: image, rect: const PixelRect(100, 200, 600, 300)),
          ),
        ),
      ),
    ));

    final size = tester.getSize(find.byKey(const Key('strip')));
    expect(size.width, 400);
    expect(size.height, closeTo(80, 0.5)); // a 500 × 100 crop at 400 wide

    await tester.tap(find.byKey(const Key('strip')));
    await tester.pump();
    expect(find.byKey(const Key('strip')), findsNothing);
    expect(find.text('Show capture'), findsOneWidget);

    await tester.tap(find.text('Show capture'));
    await tester.pump();
    expect(find.byKey(const Key('strip')), findsOneWidget);
  });

  testWidgets('a strip past the frame edge is clamped to it', (tester) async {
    final image = (await tester.runAsync(() => createTestImage(width: 1000, height: 2000)))!;
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: CaptureStrip(image: image, rect: const PixelRect(-50, 1900, 1100, 2100)),
          ),
        ),
      ),
    ));
    // Clamped to 1000 × 100, so 40 tall at 400 wide.
    expect(tester.getSize(find.byKey(const Key('strip'))).height, closeTo(40, 0.5));
  });

  testWidgets('a collapsed strip starts as the show row', (tester) async {
    final image = (await tester.runAsync(() => createTestImage(width: 10, height: 10)))!;
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: CaptureStrip(image: image, rect: const PixelRect(0, 0, 10, 10), collapsed: true),
      ),
    ));
    expect(find.byKey(const Key('strip')), findsNothing);
    expect(find.text('Show capture'), findsOneWidget);
  });

  test('decodeFrame returns null when the file is missing', () async {
    expect(await decodeFrame('/no/such/capture.png'), isNull);
  });
}
