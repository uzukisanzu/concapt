import 'dart:io';

import 'package:window_capture/window_capture.dart';

import '../core/pixel_rect.dart';
import '../core/text_piece.dart';
import 'text_reader.dart';

/// Windows' built-in OCR. Returns words with boxes in image pixels, like
/// ML Kit's elements.
class WindowsOcrTextReader implements TextReader, RegionReader {
  @override
  Future<List<TextPiece>> read(String imagePath) async =>
      _pieces(await WindowCapture.recognize(File(imagePath).absolute.path));

  @override
  Future<List<TextPiece>> readRegion(String imagePath, PixelRect region, double scale) async =>
      _pieces(
        await WindowCapture.recognize(
          File(imagePath).absolute.path,
          region: [region.left, region.top, region.right, region.bottom],
          scale: scale,
        ),
      );

  static List<TextPiece> _pieces(List<Map<Object?, Object?>> words) => [
    for (final word in words) TextPiece.fromJson(word.cast<String, dynamic>()),
  ];
}
