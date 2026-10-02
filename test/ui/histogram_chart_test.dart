import 'package:concapt/core/histogram.dart';
import 'package:concapt/ui/histogram_chart.dart';
import 'package:concapt/ui/series_detail_screen.dart';
import 'package:concapt/ui/theme.dart';
import 'dart:ui' show PictureRecorder;

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

  testWidgets('the chart is labelled for screen readers', (tester) async {
    await tester.pumpWidget(localizedApp(
      Scaffold(body: HistogramChart(histogram: buildHistogram(const [100, 200, 300]))),
    ));
    expect(find.bySemanticsLabel('Histogram of 3 runs'), findsOneWidget);
  });

  group('painter', () {
    HistogramPainter painterFor(Histogram histogram, {double? mean, double scale = 1}) =>
        HistogramPainter(
          histogram: histogram,
          mean: mean,
          median: null,
          barColor: const Color(0xFF000001),
          meanColor: const Color(0xFF000002),
          medianColor: const Color(0xFF000003),
          axisColor: const Color(0xFF000004),
          haloColor: const Color(0xFF000005),
          labelStyle: buildTheme(Brightness.light).textTheme.labelSmall!,
          textScaler: TextScaler.linear(scale),
        );

    void paintOn(HistogramPainter painter, Size size) =>
        painter.paint(Canvas(PictureRecorder()), size);

    test('an empty histogram paints nothing and returns', () {
      paintOn(painterFor(Histogram.empty), const Size(300, 200));
    });

    test('a canvas narrower than a label still paints', () {
      paintOn(painterFor(buildHistogram(const [100000, 250000])), const Size(10, 100));
    });

    test('large text on many bins still paints', () {
      final values = [for (var i = 0; i < 300; i++) 113000 + (i * 7919) % 15000];
      paintOn(painterFor(buildHistogram(values), scale: 3), const Size(200, 150));
    });

    testWidgets('a single-value mean marks the center of its bar', (tester) async {
      const histogram = Histogram(start: 5, step: 1, counts: [3]);
      await tester.pumpWidget(Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: CustomPaint(painter: painterFor(histogram, mean: 5)),
        ),
      ));
      expect(
        tester.renderObject(find.byType(CustomPaint).last),
        paints
          ..line(color: const Color(0xFF000004)) // axis
          ..line(p1: const Offset(150, 0), color: const Color(0xFF000005)) // halo
          ..line(p1: const Offset(150, 0), color: const Color(0xFF000002)), // mean
      );
    });

    test('equal inputs do not repaint', () {
      final values = [100, 200, 300];
      expect(
        painterFor(buildHistogram(values)).shouldRepaint(painterFor(buildHistogram(values))),
        isFalse,
      );
    });
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
