import 'package:concapt/core/models.dart';
import 'package:concapt/ui/run_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';
import '../helpers/sample.dart';

Future<List<RunScores>> pumpForm(
  WidgetTester tester,
  RunDraft draft, {
  bool saveOnEnter = false,
}) async {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final saved = <RunScores>[];
  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: RunForm(initial: draft, onSave: saved.add, onCancel: () {}, saveOnEnter: saveOnEnter),
      ),
    ),
  );
  return saved;
}

Future<void> pumpReview(WidgetTester tester, RunDraft draft) async {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: RunForm(
          initial: draft,
          onSave: (_) {},
          onCancel: () {},
          foldPassing: true,
          stagePreviews: [for (var i = 0; i < 3; i++) SizedBox(key: Key('preview-$i'), height: 40)],
        ),
      ),
    ),
  );
}

RunDraft draftWithStage3Total(int total) {
  final full = RunDraft.fromScores(referenceScores());
  final s3 = full.stages[2];
  return RunDraft([
    full.stages[0],
    full.stages[1],
    StageDraft(left: s3.left, middle: s3.middle, right: s3.right, total: total),
  ]);
}

void main() {
  test('stageStatus', () {
    final l = en();
    expect(stageStatus(l, const StageDraft(left: 10, middle: 2, right: 3, total: 17)), 'Adds up');
    expect(stageStatus(l, const StageDraft(left: 10, middle: 2, right: 3, total: 16)), 'Off by +1');
    expect(
      stageStatus(l, const StageDraft(left: 10, middle: 2, right: 3, total: 1017)),
      'Off by −1,000',
    );
    expect(stageStatus(l, const StageDraft(left: 1)), 'Missing values');
  });

  testWidgets('a valid draft saves directly', (tester) async {
    final saved = await pumpForm(tester, RunDraft.fromScores(referenceScores()));
    expect(find.text('Adds up'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(saved.single, referenceScores());
  });

  testWidgets('fixing a field updates the status live', (tester) async {
    await pumpForm(tester, draftWithStage3Total(181222));
    expect(find.text('Off by −1'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field-2-3')), '181221');
    await tester.pump();
    expect(find.text('Adds up'), findsNWidgets(3));
  });

  testWidgets('the bonus follows the members and cannot be typed', (tester) async {
    await pumpForm(tester, RunDraft.fromScores(referenceScores()));
    expect(find.byKey(const Key('bonus-0')), findsOneWidget);
    expect(find.text('24,183'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('field-0-0')), '125000');
    await tester.pump();
    expect(find.text('25,000'), findsOneWidget);
    expect(find.text('24,183'), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('bonus-0')), matching: find.byType(EditableText)),
      findsNothing,
    );
  });

  testWidgets('with saveOnEnter, Enter in a field saves', (tester) async {
    final saved = await pumpForm(tester, RunDraft.fromScores(referenceScores()), saveOnEnter: true);
    await tester.tap(find.byKey(const Key('field-0-3')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(saved.single, referenceScores());
  });

  testWidgets('without saveOnEnter, Enter in a field does not save', (tester) async {
    final saved = await pumpForm(tester, RunDraft.fromScores(referenceScores()));
    await tester.tap(find.byKey(const Key('field-0-3')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
  });

  testWidgets('the quick fix fills the focused field', (tester) async {
    await pumpForm(tester, draftWithStage3Total(181222));
    await tester.tap(find.byKey(const Key('field-0-0')));
    await tester.pump();
    expect(find.byKey(const Key('fix-0')), findsNothing);

    await tester.tap(find.byKey(const Key('field-2-3')));
    await tester.pump();
    expect(find.text('Total → 181,221'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fix-2')));
    await tester.pump();
    expect(find.text('Adds up'), findsNWidgets(3));
    expect(find.byKey(const Key('fix-2')), findsNothing);
  });

  testWidgets('in a narrow form the quick fix shortens the stage label', (tester) async {
    await pumpReview(tester, draftWithStage3Total(181222));
    tester.view.physicalSize = const Size(840, 2800);
    await tester.tap(find.byKey(const Key('field-2-3')));
    await tester.pump();
    expect(find.byKey(const Key('fix-2')), findsOneWidget);
  });

  testWidgets('review folds passing stages and opens failing ones', (tester) async {
    await pumpReview(tester, draftWithStage3Total(181222));
    expect(find.byKey(const Key('field-0-0')), findsNothing);
    expect(find.byKey(const Key('preview-0')), findsNothing);
    expect(find.byKey(const Key('field-2-0')), findsOneWidget);
    expect(find.byKey(const Key('preview-2')), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNWidgets(2));
    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    await tester.tap(find.byKey(const Key('band-0')));
    await tester.pump();
    expect(find.byKey(const Key('field-0-0')), findsOneWidget);
    expect(find.byKey(const Key('preview-0')), findsOneWidget);
  });

  testWidgets('folding a focused failing stage shows its status again', (tester) async {
    await pumpReview(tester, draftWithStage3Total(181222));
    await tester.tap(find.byKey(const Key('field-2-3')));
    await tester.pump();
    expect(find.byKey(const Key('fix-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('band-2')));
    await tester.pump();
    expect(find.byKey(const Key('field-2-3')), findsNothing);
    expect(find.byKey(const Key('fix-2')), findsNothing);
    expect(find.text('Off by −1'), findsOneWidget);
  });

  testWidgets('save still checks folded stages', (tester) async {
    await pumpReview(tester, draftWithStage3Total(181222));
    await tester.tap(find.byKey(const Key('band-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text("Stage 3 doesn't add up."), findsOneWidget);
  });

  testWidgets('the plain form has no fold bands', (tester) async {
    await pumpForm(tester, draftWithStage3Total(181222));
    expect(find.byKey(const Key('band-0')), findsNothing);
    expect(find.byKey(const Key('field-0-0')), findsOneWidget);
  });

  testWidgets('a failing sum asks before saving', (tester) async {
    final saved = await pumpForm(tester, draftWithStage3Total(181222));
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Save anyway?'), findsOneWidget);
    expect(find.text("Stage 3 doesn't add up."), findsOneWidget);
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();
    expect(saved.single.stages[2].total, 181222);
  });

  testWidgets('a missing field disables save', (tester) async {
    await pumpForm(tester, RunDraft.fromScores(referenceScores()));
    await tester.enterText(find.byKey(const Key('field-1-0')), '');
    // While focused, the emptied field offers its quick fix instead of the status.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final save = tester.widget<FilledButton>(find.byKey(const Key('save')));
    expect(save.onPressed, isNull);
    expect(find.text('Missing values'), findsOneWidget);
  });
}
