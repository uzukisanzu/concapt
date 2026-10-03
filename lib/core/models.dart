import 'dart:math';

/// The crown bonus the stage's top scorer earns: a fifth of their score,
/// rounded down.
int crownBonus(int left, int middle, int right) => max(left, max(middle, right)) ~/ 5;

/// Scores read from one stage of a rehearsal result.
class StageScores {
  const StageScores({
    required this.left,
    required this.middle,
    required this.right,
    required this.total,
  });

  final int left;
  final int middle;
  final int right;
  final int total;

  List<int> get members => [left, middle, right];
  int get bonus => crownBonus(left, middle, right);
  int get sum => left + middle + right + bonus;
  bool get sumOk => sum == total;

  @override
  bool operator ==(Object other) =>
      other is StageScores &&
      other.left == left &&
      other.middle == middle &&
      other.right == right &&
      other.total == total;

  @override
  int get hashCode => Object.hash(left, middle, right, total);

  @override
  String toString() => 'StageScores($left, $middle, $right, +$bonus = $total)';
}

/// The three stages of one rehearsal run.
class RunScores {
  RunScores(List<StageScores> stages) : stages = List.unmodifiable(stages) {
    if (stages.length != stageCount) {
      throw ArgumentError.value(stages.length, 'stages', 'expected $stageCount');
    }
  }

  static const stageCount = 3;

  final List<StageScores> stages;

  bool get allSumsOk => stages.every((s) => s.sumOk);

  int member(int stage, int slot) => stages[stage].members[slot];

  @override
  bool operator ==(Object other) {
    if (other is! RunScores) return false;
    for (var i = 0; i < stageCount; i++) {
      if (other.stages[i] != stages[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(stages);
}

/// A stage as read or typed; any field may be missing.
class StageDraft {
  const StageDraft({this.left, this.middle, this.right, this.total});

  /// Fields in [fields] order: left, middle, right, total.
  factory StageDraft.fromFields(List<int?> f) =>
      StageDraft(left: f[0], middle: f[1], right: f[2], total: f[3]);

  factory StageDraft.fromScores(StageScores s) =>
      StageDraft(left: s.left, middle: s.middle, right: s.right, total: s.total);

  final int? left;
  final int? middle;
  final int? right;
  final int? total;

  List<int?> get fields => [left, middle, right, total];

  /// Null while a member is missing.
  int? get bonus {
    final l = left, m = middle, r = right;
    return l == null || m == null || r == null ? null : crownBonus(l, m, r);
  }

  StageScores? toScores() {
    final l = left, m = middle, r = right, t = total;
    if (l == null || m == null || r == null || t == null) return null;
    return StageScores(left: l, middle: m, right: r, total: t);
  }

  /// Complete and passing the sum check.
  bool get isValid => toScores()?.sumOk ?? false;

  /// The value for [field] that makes the stage add up, given the other three.
  /// Null when another field is empty or no non-negative value adds up.
  int? fixFor(int field) {
    if (field == 3) {
      final b = bonus;
      return b == null ? null : left! + middle! + right! + b;
    }
    final others = [
      for (var i = 0; i < 3; i++)
        if (i != field) fields[i],
    ];
    final a = others[0], b = others[1], t = total;
    if (a == null || b == null || t == null) return null;
    final highest = max(a, b);
    final rest = t - a - b;

    // At most the highest of the other two, the member leaves the bonus as is.
    final below = rest - highest ~/ 5;
    if (below >= 0 && below <= highest) return below;

    // Above it, the member sets the bonus: x + ⌊x / 5⌋ = rest.
    final above = (5 * rest + 5) ~/ 6;
    return above > highest && above + above ~/ 5 == rest ? above : null;
  }
}

/// A run as read or typed, before it is saved.
class RunDraft {
  RunDraft(List<StageDraft> stages) : stages = List.unmodifiable(stages) {
    if (stages.length != RunScores.stageCount) {
      throw ArgumentError.value(stages.length, 'stages', 'expected ${RunScores.stageCount}');
    }
  }

  factory RunDraft.fromScores(RunScores scores) =>
      RunDraft([for (final s in scores.stages) StageDraft.fromScores(s)]);

  final List<StageDraft> stages;

  /// Indices of stages that are incomplete or fail the sum check.
  Set<int> get invalidStages => {
    for (var i = 0; i < stages.length; i++)
      if (!stages[i].isValid) i,
  };

  /// Null while any field is missing; sums are not checked.
  RunScores? toScores() {
    final scores = [for (final s in stages) s.toScores()];
    if (scores.any((s) => s == null)) return null;
    return RunScores(scores.cast<StageScores>());
  }
}

/// A saved run.
class RunRecord {
  const RunRecord({
    required this.id,
    required this.seq,
    required this.capturedAt,
    required this.edited,
    required this.scores,
  });

  final int id;

  /// Run number within its session, starting at 1.
  final int seq;
  final DateTime capturedAt;

  /// True when the user corrected the numbers by hand.
  final bool edited;
  final RunScores scores;
}
