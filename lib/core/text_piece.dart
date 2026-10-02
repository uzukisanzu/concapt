/// One word recognized by OCR, with its box in image pixels.
class TextPiece {
  const TextPiece(this.text, this.left, this.top, this.right, this.bottom);

  factory TextPiece.fromJson(Map<String, dynamic> json) => TextPiece(
    json['text'] as String,
    (json['l'] as num).toDouble(),
    (json['t'] as num).toDouble(),
    (json['r'] as num).toDouble(),
    (json['b'] as num).toDouble(),
  );

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;

  Map<String, Object> toJson() => {'text': text, 'l': left, 't': top, 'r': right, 'b': bottom};

  @override
  String toString() => 'TextPiece("$text" @ $left,$top–$right,$bottom)';
}
