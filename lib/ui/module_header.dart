import 'package:flutter/material.dart';

/// The gray band that opens a ruled module, under a hairline top rule.
class ModuleBand extends StatelessWidget {
  const ModuleBand({super.key, required this.child, this.color});

  final Widget child;

  /// Defaults to the light gray header fill.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: child,
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
