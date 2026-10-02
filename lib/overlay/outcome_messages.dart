import '../capture/capture_controller.dart';
import '../l10n/app_localizations.dart';

String outcomeMessage(AppLocalizations l, CaptureOutcome outcome) => switch (outcome) {
      CaptureSaved(:final seq) => l.runSaved(seq),
      CaptureDuplicate(:final seq) => l.runDuplicate(seq),
      CaptureNoResult() => l.noResultScreen,
      CaptureIncomplete() => l.incompleteScreen,
      CaptureReadFailed() => l.readFailed,
      CaptureStopped() => l.captureStopped,
      CaptureNeedsReview() => l.checkHighlightedStage,
    };
