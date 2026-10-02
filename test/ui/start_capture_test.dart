import 'package:concapt/ui/start_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits until the overlay service reports active', () async {
    var calls = 0;
    final ready = await waitForOverlay(isActive: () async => ++calls >= 3);
    expect(ready, isTrue);
    expect(calls, 3);
  });

  test('gives up when the overlay never starts', () async {
    final ready = await waitForOverlay(
      isActive: () async => false,
      timeout: const Duration(milliseconds: 100),
    );
    expect(ready, isFalse);
  });
}
