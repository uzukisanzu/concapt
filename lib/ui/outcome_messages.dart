import '../capture/capture_controller.dart';
import '../capture/capture_source.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

String outcomeMessage(AppLocalizations l, CaptureOutcome outcome) => switch (outcome) {
  CaptureSaved(:final seq, :final scores) => savedMessage(l, seq, scores),
  CaptureDuplicate(:final seq) => l.runDuplicate(seq),
  CaptureNoResult() => l.noResultScreen,
  CaptureIncomplete() => l.incompleteScreen,
  CaptureReadFailed() => l.readFailed,
  CaptureStopped() => l.captureStopped,
  CaptureWindowUnavailable(reason: WindowUnavailableReason.closed) => l.windowClosed,
  CaptureWindowUnavailable(reason: WindowUnavailableReason.minimized) => l.windowMinimized,
  CaptureNeedsReview() => l.checkHighlightedStage,
};

/// The run number with its three stage totals, to check against the game screen.
String savedMessage(AppLocalizations l, int seq, RunScores scores) =>
    l.runSaved(seq, scores.stages.map((s) => formatInt(s.total)).join(' / '));
