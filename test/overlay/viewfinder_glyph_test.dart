import 'package:concapt/overlay/viewfinder_glyph.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sizes to an icon square', (tester) async {
    await tester.pumpWidget(const Center(child: ViewfinderGlyph(color: Color(0xFFFFFFFF))));

    expect(tester.getSize(find.byType(ViewfinderGlyph)), const Size.square(24));
  });
}
