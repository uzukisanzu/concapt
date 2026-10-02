import 'package:concapt/core/stats.dart';
import 'package:concapt/ui/stats_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('shows each slot column and reports taps', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: StatsCard(
          stage: 0,
          summaries: [
            summarize(const [100000, 120000]),
            summarize(const [40000]),
            summarize(const []),
          ],
          onSlotTap: tapped.add,
        ),
      ),
    ));

    expect(find.text('Stage 1'), findsOneWidget);
    expect(find.text('110,000'), findsWidgets); // mean and median of left
    expect(find.text('40,000'), findsWidgets);
    expect(find.text('—'), findsNWidgets(6)); // right slot, every stat but n
    await tester.tap(find.byKey(const Key('slot-0-1')));
    expect(tapped, [1]);
  });

  testWidgets('each slot column is one labeled button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: StatsCard(
          stage: 0,
          summaries: [
            summarize(const [63227]),
            summarize(const [40000]),
            summarize(const []),
          ],
          onSlotTap: (_) {},
        ),
      ),
      locale: const Locale('ja'),
    ));

    expect(
      tester.getSemantics(find.byKey(const Key('slot-0-0'))),
      matchesSemantics(
        label: 'ステージ1 #1, 平均 63,227, n 1',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('63,227'), findsNothing);
    expect(find.bySemanticsLabel('01'), findsNothing);
    expect(
      tester.getSemantics(find.text('ステージ1')),
      matchesSemantics(label: 'ステージ1', isHeader: true),
    );
    expect(tester.getSize(find.byKey(const Key('slot-0-0'))).height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('means keep a gutter from the column rules at font scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(411, 904);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(
      MediaQuery(
        data: const MediaQueryData(size: Size(411, 904), textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: StatsCard(
            stage: 0,
            summaries: [
              summarize(const [1307173]),
              summarize(const [1510666]),
              summarize(const [1246955]),
            ],
            onSlotTap: (_) {},
          ),
        ),
      ),
    ));

    final means = [
      for (final v in ['1,307,173', '1,510,666', '1,246,955']) tester.getRect(find.text(v).first),
    ];
    for (var slot = 1; slot < 3; slot++) {
      final rule = tester.getRect(find.byKey(Key('slot-0-$slot'))).left;
      expect(rule - means[slot - 1].right, greaterThanOrEqualTo(8));
      expect(means[slot].left - rule, greaterThanOrEqualTo(8));
    }
  });

  test('summaryRows lists the seven stats in order', () {
    final rows = summaryRows(en(), summarize(const [1, 2, 3]));
    expect(rows.map((r) => r.$1), ['n', 'Mean', 'Median', 'Min', 'Max', 'P25', 'P75']);
    expect(rows.first.$2, 3);
  });
}
