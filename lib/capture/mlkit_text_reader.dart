import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/text_piece.dart';
import 'text_reader.dart';

/// On-device ML Kit recognizer, Latin script. Returns words, not lines,
/// so ML Kit can't merge the three member scores into one piece.
class MlKitTextReader implements TextReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<List<TextPiece>> read(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          for (final e in line.elements)
            TextPiece(
              e.text,
              e.boundingBox.left,
              e.boundingBox.top,
              e.boundingBox.right,
              e.boundingBox.bottom,
            ),
    ];
  }

  Future<void> close() => _recognizer.close();
}
