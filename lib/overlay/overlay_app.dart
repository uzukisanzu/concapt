import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:screen_capture/screen_capture.dart';

import '../capture/capture_controller.dart';
import '../capture/capture_target.dart';
import '../capture/mlkit_text_reader.dart';
import '../capture/screen_capture_source.dart';
import '../core/models.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import '../ui/run_form.dart';
import '../ui/theme.dart';
import 'outcome_messages.dart';
import 'overlay_sizes.dart';

class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OverlayHome(),
    );
  }
}

enum _Mode { starting, bubble, hidden, busy, panel }

class OverlayHome extends StatefulWidget {
  const OverlayHome({super.key});

  @override
  State<OverlayHome> createState() => _OverlayHomeState();
}

class _OverlayHomeState extends State<OverlayHome> {
  _Mode _mode = _Mode.starting;
  CaptureController? _controller;
  AppDatabase? _db;
  MlKitTextReader? _reader;
  RunDraft? _draft;
  CaptureController? _draftController;
  StreamSubscription<String>? _stopped;
  StreamSubscription<dynamic>? _messages;

  // Starts run one at a time, so a reset cannot overlap the first start.
  Future<void> _starting = Future.value();

  // Bumped by every restart. Work begun under an older value is stale.
  int _generation = 0;

  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    _stopped = ScreenCapture.events.listen((event) {
      if (event == 'stopped') _close();
    });
    // The cached engine outlives closeOverlay, so the main app sends
    // 'reset' on every show.
    _messages = FlutterOverlayWindow.overlayListener.listen((message) {
      if (message == 'reset') _restart();
    });
    // Localizations are readable once the first frame is built. The engine
    // also boots at app launch with no window, so start only when shown.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await FlutterOverlayWindow.isActive()) _restart();
    });
  }

  void _restart() {
    _generation++;
    _starting = _starting.then((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    final generation = _generation;
    try {
      await _teardown();
      await _resetWindow();
      if (!mounted) return;
      setState(() {
        _draft = null;
        _draftController = null;
        _mode = _Mode.starting;
      });
      final l = AppLocalizations.of(context);
      final sessionId = await CaptureTarget.read();
      if (sessionId == null) {
        await ScreenCapture.toast(l.noSessionSelected);
        await FlutterOverlayWindow.closeOverlay();
        return;
      }
      final db = AppDatabase.open();
      final reader = MlKitTextReader();
      _db = db;
      _reader = reader;
      _controller = CaptureController(
        source: ScreenCaptureSource(),
        reader: reader,
        repository: Repository(db),
        sessionId: sessionId,
        hideBubble: () async {
          if (generation == _generation) await _hideBubble();
        },
        showBubble: () async {
          if (generation == _generation) await _showBusy();
        },
      );
      if (mounted) setState(() => _mode = _Mode.bubble);
    } catch (_) {
      // A failed start must not block later resets. Without a working
      // bubble, closing is the only sane state.
      // closeOverlay never completes once the service is gone.
      try {
        await _teardown();
        if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
    }
  }

  Future<void> _teardown() async {
    // Let an in-flight capture finish before its database closes.
    await _inFlight?.timeout(const Duration(seconds: 12), onTimeout: () {});
    final reader = _reader;
    final db = _db;
    _controller = null;
    _reader = null;
    _db = null;
    await reader?.close();
    await db?.close();
  }

  /// Returns the window to the bubble's size and flags.
  Future<void> _resetWindow() async {
    final bubble = OverlaySizes.resizeUnits(OverlaySizes.bubbleDp);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(bubble, bubble, true);
  }

  Future<void> _close() async {
    await _resetWindow();
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  void dispose() {
    _stopped?.cancel();
    _messages?.cancel();
    _teardown();
    super.dispose();
  }

  /// Clears the bubble from the screen before the frame is taken.
  Future<void> _hideBubble() async {
    setState(() => _mode = _Mode.hidden);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _showBusy() async {
    if (mounted) setState(() => _mode = _Mode.busy);
  }

  Future<void> _onTap() async {
    final controller = _controller;
    if (controller == null) return;
    final l = AppLocalizations.of(context);
    final generation = _generation;
    final run = controller.trigger();
    _inFlight = run.then<void>((_) {}, onError: (_) {});
    CaptureOutcome? outcome;
    try {
      outcome = await run;
    } catch (_) {
      outcome = const CaptureReadFailed();
    }
    if (outcome == null || !mounted || generation != _generation) return;
    switch (outcome) {
      case CaptureNeedsReview(:final draft):
        await _openPanel(draft, controller);
      case CaptureStopped():
        await ScreenCapture.toast(outcomeMessage(l, outcome));
        await _close();
      default:
        setState(() => _mode = _Mode.bubble);
        await ScreenCapture.toast(outcomeMessage(l, outcome));
    }
  }

  Future<void> _openPanel(RunDraft draft, CaptureController controller) async {
    await FlutterOverlayWindow.resizeOverlay(
      OverlaySizes.resizeUnits(OverlaySizes.panelWidthDp),
      OverlaySizes.resizeUnits(OverlaySizes.panelHeightDp),
      true,
    );
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _draftController = controller;
      _mode = _Mode.panel;
    });
  }

  Future<void> _closePanel() async {
    await _resetWindow();
    if (!mounted) return;
    setState(() {
      _draft = null;
      _draftController = null;
      _mode = _Mode.bubble;
    });
  }

  Future<void> _save(RunScores scores) async {
    final l = AppLocalizations.of(context);
    final generation = _generation;
    final seq = await _draftController!.saveReviewed(scores);
    await ScreenCapture.toast(l.runSaved(seq));
    if (generation == _generation) await _closePanel();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: switch (_mode) {
        _Mode.starting || _Mode.hidden => const SizedBox.shrink(),
        _Mode.bubble => _Bubble(onTap: _onTap),
        _Mode.busy => const _Bubble(busy: true),
        _Mode.panel => Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: scheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: RunForm(initial: _draft!, onSave: _save, onCancel: _closePanel),
          ),
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({this.onTap, this.busy = false});

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
              )
            : Icon(Icons.camera_alt, color: scheme.onPrimary),
      ),
    );
  }
}
