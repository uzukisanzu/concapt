import 'package:concapt/core/models.dart';
import 'package:concapt/core/text_piece.dart';

TextPiece p(String text, double left, double top, {double width = 60, double height = 16}) =>
    TextPiece(text, left, top, left + width, top + height);

String commas(int value) {
  final s = value.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// One stage block as OCR sees it, starting at [y]. Proportions follow the
/// real screen: totals about 1.9× member height, members 1.25× height apart.
List<TextPiece> stagePieces({
  required double y,
  required String total,
  required List<String> members,
  required String bonus,
  String power = '58929',
}) => [
  p('${(y / 240).round() + 1}', 250, y - 30, width: 12), // ステージN label digit
  p(total, 170, y, width: 130, height: 30),
  for (var i = 0; i < members.length; i++) p(members[i], [120.0, 200.0, 280.0][i], y + 38),
  p(bonus, 120, y + 58, width: 70),
  p('1', 135, y + 110, width: 10), // placement badges
  p('2', 207, y + 110, width: 10),
  p('3', 280, y + 110, width: 10),
  p(power, 238, y + 158, width: 70), // 総合力
];

const stageTops = [60.0, 300.0, 540.0];

/// A whole result screen for [scores].
List<TextPiece> screenPieces(RunScores scores) => [
  for (var i = 0; i < 3; i++)
    ...stagePieces(
      y: stageTops[i],
      total: '${commas(scores.stages[i].total)}Pt',
      members: [for (final m in scores.stages[i].members) commas(m)],
      bonus: '+${scores.stages[i].bonus}',
    ),
];
