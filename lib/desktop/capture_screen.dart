import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_capture/window_capture.dart';

import '../capture/capture_controller.dart';
import '../capture/capture_source.dart';
import '../capture/hotkey.dart';
import '../capture/window_capture_source.dart';
import '../capture/window_target.dart';
import '../capture/windows_ocr_text_reader.dart';
import '../core/models.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import '../ui/capture_strip.dart';
import '../ui/format.dart';
import '../ui/module_header.dart';
import '../ui/outcome_messages.dart';
import '../ui/run_form.dart';

/// Captures runs into a session from another window, on a global hotkey.
/// The Windows counterpart to the overlay.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.repository,
    required this.sessionId,
    this.cacheDirectory = getApplicationCacheDirectory,
  });

  final Repository repository;
  final int sessionId;
  final Future<Directory> Function() cacheDirectory;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late final _controller = CaptureController(
    source: WindowCaptureSource(() => _window!.handle, directory: widget.cacheDirectory),
    reader: WindowsOcrTextReader(),
    repository: widget.repository,
    sessionId: widget.sessionId,
    // The capture reads the window's own content, so concapt can stay in view.
    hideBubble: () async {},
    showBubble: () async {},
  );

  StreamSubscription<void>? _presses;
  String _sessionName = '';
  int _runCount = 0;
  RunRecord? _lastRun;
  List<WindowInfo> _windows = const [];
  WindowInfo? _window;
  Hotkey _hotkey = Hotkey.f9;
  bool _hotkeyBound = false;

  /// Null until checked.
  bool? _ocrReady;
  bool _onTop = false;
  bool _busy = false;
  String? _message;

  /// The run waiting for review, and its decoded frame for the capture strips.
  CaptureNeedsReview? _review;
  ui.Image? _frame;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _presses?.cancel();
    unawaited(WindowCapture.unregisterHotkey());
    if (_onTop) unawaited(WindowCapture.setAlwaysOnTop(false));
    _frame?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final ocrReady = await WindowCapture.ocrAvailable();
    final hotkey = await Hotkey.load();
    final remembered = await RememberedWindow.load();
    final windows = await WindowCapture.listWindows();
    await _reloadRuns();
    if (!mounted) return;
    setState(() {
      _ocrReady = ocrReady;
      _hotkey = hotkey;
      _windows = windows;
      _window = remembered?.findIn(windows);
    });
    if (!ocrReady) return;
    _presses = WindowCapture.hotkeyPresses.listen((_) => _capture());
    await _bind(hotkey);
  }

  Future<void> _reloadRuns() async {
    final session = await widget.repository.session(widget.sessionId);
    final runs = await widget.repository.runs(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _sessionName = session.name;
      _runCount = runs.length;
      _lastRun = runs.isEmpty ? null : runs.last;
    });
  }

  Future<void> _bind(Hotkey hotkey) async {
    final bound = await WindowCapture.registerHotkey(hotkey.virtualKey, hotkey.modifiers);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _hotkeyBound = bound;
      _message = bound ? null : l.hotkeyTaken(hotkey.label);
    });
  }

  Future<void> _capture() async {
    final l = AppLocalizations.of(context);
    if (_review != null) {
      setState(() => _message = l.finishReviewFirst);
      return;
    }
    if (_window == null) {
      setState(() => _message = l.pickWindowFirst);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);

    CaptureOutcome outcome;
    try {
      // Never null: _busy keeps a second capture from starting.
      outcome = (await _controller.trigger())!;
    } catch (_) {
      outcome = const CaptureReadFailed();
    }
    if (!mounted) return;

    switch (outcome) {
      case CaptureNeedsReview review:
        final frame = await decodeFrame(review.framePath);
        if (!mounted) {
          frame?.dispose();
          return;
        }
        setState(() {
          _busy = false;
          _review = review;
          _frame = frame;
          _message = l.checkHighlightedStage;
        });
        await WindowCapture.flashWindow();
      case CaptureWindowUnavailable(reason: WindowUnavailableReason.closed):
        final windows = await WindowCapture.listWindows();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _windows = windows;
          _window = null;
          _message = outcomeMessage(l, outcome);
        });
      default:
        await _reloadRuns();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _message = outcomeMessage(l, outcome);
        });
    }
  }

  Future<void> _save(RunScores scores) async {
    final l = AppLocalizations.of(context);
    final int seq;
    try {
      seq = await _controller.saveReviewed(scores);
    } catch (_) {
      // The form stays open so the user can try again.
      if (mounted) setState(() => _message = l.saveFailed);
      return;
    }
    await _reloadRuns();
    _closeReview(savedMessage(l, seq, scores));
  }

  void _closeReview(String? message) {
    if (!mounted) return;
    final frame = _frame;
    setState(() {
      _review = null;
      _frame = null;
      _message = message;
    });
    frame?.dispose();
  }

  void _pick(int? handle) {
    final window = _windows.where((w) => w.handle == handle).firstOrNull;
    setState(() => _window = window);
    if (window != null) unawaited(RememberedWindow.of(window).save());
  }

  Future<void> _refreshWindows() async {
    final windows = await WindowCapture.listWindows();
    if (!mounted) return;
    setState(() {
      _windows = windows;
      _window = windows.where((w) => w.handle == _window?.handle).firstOrNull;
    });
  }

  Future<void> _rebind() async {
    // Released while the dialog listens, or pressing the bound key would capture.
    await WindowCapture.unregisterHotkey();
    if (!mounted) return;
    final picked = await showDialog<Hotkey>(
      context: context,
      builder: (_) => const _HotkeyDialog(),
    );
    if (picked != null) {
      await picked.save();
      if (mounted) setState(() => _hotkey = picked);
    }
    if (mounted) await _bind(_hotkey);
  }

  Future<void> _setOnTop(bool onTop) async {
    await WindowCapture.setAlwaysOnTop(onTop);
    if (mounted) setState(() => _onTop = onTop);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final review = _review;
    final frame = _frame;
    return Scaffold(
      appBar: AppBar(title: Text(_sessionName)),
      body: switch (_ocrReady) {
        null => const SizedBox.shrink(),
        false => Padding(padding: const EdgeInsets.all(12), child: Text(l.ocrMissing)),
        true => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: review == null
                  ? _controls(l)
                  : RunForm(
                      initial: review.draft,
                      onSave: _save,
                      onCancel: () => _closeReview(null),
                      foldPassing: true,
                      stagePreviews: frame == null
                          ? null
                          : [
                              for (var i = 0; i < review.stageBounds.length; i++)
                                CaptureStrip(
                                  image: frame,
                                  rect: review.stageBounds[i],
                                  collapsed: review.draft.stages[i].isValid,
                                ),
                            ],
                    ),
            ),
            if (_busy) const LinearProgressIndicator(),
            _OutcomeLine(_message ?? (_hotkeyBound ? l.hotkeyReady(_hotkey.label) : '')),
          ],
        ),
      },
    );
  }

  Widget _controls(AppLocalizations l) {
    final last = _lastRun;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  hint: Text(l.pickWindowFirst),
                  value: _window?.handle,
                  items: [
                    for (final w in _windows)
                      DropdownMenuItem(
                        value: w.handle,
                        child: Text(
                          l.windowEntry(w.title, w.process),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _pick,
                ),
              ),
              IconButton(
                tooltip: l.refreshWindows,
                icon: const Icon(Icons.refresh),
                onPressed: _refreshWindows,
              ),
            ],
          ),
        ),
        ListTile(
          title: Text(l.hotkeyLabel),
          subtitle: Text(_hotkey.label),
          trailing: TextButton(onPressed: _rebind, child: Text(l.changeHotkey)),
        ),
        SwitchListTile(title: Text(l.alwaysOnTop), value: _onTop, onChanged: _setOnTop),
        ModuleBand(tab: ModuleTab(l.runsHeading(_runCount))),
        if (last != null) _LastRun(last.scores),
      ],
    );
  }
}

/// The latest outcome, in place of the overlay's toasts.
class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}

/// The last saved run's member scores, one row per stage.
class _LastRun extends StatelessWidget {
  const _LastRun(this.scores);

  final RunScores scores;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth()},
        children: [
          for (var i = 0; i < scores.stages.length; i++)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 4),
                  child: Text(l.stageLabel(i + 1), style: text.bodySmall),
                ),
                for (final member in scores.stages[i].members)
                  Text(formatInt(member), textAlign: TextAlign.end, style: text.bodyMedium),
              ],
            ),
        ],
      ),
    );
  }
}

/// Waits for the next bindable key press and returns it as a [Hotkey].
class _HotkeyDialog extends StatelessWidget {
  const _HotkeyDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.hotkeyLabel),
      content: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final keyboard = HardwareKeyboard.instance;
          final hotkey = Hotkey.fromKey(
            event.logicalKey,
            control: keyboard.isControlPressed,
            alt: keyboard.isAltPressed,
            shift: keyboard.isShiftPressed,
          );
          if (hotkey == null) return KeyEventResult.ignored;
          Navigator.of(context).pop(hotkey);
          return KeyEventResult.handled;
        },
        child: Text(l.pressHotkey),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel))],
    );
  }
}
