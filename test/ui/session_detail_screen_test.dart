import 'package:concapt/data/database.dart';
import 'package:concapt/data/repository.dart';
import 'package:concapt/ui/session_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';
import '../helpers/sample.dart';

void main() {
  test('csvFileName keeps Japanese and replaces what a file name cannot hold', () {
    expect(csvFileName('第3週 · A'), '第3週 · A.csv');
    expect(csvFileName('a/b:c'), 'a_b_c.csv');
    expect(csvFileName('  '), 'session.csv');
  });

  testWidgets('shows the session, its runs, and the capture button', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    final repo = Repository(db);
    late int sessionId;
    await tester.runAsync(() async {
      sessionId = await repo.createSession('Week 3');
      await repo.addRun(sessionId, referenceScores(), edited: false);
    });

    await tester.pumpWidget(localizedApp(
      SessionDetailScreen(
        repository: repo,
        sessionId: sessionId,
        capturingSession: () async => null,
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('Week 3'), findsOneWidget);
    expect(find.text('Start capturing'), findsOneWidget);
    expect(find.text('120,918'), findsWidgets);
  });
}
