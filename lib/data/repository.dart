import 'package:drift/drift.dart';

import '../core/models.dart';
import 'database.dart';

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.runCount,
    this.lastCapturedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final int runCount;
  final DateTime? lastCapturedAt;
}

class Repository {
  Repository(this._db);

  final AppDatabase _db;

  Future<int> createSession(String name, {DateTime? createdAt}) => _db
      .into(_db.sessions)
      .insert(SessionsCompanion.insert(name: name, createdAt: createdAt ?? DateTime.now()));

  Future<Session> session(int id) =>
      (_db.select(_db.sessions)..where((s) => s.id.equals(id))).getSingle();

  Future<void> renameSession(int id, String name) =>
      (_db.update(_db.sessions)..where((s) => s.id.equals(id)))
          .write(SessionsCompanion(name: Value(name)));

  Future<void> deleteSession(int id) =>
      (_db.delete(_db.sessions)..where((s) => s.id.equals(id))).go();

  Future<List<SessionSummary>> listSessions() async {
    final runCount = _db.runs.id.count();
    final lastCaptured = _db.runs.capturedAt.max();
    final query = _db.select(_db.sessions).join([
      leftOuterJoin(_db.runs, _db.runs.sessionId.equalsExp(_db.sessions.id)),
    ])
      ..addColumns([runCount, lastCaptured])
      ..groupBy([_db.sessions.id])
      ..orderBy([
        OrderingTerm.desc(_db.sessions.createdAt),
        OrderingTerm.desc(_db.sessions.id),
      ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        _summary(row.readTable(_db.sessions), row.read(runCount) ?? 0, row.read(lastCaptured)),
    ];
  }

  SessionSummary _summary(Session s, int runCount, DateTime? lastCaptured) => SessionSummary(
        id: s.id,
        name: s.name,
        createdAt: s.createdAt,
        runCount: runCount,
        lastCapturedAt: lastCaptured,
      );

  /// Saves a run and returns its number within the session.
  ///
  /// The number is assigned inside the INSERT, so concurrent writers from
  /// the two engines can't take the same one.
  Future<int> addRun(
    int sessionId,
    RunScores scores, {
    required bool edited,
    DateTime? capturedAt,
  }) {
    return _db.transaction(() async {
      final runId = await _db.customInsert(
        'INSERT INTO runs (session_id, seq, captured_at, edited) '
        'SELECT ?1, COALESCE(MAX(seq), 0) + 1, ?2, ?3 FROM runs WHERE session_id = ?1',
        variables: [
          Variable.withInt(sessionId),
          Variable.withDateTime(capturedAt ?? DateTime.now()),
          Variable.withBool(edited),
        ],
        updates: {_db.runs},
      );
      await _insertStages(runId, scores);
      final run = await (_db.select(_db.runs)..where((r) => r.id.equals(runId))).getSingle();
      return run.seq;
    });
  }

  Future<List<RunRecord>> runs(int sessionId) async {
    final rows = await (_db.select(_db.runs)
          ..where((r) => r.sessionId.equals(sessionId))
          ..orderBy([(r) => OrderingTerm.desc(r.seq)]))
        .get();
    return _withScores(rows);
  }

  Future<RunRecord?> lastRun(int sessionId) async {
    final rows = await (_db.select(_db.runs)
          ..where((r) => r.sessionId.equals(sessionId))
          ..orderBy([(r) => OrderingTerm.desc(r.seq)])
          ..limit(1))
        .get();
    final records = await _withScores(rows);
    return records.isEmpty ? null : records.first;
  }

  Future<void> updateRun(int runId, RunScores scores) => _db.transaction(() async {
        await (_db.delete(_db.stageResults)..where((s) => s.runId.equals(runId))).go();
        await _insertStages(runId, scores);
        await (_db.update(_db.runs)..where((r) => r.id.equals(runId)))
            .write(const RunsCompanion(edited: Value(true)));
      });

  Future<void> deleteRun(int runId) =>
      (_db.delete(_db.runs)..where((r) => r.id.equals(runId))).go();

  Future<void> _insertStages(int runId, RunScores scores) => _db.batch((b) {
        b.insertAll(_db.stageResults, [
          for (var i = 0; i < scores.stages.length; i++)
            StageResultsCompanion.insert(
              runId: runId,
              stage: i + 1,
              leftScore: scores.stages[i].left,
              middleScore: scores.stages[i].middle,
              rightScore: scores.stages[i].right,
              bonus: scores.stages[i].bonus,
              total: scores.stages[i].total,
            ),
        ]);
      });

  Future<List<RunRecord>> _withScores(List<Run> rows) async {
    if (rows.isEmpty) return const [];
    final stageRows = await (_db.select(_db.stageResults)
          ..where((s) => s.runId.isIn(rows.map((r) => r.id))))
        .get();
    final byRun = <int, List<StageResult>>{};
    for (final s in stageRows) {
      (byRun[s.runId] ??= []).add(s);
    }
    return [
      for (final r in rows)
        RunRecord(
          id: r.id,
          seq: r.seq,
          capturedAt: r.capturedAt,
          edited: r.edited,
          scores: _scores(byRun[r.id]!),
        ),
    ];
  }

  RunScores _scores(List<StageResult> rows) {
    rows.sort((a, b) => a.stage.compareTo(b.stage));
    return RunScores([
      for (final s in rows)
        StageScores(
          left: s.leftScore,
          middle: s.middleScore,
          right: s.rightScore,
          bonus: s.bonus,
          total: s.total,
        ),
    ]);
  }
}
