import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

/// A ruled row: run number, time, and the edited tag on the left; the
/// nine member scores on the right, one line per stage.
class RunRow extends StatelessWidget {
  const RunRow({super.key, required this.run, this.onTap, this.onLongPress});

  final RunRecord run;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.runTitle(run.seq), style: text.titleSmall),
                    Text(
                      formatTime(run.capturedAt),
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (run.edited) ...[
                      const SizedBox(height: 4),
                      DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(color: scheme.primary)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            l.edited,
                            style: text.labelMedium?.copyWith(color: scheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    for (final stage in run.scores.stages)
                      Row(
                        children: [
                          for (final score in stage.members)
                            Expanded(
                              child: Text(
                                formatInt(score),
                                style: text.bodyMedium,
                                textAlign: TextAlign.end,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
