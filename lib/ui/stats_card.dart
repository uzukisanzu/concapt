import 'package:flutter/material.dart';

import '../core/stats.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'module_header.dart';
import 'theme.dart';

/// 0 left, 1 middle, 2 right.
String slotName(AppLocalizations l, int slot) => [l.slotLeft, l.slotMiddle, l.slotRight][slot];

List<(String, num?)> summaryRows(AppLocalizations l, Summary s) => [
      (l.statN, s.n),
      (l.statMean, s.mean),
      (l.statMedian, s.median),
      (l.statMin, s.min),
      (l.statMax, s.max),
      (l.statP25, s.p25),
      (l.statP75, s.p75),
    ];

/// The mean's index in [summaryRows]; tables set that row large.
const meanRow = 1;

/// One stage's statistics as a ruled module: rows are stats, columns are
/// the three slots, and the mean row is set large. Each slot column is one
/// tap target that opens that slot.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.stage,
    required this.summaries,
    required this.onSlotTap,
  });

  final int stage;
  final List<Summary> summaries;
  final ValueChanged<int> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = [for (final s in summaries) summaryRows(l, s)];
    final labels = rows.first.map((r) => r.$1).toList();
    final last = summaries.length - 1;
    final hairline = BorderSide(color: scheme.outlineVariant);
    final rule = BoxDecoration(border: Border(bottom: hairline));

    Widget label(String value, TextStyle? style, double vertical) => Padding(
          padding: EdgeInsets.fromLTRB(12, vertical, 8, vertical),
          child: Text(value, style: style),
        );

    Widget cell(int slot, String value, TextStyle? style, double vertical) => Padding(
          padding: EdgeInsets.fromLTRB(8, vertical, slot == last ? 12 : 8, vertical),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value, style: style, maxLines: 1),
          ),
        );

    final slotStyle = text.labelMedium?.copyWith(color: scheme.onSurfaceVariant);

    // The chart icon says the column opens its histogram.
    Widget header(int slot) => Padding(
          padding: EdgeInsets.fromLTRB(8, 4, slot == last ? 12 : 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.bar_chart, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(slotName(l, slot), style: slotStyle),
            ],
          ),
        );
    final labelStyle = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final meanLabelStyle = bold(text.labelLarge);
    TextStyle? labelStyleOf(int r) => r == meanRow ? meanLabelStyle : labelStyle;
    TextStyle? valueStyle(int r) => r == meanRow ? text.titleLarge : text.bodyMedium;
    double pad(int r) => r == meanRow ? 4 : 2;

    final table = Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: rule,
          children: [
            const SizedBox.shrink(),
            for (var slot = 0; slot <= last; slot++) header(slot),
          ],
        ),
        for (var r = 0; r < labels.length; r++)
          TableRow(
            decoration: r == labels.length - 1 ? null : rule,
            children: [
              label(labels[r], labelStyleOf(r), pad(r)),
              for (var slot = 0; slot <= last; slot++)
                cell(slot, formatInt(rows[slot][r].$2), valueStyle(r), pad(r)),
            ],
          ),
      ],
    );

    // Laid over the table: an invisible copy of the label column sets the
    // offset, then each slot column is one ruled tap target.
    final columns = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicWidth(
          child: Opacity(
            opacity: 0,
            child: Column(
              children: [
                for (var r = 0; r < labels.length; r++) label(labels[r], labelStyleOf(r), pad(r)),
              ],
            ),
          ),
        ),
        for (var slot = 0; slot <= last; slot++)
          Expanded(
            child: Semantics(
              button: true,
              label: l.slotColumnSemantics(
                l.stageLabel(stage + 1),
                slotName(l, slot),
                formatInt(summaries[slot].mean),
                formatInt(summaries[slot].n),
              ),
              onTap: () => onSlotTap(slot),
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: slot == 0 ? BorderSide.none : hairline),
                ),
                child: InkWell(
                  key: Key('slot-$stage-$slot'),
                  onTap: () => onSlotTap(slot),
                ),
              ),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleBand(
          tab: ExcludeSemantics(child: ModuleTab(twoDigits(stage + 1))),
          child: Semantics(
            header: true,
            child: Text(l.stageLabel(stage + 1), style: text.titleSmall),
          ),
        ),
        Stack(
          children: [
            ExcludeSemantics(child: table),
            Positioned.fill(child: columns),
          ],
        ),
      ],
    );
  }
}
