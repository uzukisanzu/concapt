/// Scores read from one stage of a rehearsal result.
class StageScores {
  const StageScores({
    required this.left,
    required this.middle,
    required this.right,
    required this.bonus,
    required this.total,
  });

  final int left;
  final int middle;
  final int right;
  final int bonus;
  final int total;

  List<int> get members => [left, middle, right];
  int get sum => left + middle + right + bonus;
  bool get sumOk => sum == total;

  @override
  bool operator ==(Object other) =>
      other is StageScores &&
      other.left == left &&
      other.middle == middle &&
      other.right == right &&
      other.bonus == bonus &&
      other.total == total;

  @override
  int get hashCode => Object.hash(left, middle, right, bonus, total);

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
  const StageDraft({this.left, this.middle, this.right, this.bonus, this.total});

  /// Fields in [fields] order: left, middle, right, bonus, total.
  factory StageDraft.fromFields(List<int?> f) =>
      StageDraft(left: f[0], middle: f[1], right: f[2], bonus: f[3], total: f[4]);

  factory StageDraft.fromScores(StageScores s) =>
      StageDraft(left: s.left, middle: s.middle, right: s.right, bonus: s.bonus, total: s.total);

  final int? left;
  final int? middle;
  final int? right;
  final int? bonus;
  final int? total;

  List<int?> get fields => [left, middle, right, bonus, total];

  StageScores? toScores() {
    final l = left, m = middle, r = right, b = bonus, t = total;
    if (l == null || m == null || r == null || b == null || t == null) return null;
    return StageScores(left: l, middle: m, right: r, bonus: b, total: t);
  }

  /// Complete and passing the sum check.
  bool get isValid => toScores()?.sumOk ?? false;

  /// The value for [field] that makes the stage add up, given the other four.
  /// Null when another field is empty or the value would be negative.
  int? fixFor(int field) {
    final f = fields;
    var others = 0;
    for (var i = 0; i < 4; i++) {
      if (i == field) continue;
      final v = f[i];
      if (v == null) return null;
      others += v;
    }
    if (field == 4) return others;
    final total = f[4];
    if (total == null) return null;
    final value = total - others;
    return value < 0 ? null : value;
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
