import 'package:flutter/material.dart';

import '../core/histogram.dart';
import '../core/stats.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'histogram_chart.dart';
import 'stats_card.dart';
import 'theme.dart';

/// One member's score distribution within a session: the histogram, then
/// the seven stats as a ruled table with the mean set large.
class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({super.key, required this.title, required this.values});

  final String title;
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final summary = summarize(values);
    final rows = summaryRows(l, summary);
    final rule = BorderSide(color: scheme.outlineVariant);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: HistogramChart(
              histogram: buildHistogram(values),
              mean: summary.mean,
              median: summary.median,
            ),
          ),
          for (var r = 0; r < rows.length; r++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: rule, bottom: r == rows.length - 1 ? rule : BorderSide.none),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: r == meanRow ? 6 : 4),
                child: Row(
                  children: [
                    Text(
                      rows[r].$1,
                      style: r == meanRow
                          ? bold(text.labelLarge)
                          : text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Text(
                      formatInt(rows[r].$2),
                      style: r == meanRow ? text.titleLarge : text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
