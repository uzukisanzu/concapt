import '../core/pixel_rect.dart';
import '../core/text_piece.dart';

/// Recognizes words in an image file.
abstract interface class TextReader {
  Future<List<TextPiece>> read(String imagePath);
}

/// Recognizes words in part of an image file.
abstract interface class RegionReader {
  /// Words in [region], enlarged [scale] times for OCR, with boxes in image pixels.
  Future<List<TextPiece>> readRegion(String imagePath, PixelRect region, double scale);
}
