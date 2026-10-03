import '../core/models.dart';
import '../core/pixel_rect.dart';
import '../core/result_parser.dart';
import '../core/text_piece.dart';
import 'text_reader.dart';

const _scales = [2.0, 3.0];
final _nonDigits = RegExp(r'\D');

/// Re-reads the total of each stage that fails the sum check but has all its
/// members. Windows OCR drops or garbles some totals, like `204,444Pt`, yet
/// reads them once `Pt` is cut off, so the crop's right edge sweeps leftward
/// across the total line. A reading counts only if it equals the members
/// plus the bonus. Past [deadline] no more reads start; totals confirmed by
/// then are kept.
Future<RunDraft> rereadTotals(
  RegionReader reader,
  String imagePath,
  ParsedRun run, {
  DateTime? deadline,
}) async {
  final stages = [...run.draft.stages];
  for (var i = 0; i < stages.length; i++) {
    final stage = stages[i];
    final expected = stage.fixFor(3);
    if (stage.isValid || expected == null) continue;
    if (await _confirms(reader, imagePath, run.totalLines[i], expected, deadline)) {
      stages[i] = StageDraft(
        left: stage.left,
        middle: stage.middle,
        right: stage.right,
        total: expected,
      );
    }
  }
  return RunDraft(stages);
}

Future<bool> _confirms(
  RegionReader reader,
  String imagePath,
  PixelRect line,
  int expected,
  DateTime? deadline,
) async {
  final step = line.height / 6;
  for (var right = line.right; right > line.left + line.width / 2; right -= step) {
    final crop = PixelRect(line.left, line.top, right, line.bottom);
    for (final scale in _scales) {
      if (deadline != null && DateTime.now().isAfter(deadline)) return false;
      final List<TextPiece> pieces;
      try {
        pieces = await reader.readRegion(imagePath, crop, scale);
      } catch (_) {
        continue;
      }
      if (pieces.map((p) => p.text).join().replaceAll(_nonDigits, '') == '$expected') return true;
    }
  }
  return false;
}
