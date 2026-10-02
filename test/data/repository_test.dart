import 'dart:io';

import 'package:concapt/data/database.dart';
import 'package:concapt/data/repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() => db.close());

  test('a new session lists with no runs', () async {
    await repo.createSession('Week 3 · A', createdAt: DateTime(2026, 10, 1));
    final sessions = await repo.listSessions();
    expect(sessions.single.name, 'Week 3 · A');
    expect(sessions.single.runCount, 0);
    expect(sessions.single.lastCapturedAt, isNull);
  });

  test('sessions list newest first with counts', () async {
    final older = await repo.createSession('older', createdAt: DateTime(2026, 9, 1));
    await repo.createSession('newer', createdAt: DateTime(2026, 10, 1));
    await repo.addRun(older, referenceScores(), edited: false, capturedAt: DateTime(2026, 9, 2, 10));
    final sessions = await repo.listSessions();
    expect(sessions.map((s) => s.name), ['newer', 'older']);
    expect(sessions[1].runCount, 1);
    expect(sessions[1].lastCapturedAt, DateTime(2026, 9, 2, 10));
  });

  test('runs number from 1 and round-trip their scores', () async {
    final sid = await repo.createSession('s');
    expect(await repo.addRun(sid, referenceScores(), edited: false), 1);
    expect(await repo.addRun(sid, scoresWithLeft(1), edited: true), 2);
    final runs = await repo.runs(sid);
    expect(runs.map((r) => r.seq), [2, 1]);
    expect(runs[1].scores, referenceScores());
    expect(runs[0].edited, isTrue);
    expect((await repo.lastRun(sid))!.seq, 2);
  });

  test('numbering is per session', () async {
    final a = await repo.createSession('a');
    final b = await repo.createSession('b');
    await repo.addRun(a, referenceScores(), edited: false);
    expect(await repo.addRun(b, referenceScores(), edited: false), 1);
  });

  test('deleting a run never reuses a higher number', () async {
    final sid = await repo.createSession('s');
    for (var i = 0; i < 3; i++) {
      await repo.addRun(sid, referenceScores(), edited: false);
    }
    final second = (await repo.runs(sid)).firstWhere((r) => r.seq == 2);
    await repo.deleteRun(second.id);
    expect(await repo.addRun(sid, referenceScores(), edited: false), 4);
  });

  test('updating a run replaces scores and marks it edited', () async {
    final sid = await repo.createSession('s');
    await repo.addRun(sid, referenceScores(), edited: false);
    final run = (await repo.lastRun(sid))!;
    await repo.updateRun(run.id, scoresWithLeft(5));
    final updated = (await repo.lastRun(sid))!;
    expect(updated.scores, scoresWithLeft(5));
    expect(updated.edited, isTrue);
    expect(updated.seq, run.seq);
  });

  test('stages are stored as 1, 2, 3', () async {
    final sid = await repo.createSession('s');
    await repo.addRun(sid, referenceScores(), edited: false);
    final stages = await db.select(db.stageResults).get();
    expect(stages.map((s) => s.stage), unorderedEquals([1, 2, 3]));
    expect(stages.firstWhere((s) => s.stage == 3).total, 181221);
  });

  test('two runs in a session cannot share a number', () async {
    final sid = await repo.createSession('s');
    RunsCompanion run() =>
        RunsCompanion.insert(sessionId: sid, seq: 1, capturedAt: DateTime(2026, 10, 2));
    await db.into(db.runs).insert(run());
    await expectLater(db.into(db.runs).insert(run()), throwsA(isA<SqliteException>()));
  });

  test('updating a missing run throws and stores nothing', () async {
    await expectLater(repo.updateRun(999, referenceScores()), throwsA(isA<SqliteException>()));
    expect(await db.select(db.stageResults).get(), isEmpty);
  });

  test('upgrading from version 1 adds the run number index', () async {
    final dir = await Directory.systemTemp.createTemp('concapt_db');
    final file = File('${dir.path}/v1.sqlite');
    try {
      final v1 = AppDatabase(NativeDatabase(file));
      await v1.customStatement('DROP INDEX runs_session_seq');
      await v1.customStatement('PRAGMA user_version = 1');
      await v1.close();

      final v2 = AppDatabase(NativeDatabase(file));
      final index = await v2
          .customSelect("SELECT name FROM sqlite_master WHERE name = 'runs_session_seq'")
          .get();
      await v2.close();
      expect(index, hasLength(1));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('deleting a session cascades to runs and stages', () async {
    final sid = await repo.createSession('s');
    await repo.addRun(sid, referenceScores(), edited: false);
    await repo.deleteSession(sid);
    expect(await db.select(db.runs).get(), isEmpty);
    expect(await db.select(db.stageResults).get(), isEmpty);
  });

  test('rename', () async {
    final sid = await repo.createSession('old');
    await repo.renameSession(sid, 'new');
    expect((await repo.session(sid)).name, 'new');
  });

  test('two connections insert concurrently with unique seq', () async {
    // Two connections to one file are the point of this test.
    final warnedBefore = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('concapt_db');
    final file = File('${dir.path}/shared.sqlite');
    final a = AppDatabase(NativeDatabase.createInBackground(file));
    final b = AppDatabase(NativeDatabase.createInBackground(file));
    try {
      final repoA = Repository(a);
      final repoB = Repository(b);
      final sid = await repoA.createSession('shared');
      await repoB.listSessions(); // opens b after the schema exists
      final seqs = await Future.wait([
        for (var i = 0; i < 20; i++)
          (i.isEven ? repoA : repoB).addRun(sid, referenceScores(), edited: false),
      ]);
      expect(seqs.toSet().length, 20);
      expect((await repoA.runs(sid)).length, 20);
    } finally {
      await a.close();
      await b.close();
      await dir.delete(recursive: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = warnedBefore;
    }
  });
}
