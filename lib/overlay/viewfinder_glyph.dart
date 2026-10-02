import 'package:flutter/widgets.dart';

/// The launcher icon's viewfinder and histogram, drawn as the bubble's glyph.
class ViewfinderGlyph extends StatelessWidget {
  const ViewfinderGlyph({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GlyphPainter(color));
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color);

  final Color color;

  // Coordinates from assets/icon/foreground.svg, framed to 30–78 on both axes.
  static const _origin = 30.0;
  static const _extent = 48.0;

  // Thicker than the icon's 4, so the corners hold up at 24dp.
  static const _cornerWidth = 5.5;

  static const _bars = [
    Rect.fromLTWH(37.5, 64, 4.5, 4),
    Rect.fromLTWH(43.2, 61, 4.5, 7),
    Rect.fromLTWH(48.9, 56, 4.5, 12),
    Rect.fromLTWH(54.6, 48, 4.5, 20),
    Rect.fromLTWH(60.3, 42, 4.5, 26),
    Rect.fromLTWH(66, 54, 4.5, 14),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.width / _extent)
      ..translate(-_origin, -_origin);

    final corners = Path()
      ..moveTo(32, 42)
      ..lineTo(32, 32)
      ..lineTo(42, 32)
      ..moveTo(66, 32)
      ..lineTo(76, 32)
      ..lineTo(76, 42)
      ..moveTo(76, 66)
      ..lineTo(76, 76)
      ..lineTo(66, 76)
      ..moveTo(42, 76)
      ..lineTo(32, 76)
      ..lineTo(32, 66);
    canvas.drawPath(
      corners,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _cornerWidth,
    );

    final fill = Paint()..color = color;
    for (final bar in _bars) {
      canvas.drawRect(bar, fill);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color;
}
