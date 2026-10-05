import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'dialogs.dart';
import 'format.dart';
import 'module_header.dart';
import 'theme.dart';

/// Labels in [StageDraft.fields] order.
List<String> fieldLabels(AppLocalizations l) => [
  l.slotLeft,
  l.slotMiddle,
  l.slotRight,
  l.fieldTotal,
];

String stageStatus(AppLocalizations l, StageDraft stage) {
  final scores = stage.toScores();
  if (scores == null) return l.statusMissing;
  if (scores.sumOk) return l.statusAddsUp;
  final diff = scores.sum - scores.total;
  return l.statusOffBy('${diff > 0 ? '+' : '−'}${formatInt(diff.abs())}');
}

/// Twelve fields (3 stages × left, middle, right, total) with each stage's
/// bonus and a live sum check.
class RunForm extends StatefulWidget {
  const RunForm({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onCancel,
    this.stagePreviews,
    this.foldPassing = false,
    this.topInset = 12,
    this.saveOnEnter = false,
  });

  final RunDraft initial;
  final ValueChanged<RunScores> onSave;
  final VoidCallback onCancel;

  /// Shown above each stage's fields, such as a crop of the captured frame.
  final List<Widget?>? stagePreviews;

  /// Starts stages that add up folded, and lets every band fold its stage.
  final bool foldPassing;

  /// Ground above the first stage; zero when a rule already sits there.
  final double topInset;

  /// Enter in a field saves, as on a desktop keyboard.
  final bool saveOnEnter;

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

  late final List<List<FocusNode>> _focus = [
    for (final row in _controllers) [for (final _ in row) FocusNode()..addListener(_changed)],
  ];

  late final List<bool> _folded = [
    for (final stage in widget.initial.stages) widget.foldPassing && stage.isValid,
  ];

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final row in [..._controllers, ..._focus]) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _fill(int stage, int field, int value) {
    final text = value.toString();
    _controllers[stage][field].value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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
            padding: EdgeInsets.only(top: widget.topInset),
            children: [
              for (var i = 0; i < _controllers.length; i++) ...[
                _StageSection(
                  index: i,
                  stage: draft.stages[i],
                  controllers: _controllers[i],
                  focusNodes: _focus[i],
                  onFix: (field, value) => _fill(i, field, value),
                  onSubmit: widget.saveOnEnter
                      ? () {
                          if (_draft.toScores() != null) _save();
                        }
                      : null,
                  preview: widget.stagePreviews?.elementAtOrNull(i),
                  folded: _folded[i],
                  onToggleFold: widget.foldPassing
                      ? () => setState(() => _folded[i] = !_folded[i])
                      : null,
                ),
              ],
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
/// and the sum status, then an optional preview, the four score fields, and
/// the bonus the members earn.
/// While a field of a failing stage has focus, the status gives way to a
/// quick fix for it. With [onToggleFold], the band folds the stage.
class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.index,
    required this.stage,
    required this.controllers,
    required this.focusNodes,
    required this.onFix,
    required this.onSubmit,
    required this.preview,
    required this.folded,
    required this.onToggleFold,
  });

  final int index;
  final StageDraft stage;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int field, int value) onFix;
  final VoidCallback? onSubmit;
  final Widget? preview;
  final bool folded;
  final VoidCallback? onToggleFold;

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
        focusNode: focusNodes[f],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.end,
        textInputAction: onSubmit == null ? null : TextInputAction.done,
        onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
        decoration: InputDecoration(
          labelText: labels[f],
          // The one box left to fill in a failing stage.
          enabledBorder: !ok && stage.fields[f] == null
              ? Theme.of(context).inputDecorationTheme.errorBorder
              : null,
        ),
      ),
    );

    // Derived from the members, so shown but never typed.
    final bonus = Expanded(
      child: InputDecorator(
        key: Key('bonus-$index'),
        decoration: InputDecoration(
          labelText: l.fieldBonus,
          enabled: false,
          filled: false,
          labelStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          floatingLabelStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        isEmpty: stage.bonus == null,
        child: Text(
          stage.bonus == null ? '' : formatInt(stage.bonus!),
          textAlign: TextAlign.end,
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );

    const gap = SizedBox(width: 8);

    // A folded stage's fields are gone, even while their focus is still settling.
    final focused = folded ? -1 : focusNodes.indexWhere((n) => n.hasFocus);
    final fix = ok || focused < 0 ? null : stage.fixFor(focused);

    final band = ModuleBand(
      color: ok ? null : scheme.errorContainer,
      tab: ExcludeSemantics(child: ModuleTab(twoDigits(index + 1))),
      child: Row(
        children: [
          // The tab carries the number, so the label is the part that gives way.
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l.stageLabel(index + 1),
                style: text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (fix != null)
            // Inside the fields' tap region, so tapping it keeps their focus.
            TextFieldTapRegion(
              child: OutlinedButton(
                key: Key('fix-$index'),
                onPressed: () => onFix(focused, fix),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                  side: BorderSide(color: scheme.onErrorContainer),
                  textStyle: bold(text.labelLarge),
                  // As short as the status it replaces, so the band keeps its height.
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l.quickFix(labels[focused], formatInt(fix))),
              ),
            )
          else
            Text(
              stageStatus(l, stage),
              key: Key('status-$index'),
              style: ok
                  ? text.labelLarge?.copyWith(color: scheme.onSurface)
                  : bold(text.labelLarge)?.copyWith(color: scheme.onErrorContainer),
            ),
          if (onToggleFold != null) ...[
            const SizedBox(width: 4),
            Icon(
              folded ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: ok ? scheme.onSurfaceVariant : scheme.onErrorContainer,
            ),
          ],
        ],
      ),
    );

    return Column(
      key: Key('stage-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onToggleFold != null)
          InkWell(key: Key('band-$index'), onTap: onToggleFold, child: band)
        else
          band,
        if (!folded) ...[
          if (preview != null)
            Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), child: preview),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                Row(children: [field(0), gap, field(1), gap, field(2)]),
                const SizedBox(height: 12),
                Row(children: [bonus, gap, field(3)]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
