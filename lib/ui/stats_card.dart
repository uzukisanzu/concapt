import 'package:flutter/material.dart';

import '../core/stats.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'module_header.dart';

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

/// One stage's statistics as a ruled module: rows are stats, columns are
/// the three slots, and the mean row is set large. Any cell in a column
/// opens that slot.
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

  static const _meanRow = 1;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = [for (final s in summaries) summaryRows(l, s)];
    final labels = rows.first.map((r) => r.$1).toList();
    final last = summaries.length - 1;
    final rule = BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant)));

    Widget label(String value, TextStyle? style, double vertical) => Padding(
          padding: EdgeInsets.fromLTRB(12, vertical, 8, vertical),
          child: Text(value, style: style),
        );

    Widget cell(int slot, String value, TextStyle? style, double vertical, {Key? key}) => InkWell(
          key: key,
          onTap: () => onSlotTap(slot),
          child: Padding(
            padding: EdgeInsets.fromLTRB(4, vertical, slot == last ? 12 : 0, vertical),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value, style: style, maxLines: 1),
            ),
          ),
        );

    final slotStyle = text.labelMedium?.copyWith(color: scheme.onSurfaceVariant);
    final labelStyle = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final meanLabelStyle = text.labelLarge?.copyWith(fontWeight: FontWeight.w700);
    TextStyle? valueStyle(int r) => r == _meanRow ? text.titleLarge : text.bodyMedium;
    double pad(int r) => r == _meanRow ? 4 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleBand(
          child: Row(
            children: [
              ModuleTab(twoDigits(stage + 1)),
              const SizedBox(width: 8),
              Text(l.stageLabel(stage + 1), style: text.titleSmall),
            ],
          ),
        ),
        Table(
          columnWidths: const {0: IntrinsicColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: rule,
              children: [
                const SizedBox.shrink(),
                for (var slot = 0; slot <= last; slot++)
                  cell(slot, slotName(l, slot), slotStyle, 4, key: Key('slot-$stage-$slot')),
              ],
            ),
            for (var r = 0; r < labels.length; r++)
              TableRow(
                decoration: r == labels.length - 1 ? null : rule,
                children: [
                  label(labels[r], r == _meanRow ? meanLabelStyle : labelStyle, pad(r)),
                  for (var slot = 0; slot <= last; slot++)
                    cell(slot, formatInt(rows[slot][r].$2), valueStyle(r), pad(r)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
