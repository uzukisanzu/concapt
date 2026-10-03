import 'package:concapt/core/models.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

void main() {
  group('StageScores', () {
    test('has value equality', () {
      const a = StageScores(left: 10, middle: 2, right: 3, total: 17);
      expect(a, const StageScores(left: 10, middle: 2, right: 3, total: 17));
      expect(a == const StageScores(left: 10, middle: 2, right: 3, total: 18), isFalse);
      expect(a.members, [10, 2, 3]);
    });

    test('the bonus is the highest member over five, rounded down', () {
      expect(const StageScores(left: 2, middle: 14, right: 3, total: 0).bonus, 2);
      expect([for (final s in referenceScores().stages) s.bonus], [24183, 21413, 25162]);
    });

    test('sum check passes when members plus bonus equal total', () {
      expect(referenceScores().stages.every((s) => s.sumOk), isTrue);
    });

    test('sum check fails when off by one', () {
      const s = StageScores(left: 10, middle: 2, right: 3, total: 18);
      expect(s.sum, 17);
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
    test('requires exactly three stages', () {
      expect(() => RunDraft(const [StageDraft()]), throwsArgumentError);
    });

    test('fields run left, middle, right, total', () {
      const stage = StageDraft(left: 10, middle: 2, right: 3, total: 17);
      expect(stage.fields, [10, 2, 3, 17]);
      expect(StageDraft.fromFields(stage.fields).toScores(), stage.toScores());
    });

    test('the bonus follows the members and is null while one is missing', () {
      expect(const StageDraft(left: 10, middle: 2, right: 3).bonus, 2);
      expect(const StageDraft(left: 10, right: 3, total: 17).bonus, isNull);
    });

    test('round-trips complete scores', () {
      final draft = RunDraft.fromScores(referenceScores());
      expect(draft.toScores(), referenceScores());
      expect(draft.invalidStages, isEmpty);
    });

    test('a missing field makes the stage invalid and toScores null', () {
      final full = RunDraft.fromScores(referenceScores());
      final draft = RunDraft([
        full.stages[0],
        StageDraft.fromFields([107065, null, 38123, 206163]),
        full.stages[2],
      ]);
      expect(draft.invalidStages, {1});
      expect(draft.toScores(), isNull);
    });

    test('a wrong sum makes the stage invalid but toScores still returns', () {
      final draft = RunDraft([
        StageDraft.fromFields([10, 2, 3, 18]),
        ...RunDraft.fromScores(referenceScores()).stages.skip(1),
      ]);
      expect(draft.invalidStages, {0});
      expect(draft.toScores(), isNotNull);
    });
  });

  group('StageDraft.fixFor', () {
    // 100 + 20 + 30 + 20 = 170, read with a wrong total.
    final stage = StageDraft.fromFields([100, 20, 30, 200]);

    test('a member below the highest takes the total minus the rest', () {
      expect(stage.fixFor(1), 50);
    });

    test('a member that becomes the highest also sets the bonus', () {
      // 125 + 20 + 30 + 25 = 200.
      expect(stage.fixFor(0), 125);
    });

    test('the total takes the sum', () {
      expect(stage.fixFor(3), 170);
    });

    test('fills the field itself when it is the only empty one', () {
      expect(StageDraft.fromFields([null, 20, 30, 170]).fixFor(0), 100);
    });

    test('is null when another field is empty', () {
      expect(StageDraft.fromFields([100, null, 30, 200]).fixFor(0), isNull);
    });

    test('is null when the result would be negative', () {
      expect(StageDraft.fromFields([100, 20, 30, 50]).fixFor(1), isNull);
    });

    test('is null when no value adds up', () {
      // 10 + x + 3 + bonus = 30 has no whole solution.
      expect(StageDraft.fromFields([10, 2, 3, 30]).fixFor(1), isNull);
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
