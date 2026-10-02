import 'package:flutter/material.dart';

import 'theme.dart';

/// The gray band that opens a ruled module, under a hairline top rule.
/// The [tab] hangs flush from the rule; [child] sits beside it.
class ModuleBand extends StatelessWidget {
  const ModuleBand({super.key, required this.tab, this.child, this.color});

  final Widget tab;
  final Widget? child;

  /// Defaults to the light gray header fill.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = this.child;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 0, 12, child == null ? 8 : 0),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tab,
          if (child != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child),
            ),
          ],
        ],
      ),
    );
  }
}

/// The small red tab that names a module, such as "01" for stage 1.
class ModuleTab extends StatelessWidget {
  const ModuleTab(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: bold(Theme.of(context).textTheme.labelMedium)?.copyWith(color: scheme.onPrimary),
        ),
      ),
    );
  }
}
