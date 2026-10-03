import 'package:concapt/core/models.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';
import '../helpers/screen.dart';

RunDraft parsedDraft(List<TextPiece> pieces) {
  final result = ResultParser.parse(pieces);
  expect(result, isA<ParsedRun>());
  return (result as ParsedRun).draft;
}

void main() {
  group('number', () {
    test('strips commas and periods', () {
      expect(ResultParser.number('120,918'), 120918);
      expect(ResultParser.number('39.482'), 39482);
    });

    test('maps lookalike letters inside numeric tokens', () {
      expect(ResultParser.number('12O,918'), 120918);
      expect(ResultParser.number('l5,385'), 15385);
      expect(ResultParser.number('|4,862'), 14862);
    });

    test('maps the lookalikes ML Kit reads in totals', () {
      expect(ResultParser.number('241,25A'), 241254);
      expect(ResultParser.number('225,98ó'), 225986);
    });

    test('rejects words and letter-only tokens', () {
      expect(ResultParser.number('Pt'), isNull);
      expect(ResultParser.number('lOl'), isNull);
      expect(ResultParser.number('58929x'), isNull);
    });

    test('rejects numbers too long for an int', () {
      expect(ResultParser.number('12,345,678,901,234,567,890'), isNull);
    });
  });

  test('reads the reference screen', () {
    final draft = parsedDraft(screenPieces(referenceScores()));
    expect(draft.toScores(), referenceScores());
    expect(draft.invalidStages, isEmpty);
  });

  test('reads Pt as a separate piece', () {
    final pieces =
        screenPieces(referenceScores()).where((piece) => piece.text != '214,882Pt').toList()
          ..addAll([p('214,882', 170, 60, width: 100, height: 24), p('Pt', 272, 64, width: 20)]);
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('splits a piece holding several numbers', () {
    final pieces =
        screenPieces(
            referenceScores(),
          ).where((piece) => !['120,918', '39,482', '30,299'].contains(piece.text)).toList()
          ..add(p('120,918 39,482 30,299', 120, 98, width: 220));
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('reads totals whose Pt is misread or missing', () {
    final misread = {'214,882Pt': '214,882r', '206,163Pt': '206,163Pr', '181,221Pt': '181.221'};
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        TextPiece(
          misread[piece.text] ?? piece.text,
          piece.left,
          piece.top,
          piece.right,
          piece.bottom,
        ),
    ];
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('total-sized lookalike-only text is not a total', () {
    final pieces = screenPieces(referenceScores())
      ..add(p('lll,lll', 170, 10, width: 130, height: 30));
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('joins a number OCR split in two', () {
    final pieces =
        screenPieces(
          referenceScores(),
        ).where((piece) => !['+24183', '181,221Pt'].contains(piece.text)).toList()..addAll([
          p('+241', 120, 118, width: 42),
          p('83', 166, 118, width: 28),
          p('181,22', 170, 540, width: 105, height: 30),
          p('1Pt', 282, 540, width: 48, height: 30),
        ]);
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('reads a 7-digit member score drawn in a smaller font', () {
    final scores = scoresWithLeft(1234567);
    final pieces = [
      for (final piece in screenPieces(scores))
        piece.text == '1,234,567' ? p('1,234,567', 120, 102, width: 58, height: 12) : piece,
    ];
    final draft = parsedDraft(pieces);
    expect(draft.stages[0].left, 1234567);
    expect(draft.toScores(), scores);
    expect(draft.invalidStages, isEmpty);
  });

  test('keeps the bonus marker when OCR spaces it off', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        piece.text == '+24183'
            ? TextPiece('+ 24183', piece.left, piece.top, piece.right, piece.bottom)
            : piece,
    ];
    final draft = parsedDraft(pieces);
    expect(draft.stages[0].bonus, 24183);
    expect(draft.toScores(), referenceScores());
  });

  test('joins a lone bonus marker read as its own piece', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        if (piece.text == '+24183') ...[
          TextPiece('+', piece.left, piece.top, piece.left + 10, piece.bottom),
          TextPiece('24183', piece.left + 16, piece.top, piece.right, piece.bottom),
        ] else
          piece,
    ];
    final draft = parsedDraft(pieces);
    expect(draft.stages[0].bonus, 24183);
    expect(draft.toScores(), referenceScores());
  });

  test('does not join a number onto a total ending in Pt.', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        piece.text == '214,882Pt'
            ? TextPiece('214,882Pt.', piece.left, piece.top, piece.right, piece.bottom)
            : piece,
      p('200', 305, 67, width: 30),
    ];
    expect(parsedDraft(pieces).stages[0].total, 214882);
  });

  test('6-digit members 0.9 heights apart stay separate', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        if (piece.text == '39,482')
          p('39,482', 194.4, 98)
        else if (piece.text == '30,299')
          p('30,299', 268.8, 98)
        else
          piece,
    ];
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('drops badge-border junk after the bonus', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        piece.text == '+24183'
            ? TextPiece('+24183)', piece.left, piece.top, piece.right, piece.bottom)
            : piece,
    ];
    expect(parsedDraft(pieces).stages[0].bonus, 24183);
  });

  test('drops crown junk before the bonus', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        piece.text == '+24183'
            ? TextPiece('@+24183', piece.left, piece.top, piece.right, piece.bottom)
            : piece,
    ];
    expect(parsedDraft(pieces).stages[0].bonus, 24183);
  });

  test('ignores placement badges, stage labels, and the total power row', () {
    final draft = parsedDraft(screenPieces(referenceScores()));
    for (final stage in draft.stages) {
      expect(stage.fields.where((v) => v != null && v < 100), isEmpty);
      expect(stage.fields, isNot(contains(58929)));
    }
  });

  test('a missing number fills the other slots by position', () {
    final pieces = screenPieces(
      referenceScores(),
    ).where((piece) => piece.text != '39,562').toList();
    final stage = parsedDraft(pieces).stages[1];
    expect(stage.left, 107065);
    expect(stage.middle, isNull);
    expect(stage.right, 38123);
    expect(stage.total, 206163);
  });

  test('an extra number in a member row keeps the slots it does not contest', () {
    final pieces = screenPieces(referenceScores())..add(p('777', 330, 98, width: 30));
    final stage = parsedDraft(pieces).stages[0];
    expect(stage.left, 120918);
    expect(stage.middle, 39482);
    expect(stage.right, isNull);
  });

  test('missing member row leaves slots empty', () {
    final pieces = screenPieces(
      referenceScores(),
    ).where((piece) => !['120,918', '39,482', '30,299'].contains(piece.text)).toList();
    final draft = parsedDraft(pieces);
    expect(draft.stages[0].left, isNull);
    expect(draft.stages[0].middle, isNull);
    expect(draft.stages[0].right, isNull);
    expect(draft.invalidStages, {0});
  });

  test('missing member row and bonus leaves slots empty', () {
    final pieces = screenPieces(
      referenceScores(),
    ).where((piece) => !['120,918', '39,482', '30,299', '+24183'].contains(piece.text)).toList();
    final stage = parsedDraft(pieces).stages[0];
    expect(stage.left, isNull);
    expect(stage.middle, isNull);
    expect(stage.right, isNull);
    expect(stage.bonus, isNull);
    expect(parsedDraft(pieces).invalidStages, {0});
  });

  test('an unsigned bonus is not read as a member', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        if (!['120,918', '39,482', '30,299'].contains(piece.text))
          piece.text == '+24183'
              ? TextPiece('24183', piece.left, piece.top, piece.right, piece.bottom)
              : piece,
    ];
    final stage = parsedDraft(pieces).stages[0];
    expect(stage.left, isNull);
    expect(stage.middle, isNull);
    expect(stage.right, isNull);
  });

  test('a wrong digit fails the sum check for that stage only', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        piece.text == '14,862'
            ? TextPiece('14,882', piece.left, piece.top, piece.right, piece.bottom)
            : piece,
    ];
    expect(parsedDraft(pieces).invalidStages, {2});
  });

  test("a dropped total line leaves that stage's total empty", () {
    for (final (stage, total) in [(2, '181,221Pt'), (1, '206,163Pt')]) {
      final pieces = screenPieces(referenceScores()).where((p) => p.text != total).toList();
      final draft = parsedDraft(pieces);
      final expected = referenceScores().stages[stage];

      expect(draft.stages[stage].total, isNull, reason: total);
      expect(draft.stages[stage].fields.take(3), expected.members, reason: total);
      expect(draft.invalidStages, {stage}, reason: total);
    }
  });

  test('two totals without a third member row is an incomplete screen', () {
    final y = stageTops[2];
    final pieces = screenPieces(
      referenceScores(),
    ).where((p) => p.top < y - 30).toList();
    final result = ResultParser.parse(pieces);
    expect(result, isA<IncompleteScreen>());
    expect((result as IncompleteScreen).totalsFound, 2);
  });

  test('no totals is not a result screen', () {
    expect(ResultParser.parse([p('Hello', 10, 10), p('12345', 10, 40)]), isA<NoResultScreen>());
    expect(ResultParser.parse(const []), isA<NoResultScreen>());
  });

  group('stage bounds', () {
    test('cover the total, members, and bonus of each stage', () {
      final result = ResultParser.parse(screenPieces(referenceScores())) as ParsedRun;
      expect(result.stageBounds, hasLength(3));
      for (var i = 0; i < 3; i++) {
        final y = stageTops[i];
        final b = result.stageBounds[i];
        expect(b.top, lessThanOrEqualTo(y));
        expect(b.left, lessThanOrEqualTo(120));
        expect(b.right, greaterThanOrEqualTo(340));
        expect(b.bottom, greaterThanOrEqualTo(y + 74));
        expect(b.bottom, lessThan(y + 110));
      }
    });

    test('a stage missing a member still spans the member columns', () {
      final y = stageTops[0];
      final pieces = screenPieces(
        referenceScores(),
      ).where((p) => !(p.left == 280 && p.top == y + 38)).toList();
      final b = (ResultParser.parse(pieces) as ParsedRun).stageBounds[0];
      expect(b.left, lessThanOrEqualTo(120));
      expect(b.right, greaterThanOrEqualTo(340));
    });

    test('without a bonus, the members set the bottom', () {
      final y = stageTops[0];
      final pieces = screenPieces(
        referenceScores(),
      ).where((p) => !(p.text.startsWith('+') && p.top == y + 58)).toList();
      final b = (ResultParser.parse(pieces) as ParsedRun).stageBounds[0];
      expect(b.bottom, greaterThanOrEqualTo(y + 54));
      expect(b.bottom, lessThan(y + 110));
    });
  });

  group('total lines', () {
    test("span each stage's strip at its total", () {
      final result = ResultParser.parse(screenPieces(referenceScores())) as ParsedRun;
      for (var i = 0; i < 3; i++) {
        final y = stageTops[i];
        final line = result.totalLines[i];
        expect(line.top, lessThanOrEqualTo(y));
        expect(line.bottom, greaterThanOrEqualTo(y + 30));
        expect(line.bottom, lessThan(y + 38));
        expect(line.left, lessThanOrEqualTo(120));
        expect(line.right, greaterThanOrEqualTo(340));
      }
    });

    test('a dropped total line sits where the others do', () {
      final pieces = screenPieces(referenceScores()).where((p) => p.text != '181,221Pt').toList();
      final result = ResultParser.parse(pieces) as ParsedRun;
      final y = stageTops[2];
      final line = result.totalLines[2];
      expect(line.top, lessThanOrEqualTo(y));
      expect(line.bottom, greaterThanOrEqualTo(y + 30));
      expect(line.bottom, lessThan(y + 38));
    });
  });
}
