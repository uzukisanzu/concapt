import 'package:concapt/core/models.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

void main() {
  group('StageScores', () {
    test('sum check passes when members plus bonus equal total', () {
      expect(referenceScores().stages.every((s) => s.sumOk), isTrue);
    });

    test('sum check fails when off by one', () {
      const s = StageScores(left: 1, middle: 2, right: 3, bonus: 4, total: 11);
      expect(s.sum, 10);
      expect(s.sumOk, isFalse);
    });
  });

  group('RunScores', () {
    test('requires exactly three stages', () {
      expect(() => RunScores(const []), throwsArgumentError);
    });

    test('has value equality', () {
      expect(referenceScores(), referenceScores());
      expect(referenceScores() == scoresWithLeft(1), isFalse);
    });

    test('member reads stage and slot', () {
      expect(referenceScores().member(2, 1), 14862);
    });
  });

  group('RunDraft', () {
    test('round-trips complete scores', () {
      final draft = RunDraft.fromScores(referenceScores());
      expect(draft.toScores(), referenceScores());
      expect(draft.invalidStages, isEmpty);
    });

    test('a missing field makes the stage invalid and toScores null', () {
      final full = RunDraft.fromScores(referenceScores());
      final draft = RunDraft([
        full.stages[0],
        StageDraft.fromFields([107065, null, 38123, 21413, 206163]),
        full.stages[2],
      ]);
      expect(draft.invalidStages, {1});
      expect(draft.toScores(), isNull);
    });

    test('a wrong sum makes the stage invalid but toScores still returns', () {
      final draft = RunDraft([
        StageDraft.fromFields([1, 2, 3, 4, 11]),
        ...RunDraft.fromScores(referenceScores()).stages.skip(1),
      ]);
      expect(draft.invalidStages, {0});
      expect(draft.toScores(), isNotNull);
    });
  });

  group('StageDraft.fixFor', () {
    // 1 + 2 + 3 + 4 = 10, read with a wrong total.
    final stage = StageDraft.fromFields([1, 2, 3, 4, 20]);

    test('a member or the bonus takes the total minus the other four', () {
      expect(stage.fixFor(0), 11);
      expect(stage.fixFor(3), 14);
    });

    test('the total takes the sum', () {
      expect(stage.fixFor(4), 10);
    });

    test('fills the field itself when it is the only empty one', () {
      expect(StageDraft.fromFields([null, 2, 3, 4, 10]).fixFor(0), 1);
    });

    test('is null when another field is empty', () {
      expect(StageDraft.fromFields([1, null, 3, 4, 20]).fixFor(0), isNull);
    });

    test('is null when the result would be negative', () {
      expect(StageDraft.fromFields([100, 2, 3, 4, 10]).fixFor(1), isNull);
    });
  });

  test('TextPiece round-trips through JSON', () {
    const piece = TextPiece('214,882Pt', 10, 20, 110, 44);
    final copy = TextPiece.fromJson(piece.toJson());
    expect(copy.text, piece.text);
    expect([copy.left, copy.top, copy.right, copy.bottom], [10, 20, 110, 44]);
    expect(copy.centerY, 32);
    expect(copy.height, 24);
  });
}
