import 'package:concapt/overlay/overlay_sizes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('showOverlay takes pixels', () {
    expect(OverlaySizes.showUnits(56, 3), 168);
    expect(OverlaySizes.showUnits(340, 2.75), 935);
  });

  test('resizeOverlay takes dp', () {
    expect(OverlaySizes.resizeUnits(56), 56);
    expect(OverlaySizes.resizeUnits(340.4), 340);
  });
}
