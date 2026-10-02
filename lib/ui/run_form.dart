import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'dialogs.dart';
import 'format.dart';
import 'module_header.dart';
import 'theme.dart';

/// Labels in [StageDraft.fields] order.
List<String> fieldLabels(AppLocalizations l) =>
    [l.slotLeft, l.slotMiddle, l.slotRight, l.fieldBonus, l.fieldTotal];

String stageStatus(AppLocalizations l, StageDraft stage) {
  final scores = stage.toScores();
  if (scores == null) return l.statusMissing;
  if (scores.sumOk) return l.statusAddsUp;
  final diff = scores.sum - scores.total;
  return l.statusOffBy('${diff > 0 ? '+' : '−'}${formatInt(diff.abs())}');
}

/// Fifteen fields (3 stages × left, middle, right, bonus, total) with a live sum check.
class RunForm extends StatefulWidget {
  const RunForm({super.key, required this.initial, required this.onSave, required this.onCancel});

  final RunDraft initial;
  final ValueChanged<RunScores> onSave;
  final VoidCallback onCancel;

  @override
  State<RunForm> createState() => _RunFormState();
}

class _RunFormState extends State<RunForm> {
  late final List<List<TextEditingController>> _controllers = [
    for (final stage in widget.initial.stages)
      [
        for (final value in stage.fields)
          TextEditingController(text: value?.toString() ?? '')..addListener(_changed),
      ],
  ];

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final row in _controllers) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  RunDraft get _draft => RunDraft([
        for (final row in _controllers)
          StageDraft.fromFields([
            for (final c in row) int.tryParse(c.text.replaceAll(RegExp(r'[,\s]'), '')),
          ]),
      ]);

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final draft = _draft;
    final scores = draft.toScores();
    if (scores == null) return;
    final invalid = draft.invalidStages;
    if (invalid.isNotEmpty) {
      final names = invalid.map((i) => l.stageLabel(i + 1)).join(l.listSeparator);
      final ok = await confirm(
        context,
        title: l.saveAnywayTitle,
        message: l.saveAnywayMessage(names),
        action: l.saveAnywayAction,
      );
      if (!ok) return;
    }
    widget.onSave(scores);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = _draft;
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < _controllers.length; i++)
                _StageSection(index: i, stage: draft.stages[i], controllers: _controllers[i]),
              const Divider(),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.onCancel, child: Text(l.cancel)),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('save'),
                onPressed: draft.toScores() == null ? null : _save,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One stage as a ruled module: a header band with the red numbered tab
/// and the sum status, then the five score fields.
class _StageSection extends StatelessWidget {
  const _StageSection({required this.index, required this.stage, required this.controllers});

  final int index;
  final StageDraft stage;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = fieldLabels(l);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ok = stage.isValid;

    Widget field(int f) => Expanded(
          child: TextField(
            key: Key('field-$index-$f'),
            controller: controllers[f],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: InputDecoration(labelText: labels[f]),
          ),
        );

    const gap = SizedBox(width: 8);

    return Column(
      key: Key('stage-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleBand(
          color: ok ? null : scheme.errorContainer,
          tab: ExcludeSemantics(child: ModuleTab(twoDigits(index + 1))),
          child: Row(
            children: [
              Semantics(
                header: true,
                child: Text(l.stageLabel(index + 1), style: text.titleSmall),
              ),
              const Spacer(),
              Text(
                stageStatus(l, stage),
                key: Key('status-$index'),
                style: ok
                    ? text.labelLarge?.copyWith(color: scheme.onSurface)
                    : bold(text.labelLarge)?.copyWith(color: scheme.onErrorContainer),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            children: [
              Row(children: [field(0), gap, field(1), gap, field(2)]),
              const SizedBox(height: 12),
              Row(children: [field(3), gap, field(4)]),
            ],
          ),
        ),
      ],
    );
  }
}
