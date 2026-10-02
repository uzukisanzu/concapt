import '../core/text_piece.dart';

/// Recognizes words in an image file.
abstract interface class TextReader {
  Future<List<TextPiece>> read(String imagePath);
}
