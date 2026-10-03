import 'dart:io';

import 'package:window_capture/window_capture.dart';

import '../core/text_piece.dart';
import 'text_reader.dart';

/// Windows' built-in OCR, in two passes: the frame as captured, then its
/// blue text alone, which holds the bonuses. Returns words with boxes in
/// image pixels, like ML Kit's elements.
class WindowsOcrTextReader implements TextReader {
  @override
  Future<List<TextPiece>> read(String imagePath) async {
    final path = File(imagePath).absolute.path;
    final plain = await WindowCapture.recognize(path);
    final blue = await WindowCapture.recognize(path, blueOnly: true);
    return [
      for (final word in [...plain, ...blue]) TextPiece.fromJson(word.cast<String, dynamic>()),
    ];
  }
}
