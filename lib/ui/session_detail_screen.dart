import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/csv.dart';
import '../core/models.dart';
import '../core/stats.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import 'dialogs.dart';
import 'format.dart';
import 'module_header.dart';
import 'run_editor_screen.dart';
import 'series_detail_screen.dart';
import 'start_capture.dart';
import 'stats_card.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.repository, required this.sessionId});

  final Repository repository;
  final int sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> with WidgetsBindingObserver {
  /// Three stage modules and the runs band.
  static const _headerCount = 4;

  Session? _session;
  List<RunRecord>? _runs;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The overlay engine saves runs while this app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final session = await widget.repository.session(widget.sessionId);
    final runs = await widget.repository.runs(widget.sessionId);
    final capturing = await isCapturingInto(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _session = session;
      _runs = runs;
      _capturing = capturing;
    });
  }

  Future<void> _toggleCapture() async {
    if (_capturing) {
      await stopCapture();
    } else {
      await startCapture(context, widget.sessionId);
    }
    await _reload();
  }

  void _openSeries(int stage, int slot) {
    final l = AppLocalizations.of(context);
    final values = seriesValues(_runs!, stage, slot);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SeriesDetailScreen(
        title: l.seriesTitle(stage + 1, slotName(l, slot)),
        values: values,
      ),
    ));
  }

  Future<void> _edit(RunRecord run) async {
    final l = AppLocalizations.of(context);
    final scores = await Navigator.of(context).push<RunScores>(MaterialPageRoute(
      builder: (_) =>
          RunEditorScreen(title: l.runTitle(run.seq), initial: RunDraft.fromScores(run.scores)),
    ));
    if (scores == null) return;
    await widget.repository.updateRun(run.id, scores);
    await _reload();
  }

  Future<void> _delete(RunRecord run) async {
    final l = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l.deleteRunTitle(run.seq),
      message: l.deleteRunMessage,
      action: l.delete,
    );
    if (!ok) return;
    await widget.repository.deleteRun(run.id);
    await _reload();
  }

  Future<void> _export() async {
    final session = _session!;
    final dir = await getTemporaryDirectory();
    final safeName = session.name.replaceAll(RegExp(r'[^\w\- ]'), '_');
    final file = File('${dir.path}/$safeName.csv');
    await file.writeAsString(buildCsv(_runs!));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: session.name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = _session;
    final runs = _runs;
    if (session == null || runs == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        actions: [
          IconButton(
            tooltip: l.exportCsv,
            icon: const Icon(Icons.share),
            onPressed: runs.isEmpty ? null : _export,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleCapture,
        icon: Icon(_capturing ? Icons.stop : Icons.camera_alt),
        label: Text(_capturing ? l.stopCapturing : l.startCapturing),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _headerCount + (runs.isEmpty ? 1 : runs.length),
        itemBuilder: (context, i) {
          if (i < 3) {
            return StatsCard(
              stage: i,
              summaries: [
                for (var slot = 0; slot < 3; slot++) summarize(seriesValues(runs, i, slot)),
              ],
              onSlotTap: (slot) => _openSeries(i, slot),
            );
          }
          if (i == 3) {
            return ModuleBand(
              tab: Semantics(header: true, child: ModuleTab(l.runsHeading(runs.length))),
            );
          }
          if (runs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              child: Text(
                l.noRunsYet,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          final run = runs[i - _headerCount];
          return _RunRow(
            key: ValueKey('run-${run.id}'),
            run: run,
            onTap: () => _edit(run),
            onLongPress: () => _delete(run),
          );
        },
      ),
    );
  }
}

/// A ruled row: run number, time, and the edited tag on the left; the
/// nine member scores on the right, one line per stage.
class _RunRow extends StatelessWidget {
  const _RunRow({super.key, required this.run, required this.onTap, required this.onLongPress});

  final RunRecord run;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
