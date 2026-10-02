/// A rectangle in image pixels.
class PixelRect {
  const PixelRect(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  /// This rect, cut to an image of [width] × [height].
  PixelRect clamp(double width, double height) => PixelRect(
    left.clamp(0, width).toDouble(),
    top.clamp(0, height).toDouble(),
    right.clamp(0, width).toDouble(),
    bottom.clamp(0, height).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is PixelRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'PixelRect($left, $top, $right, $bottom)';
}
