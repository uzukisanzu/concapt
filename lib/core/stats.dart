import 'models.dart';

class Summary {
  const Summary({
    required this.n,
    this.mean,
    this.median,
    this.min,
    this.max,
    this.p25,
    this.p75,
  });

  final int n;
  final double? mean;
  final double? median;
  final double? min;
  final double? max;
  final double? p25;
  final double? p75;
}

Summary summarize(List<int> values) {
  if (values.isEmpty) return const Summary(n: 0);
  final sorted = [...values]..sort();
  final total = sorted.fold<int>(0, (a, v) => a + v);
  return Summary(
    n: sorted.length,
    mean: total / sorted.length,
    median: percentile(sorted, 0.5),
    min: sorted.first.toDouble(),
    max: sorted.last.toDouble(),
    p25: percentile(sorted, 0.25),
    p75: percentile(sorted, 0.75),
  );
}

/// Linear interpolation between closest ranks, like Excel's PERCENTILE.INC.
/// [sorted] must be non-empty and ascending.
double percentile(List<int> sorted, double p) {
  final rank = p * (sorted.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
}

/// One member's scores across runs: [stage] 0–2, [slot] 0 left, 1 middle, 2 right.
List<int> seriesValues(List<RunRecord> runs, int stage, int slot) =>
    [for (final run in runs) run.scores.member(stage, slot)];
