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

  test('summaryRows lists the seven stats in order', () {
    final rows = summaryRows(en(), summarize(const [1, 2, 3]));
    expect(rows.map((r) => r.$1), ['n', 'Mean', 'Median', 'Min', 'Max', 'P25', 'P75']);
    expect(rows.first.$2, 3);
  });
}
