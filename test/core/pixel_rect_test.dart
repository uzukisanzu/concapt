import 'package:concapt/core/pixel_rect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('width and height', () {
    const r = PixelRect(10, 20, 110, 70);
    expect(r.width, 100);
    expect(r.height, 50);
  });

  test('clamp keeps a rect inside the image', () {
    expect(
      const PixelRect(-8, -8, 1230, 900).clamp(1220, 2712),
      const PixelRect(0, 0, 1220, 900),
    );
  });
}
