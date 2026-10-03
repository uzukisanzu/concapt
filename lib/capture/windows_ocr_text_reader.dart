import 'dart:io';

import 'package:window_capture/window_capture.dart';

import '../core/text_piece.dart';
import 'text_reader.dart';

/// Windows' built-in OCR. Returns words with boxes in image pixels, like
/// ML Kit's elements.
class WindowsOcrTextReader implements TextReader {
  @override
  Future<List<TextPiece>> read(String imagePath) async => [
    for (final word in await WindowCapture.recognize(File(imagePath).absolute.path))
      TextPiece.fromJson(word.cast<String, dynamic>()),
  ];
}
