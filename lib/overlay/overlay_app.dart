import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:screen_capture/screen_capture.dart';

import '../capture/capture_controller.dart';
import '../capture/capture_target.dart';
import '../capture/mlkit_text_reader.dart';
import '../capture/screen_capture_source.dart';
import '../core/models.dart';
import '../core/pixel_rect.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import '../ui/run_form.dart';
import '../ui/theme.dart';
import 'capture_strip.dart';
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

  // The reviewed capture, held while the panel is open.
  ui.Image? _frame;
  List<PixelRect> _stageBounds = const [];

  // Tapping the panel's handle hands the next drag to the plugin, which
  // moves the window by raw screen coordinates; lifting that finger ends it.
  bool _moving = false;
  int? _movePointer;

  // The flag flips first, so a finger that lands before the plugin is
  // ready still ends the move when it lifts.
  Future<void> _setMoving(bool moving) async {
    setState(() => _moving = moving);
    await FlutterOverlayWindow.resizeOverlay(
      OverlaySizes.resizeUnits(OverlaySizes.panelWidthDp),
      OverlaySizes.resizeUnits(OverlaySizes.panelHeightDp),
      moving,
    );
  }

  void _dropFrame() {
    _frame?.dispose();
    _frame = null;
    _stageBounds = const [];
  }
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
    // Stop capturing in the app closes the bubble first, so a stop that
    // finds the bubble showing came from outside (lock, status bar).
    _stopped = ScreenCapture.events.listen((event) async {
      if (event != 'stopped' || !await FlutterOverlayWindow.isActive() || !mounted) return;
      await ScreenCapture.toast(AppLocalizations.of(context).captureStopped);
      await _close();
    });
    // The cached engine outlives closeOverlay, so the main app sends
    // 'reset' on every show.
    _messages = FlutterOverlayWindow.overlayListener.listen((message) {
      if (message == 'reset') _restart();
    });
    // Localizations are readable once the first frame is built. The engine
    // also boots at app launch with no window, so start only when shown,
    // and not again if a reset already started it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await FlutterOverlayWindow.isActive() && _generation == 0) _restart();
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
      _dropFrame();
      final l = AppLocalizations.of(context);
      final sessionId = await CaptureTarget.read();
      if (generation != _generation) return;
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
      // bubble, closing is the only sane state, and the user hears why.
      // closeOverlay never completes once the service is gone.
      try {
        await _teardown();
        if (generation != _generation) return;
        if (await FlutterOverlayWindow.isActive()) {
          if (mounted) await ScreenCapture.toast(AppLocalizations.of(context).bubbleFailed);
          await FlutterOverlayWindow.closeOverlay();
        }
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

  // Clears the panel first; closeOverlay may never complete.
  Future<void> _close() async {
    await _blank();
    if (mounted) {
      setState(() {
        _draft = null;
        _draftController = null;
      });
    }
    _dropFrame();
    await _resetWindow();
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  void dispose() {
    _stopped?.cancel();
    _messages?.cancel();
    unawaited(_teardown());
    _dropFrame();
    super.dispose();
  }

  /// Draws an empty window and waits for that frame, so a following
  /// capture or resize never shows stale content.
  Future<void> _blank() async {
    if (!mounted) return;
    setState(() => _mode = _Mode.hidden);
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Clears the bubble from the screen before the frame is taken.
  Future<void> _hideBubble() async {
    await _blank();
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
    if (outcome == null || !mounted) return;
    if (generation != _generation) {
      // The run is stored even though a restart replaced this bubble.
      if (outcome is CaptureSaved) await ScreenCapture.toast(outcomeMessage(l, outcome));
      return;
    }
    switch (outcome) {
      case CaptureNeedsReview review:
        await _openPanel(review, controller, generation);
      case CaptureStopped():
        await ScreenCapture.toast(outcomeMessage(l, outcome));
        await _close();
      default:
        setState(() => _mode = _Mode.bubble);
        await ScreenCapture.toast(outcomeMessage(l, outcome));
    }
  }

  Future<void> _openPanel(
    CaptureNeedsReview review,
    CaptureController controller,
    int generation,
  ) async {
    // Decoded while the busy bubble still shows; null leaves the panel without strips.
    final frame = await decodeFrame(review.framePath);
    // A restart during the decode has torn down this capture's controller.
    if (!mounted || generation != _generation) {
      frame?.dispose();
      return;
    }
    await _blank();
    await FlutterOverlayWindow.resizeOverlay(
      OverlaySizes.resizeUnits(OverlaySizes.panelWidthDp),
      OverlaySizes.resizeUnits(OverlaySizes.panelHeightDp),
      // The plugin's drag moves the window on any touch, which would stop
      // the panel scrolling; the handle turns it on for one drag instead.
      false,
    );
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    if (!mounted || generation != _generation) {
      frame?.dispose();
      if (mounted) {
        // Undo the blank and resize; a restart still starting sets its own mode.
        await _resetWindow();
        if (mounted && _controller != null) setState(() => _mode = _Mode.bubble);
      }
      return;
    }
    setState(() {
      _draft = review.draft;
      _draftController = controller;
      _frame = frame;
      _stageBounds = review.stageBounds;
      _moving = false;
      _mode = _Mode.panel;
    });
  }

  Future<void> _closePanel() async {
    if (mounted) await _blank();
    await _resetWindow();
    if (!mounted) return;
    setState(() {
      _draft = null;
      _draftController = null;
      _mode = _Mode.bubble;
    });
    _dropFrame();
  }

  void _endMove(int pointer) {
    if (pointer != _movePointer) return;
    _movePointer = null;
    _setMoving(false);
  }

  Future<void> _save(RunScores scores) async {
    final l = AppLocalizations.of(context);
    final generation = _generation;
    final save = _draftController!.saveReviewed(scores);
    _inFlight = save.then<void>((_) {}, onError: (_) {});
    final int seq;
    try {
      seq = await save;
    } catch (_) {
      // The panel stays open so the user can try again.
      await ScreenCapture.toast(l.saveFailed);
      return;
    }
    await ScreenCapture.toast(savedMessage(l, seq, scores));
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
        _Mode.panel => Listener(
            onPointerDown: (e) {
              if (_moving) _movePointer = e.pointer;
            },
            onPointerUp: (e) => _endMove(e.pointer),
            onPointerCancel: (e) => _endMove(e.pointer),
            child: Material(
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: scheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DragHandle(active: _moving, onTap: () => _setMoving(!_moving)),
                  Expanded(
                    // While a move is armed, the drag belongs to the window.
                    child: IgnorePointer(
                      ignoring: _moving,
                      child: RunForm(
                        initial: _draft!,
                        onSave: _save,
                        onCancel: _closePanel,
                        foldPassing: true,
                        stagePreviews: _frame == null
                            ? null
                            : [
                                for (var i = 0; i < _stageBounds.length; i++)
                                  CaptureStrip(
                                    image: _frame!,
                                    rect: _stageBounds[i],
                                    collapsed: _draft!.stages[i].isValid,
                                  ),
                              ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

/// A grip along the panel's top. Tapping it lets the next drag move the
/// panel; it shows in the primary color while that drag is armed.
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).movePanel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 24,
          child: Icon(
            Icons.open_with,
            size: 20,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
