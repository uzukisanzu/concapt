import 'package:concapt/core/models.dart';

/// The run in `ref-script/result/Wed Jan 28 08_34_17 2026.png`.
RunScores referenceScores() => RunScores(const [
  StageScores(left: 120918, middle: 39482, right: 30299, total: 214882),
  StageScores(left: 107065, middle: 39562, right: 38123, total: 206163),
  StageScores(left: 125812, middle: 14862, right: 15385, total: 181221),
]);

/// A valid run like [referenceScores] whose Stage 1 left score is [left].
RunScores scoresWithLeft(int left) {
  final reference = referenceScores();
  final s1 = reference.stages[0];
  return RunScores([
    StageScores(
      left: left,
      middle: s1.middle,
      right: s1.right,
      total: left + s1.middle + s1.right + crownBonus(left, s1.middle, s1.right),
    ),
    reference.stages[1],
    reference.stages[2],
  ]);
}
