import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/histogram.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

/// Gray bars with a red mean line and a dashed ink median line, and a
/// legend that names both values.
class HistogramChart extends StatelessWidget {
  const HistogramChart({super.key, required this.histogram, this.mean, this.median});

  final Histogram histogram;
  final double? mean;
  final double? median;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (histogram.counts.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            l.noRunsYet,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.4,
          child: CustomPaint(
            painter: HistogramPainter(
              histogram: histogram,
              mean: mean,
              median: median,
              barColor: scheme.outline,
              meanColor: scheme.primary,
              medianColor: scheme.onSurface,
              axisColor: scheme.onSurfaceVariant,
              haloColor: scheme.surface,
              labelStyle: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendItem(color: scheme.primary, label: l.legendMean(formatInt(mean))),
            _LegendItem(
              color: scheme.onSurface,
              label: l.legendMedian(formatInt(median)),
              dashed: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final dash = Container(width: dashed ? 5 : 14, height: 2, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed) ...[dash, const SizedBox(width: 4), dash] else dash,
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class HistogramPainter extends CustomPainter {
  HistogramPainter({
    required this.histogram,
    required this.mean,
    required this.median,
    required this.barColor,
    required this.meanColor,
    required this.medianColor,
    required this.axisColor,
    required this.haloColor,
    required this.labelStyle,
    this.textScaler = TextScaler.noScaling,
  });

  final Histogram histogram;
  final double? mean;
  final double? median;
  final Color barColor;
  final Color meanColor;
  final Color medianColor;
  final Color axisColor;

  /// Rings each marker so it stays legible where it crosses a bar.
  final Color haloColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  static const _maxLabels = 5;
  static const _labelGap = 4.0;
  static const _dash = 4.0;
  static const _dashGap = 3.0;

  TextPainter _label(int value) => TextPainter(
        text: TextSpan(text: formatCompact(value), style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final labels = [
      for (var i = 0, every = (histogram.counts.length / (_maxLabels - 1)).ceil();
          i <= histogram.counts.length;
          i += every)
        (histogram.lowerEdge(i), _label(histogram.lowerEdge(i))),
    ];
    final chartHeight = size.height - labels.first.$2.height - _labelGap;
    final lo = histogram.start.toDouble();
    final hi = histogram.end.toDouble();
    double xOf(num value) => (value - lo) / (hi - lo) * size.width;

    final maxCount = histogram.counts.reduce(math.max);
    final bar = Paint()..color = barColor;
    for (var i = 0; i < histogram.counts.length; i++) {
      final height = histogram.counts[i] / maxCount * chartHeight;
      final left = xOf(histogram.lowerEdge(i)) + 1;
      final right = math.max(left, xOf(histogram.lowerEdge(i + 1)) - 1);
      canvas.drawRect(Rect.fromLTRB(left, chartHeight - height, right, chartHeight), bar);
    }

    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );

    for (final (value, label) in labels) {
      final x = (xOf(value) - label.width / 2).clamp(0.0, size.width - label.width);
      label
        ..paint(canvas, Offset(x, chartHeight + _labelGap))
        ..dispose();
    }

    void marker(double? value, Color color, {bool dashed = false}) {
      if (value == null) return;
      final x = xOf(value);
      final halo = Paint()
        ..color = haloColor
        ..strokeWidth = 4;
      final line = Paint()
        ..color = color
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), halo);
      if (!dashed) {
        canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), line);
        return;
      }
      for (var y = 0.0; y < chartHeight; y += _dash + _dashGap) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + _dash, chartHeight)), line);
      }
    }

    marker(median, medianColor, dashed: true);
    marker(mean, meanColor);
  }

  @override
  bool shouldRepaint(HistogramPainter old) =>
      old.histogram != histogram ||
      old.mean != mean ||
      old.median != median ||
      old.barColor != barColor ||
      old.meanColor != meanColor ||
      old.medianColor != medianColor ||
      old.axisColor != axisColor ||
      old.haloColor != haloColor ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
