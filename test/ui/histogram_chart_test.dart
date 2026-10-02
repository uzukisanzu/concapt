import 'package:concapt/core/histogram.dart';
import 'package:concapt/ui/histogram_chart.dart';
import 'package:concapt/ui/series_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';

Finder get painter =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is HistogramPainter);

void main() {
  testWidgets('empty series shows a message instead of a chart', (tester) async {
    await tester.pumpWidget(localizedApp(
      const Scaffold(body: HistogramChart(histogram: Histogram.empty)),
    ));
    expect(find.text('No runs yet'), findsOneWidget);
    expect(painter, findsNothing);
  });

  testWidgets('a series draws bars and labels its markers', (tester) async {
    final values = [for (var i = 0; i < 300; i++) 113000 + (i * 7919) % 15000];
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: SingleChildScrollView(
          child: HistogramChart(histogram: buildHistogram(values), mean: 120000, median: 119500),
        ),
      ),
    ));
    expect(painter, findsOneWidget);
    expect(find.text('Mean 120,000'), findsOneWidget);
    expect(find.text('Median 119,500'), findsOneWidget);
  });

  testWidgets('series detail shows the chart and all seven stats', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(
      const SeriesDetailScreen(title: 'Stage 1 · Left', values: [100, 200, 300]),
    ));
    expect(find.text('Stage 1 · Left'), findsOneWidget);
    expect(painter, findsOneWidget);
    for (final label in ['n', 'Mean', 'Median', 'Min', 'Max', 'P25', 'P75']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('empty series detail does not crash', (tester) async {
    await tester.pumpWidget(localizedApp(
      const SeriesDetailScreen(title: 'Stage 1 · Left', values: []),
    ));
    expect(find.text('No runs yet'), findsOneWidget);
  });

  testWidgets('dark theme renders the chart', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(localizedApp(
      const SeriesDetailScreen(title: 'Stage 1 · Left', values: [100, 200, 300]),
    ));
    expect(painter, findsOneWidget);
    final context = tester.element(painter);
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
