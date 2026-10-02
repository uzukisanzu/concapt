import 'package:concapt/data/database.dart';
import 'package:concapt/data/repository.dart';
import 'package:concapt/ui/sessions_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('the capturing session carries a tab', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    final repo = Repository(db);
    late int capturing;
    await tester.runAsync(() async {
      await repo.createSession('A');
      capturing = await repo.createSession('B');
    });

    await tester.pumpWidget(
      localizedApp(SessionsScreen(repository: repo, capturingSession: () async => capturing)),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('Capturing'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('session-$capturing')),
        matching: find.text('Capturing'),
      ),
      findsOneWidget,
    );
  });
}
