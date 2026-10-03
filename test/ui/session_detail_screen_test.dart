import 'dart:io';

import 'package:concapt/core/csv.dart';
import 'package:concapt/data/database.dart';
import 'package:concapt/data/repository.dart';
import 'package:concapt/ui/session_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';
import '../helpers/sample.dart';

/// A save dialog that answers with [path].
class FakeFileSelector extends FileSelectorPlatform {
  FakeFileSelector(this.path);

  final String? path;
  String? suggestedName;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    suggestedName = options.suggestedName;
    return path == null ? null : FileSaveLocation(path!);
  }
}

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

    await tester.pumpWidget(
      localizedApp(
        SessionDetailScreen(
          repository: repo,
          sessionId: sessionId,
          capturingSession: () async => null,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('Week 3'), findsOneWidget);
    expect(find.text('Start capturing'), findsOneWidget);
    expect(find.text('120,918'), findsWidgets);
  });

  testWidgets('on Windows, Export CSV saves where the save dialog says', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('export');
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final target = '${dir.path}${Platform.pathSeparator}out.csv';
    final selector = FakeFileSelector(target);
    FileSelectorPlatform.instance = selector;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    final repo = Repository(db);
    late int sessionId;
    await tester.runAsync(() async {
      sessionId = await repo.createSession('Week 3');
      await repo.addRun(sessionId, referenceScores(), edited: false);
    });

    await tester.pumpWidget(
      localizedApp(
        SessionDetailScreen(
          repository: repo,
          sessionId: sessionId,
          capturingSession: () async => null,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.tap(find.byTooltip('Export CSV'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(selector.suggestedName, 'Week 3.csv');
    final runs = await tester.runAsync(() => repo.runs(sessionId));
    expect(File(target).readAsStringSync(), buildCsv(runs!));
    debugDefaultTargetPlatformOverride = null;
  });
}
