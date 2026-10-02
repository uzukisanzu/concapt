import 'models.dart';

const _fields = ['left', 'middle', 'right', 'bonus', 'total'];

/// One row per run, raw values only, ordered by run number.
String buildCsv(List<RunRecord> runs) {
  final header = [
    'run',
    'captured_at',
    for (var s = 1; s <= RunScores.stageCount; s++)
      for (final f in _fields) 's${s}_$f',
  ];
  final ordered = [...runs]..sort((a, b) => a.seq.compareTo(b.seq));
  final b = StringBuffer()..writeln(header.join(','));
  for (final run in ordered) {
    b.writeln([
      run.seq,
      _timestamp(run.capturedAt),
      for (final s in run.scores.stages) ...[s.left, s.middle, s.right, s.bonus, s.total],
    ].join(','));
  }
  return b.toString();
}

String _timestamp(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}'
    'T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

String _two(int v) => v.toString().padLeft(2, '0');
