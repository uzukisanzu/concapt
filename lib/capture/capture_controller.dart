import '../core/models.dart';
import '../core/pixel_rect.dart';
import '../core/result_parser.dart';
import '../core/text_piece.dart';
import '../data/repository.dart';
import 'capture_source.dart';
import 'text_reader.dart';

sealed class CaptureOutcome {
  const CaptureOutcome();
}

class CaptureSaved extends CaptureOutcome {
  const CaptureSaved(this.seq, this.scores);

  final int seq;
  final RunScores scores;
}

class CaptureDuplicate extends CaptureOutcome {
  const CaptureDuplicate(this.seq);

  final int seq;
}

class CaptureNoResult extends CaptureOutcome {
  const CaptureNoResult();
}

class CaptureIncomplete extends CaptureOutcome {
  const CaptureIncomplete();
}

class CaptureReadFailed extends CaptureOutcome {
  const CaptureReadFailed();
}

class CaptureStopped extends CaptureOutcome {
  const CaptureStopped();
}

class CaptureNeedsReview extends CaptureOutcome {
  const CaptureNeedsReview(this.draft, {required this.framePath, required this.stageBounds});

  final RunDraft draft;

  /// The captured frame, and where each stage sits in it.
  final String framePath;
  final List<PixelRect> stageBounds;
}

/// Turns one bubble tap into a saved run or a reason it wasn't saved.
class CaptureController {
  CaptureController({
    required this.source,
    required this.reader,
    required this.repository,
    required this.sessionId,
    required this.hideBubble,
    required this.showBubble,
    this.readTimeout = const Duration(seconds: 10),
  });

  final CaptureSource source;
  final TextReader reader;
  final Repository repository;
  final int sessionId;

  /// Completes once the bubble is off screen.
  final Future<void> Function() hideBubble;

  /// Brings the bubble back (in its busy state) after the frame is taken.
  final Future<void> Function() showBubble;
  final Duration readTimeout;

  bool _busy = false;

  /// Returns null when a capture is already in progress.
  Future<CaptureOutcome?> trigger() async {
    if (_busy) return null;
    _busy = true;
    try {
      final String path;
      await hideBubble();
      try {
        path = await source.capture();
      } on CaptureStoppedException {
        return const CaptureStopped();
      } catch (_) {
        return const CaptureReadFailed();
      } finally {
        await showBubble();
      }

      final List<TextPiece> pieces;
      try {
        pieces = await reader.read(path).timeout(readTimeout);
      } catch (_) {
        return const CaptureReadFailed();
      }

      switch (ResultParser.parse(pieces)) {
        case NoResultScreen():
          return const CaptureNoResult();
        case IncompleteScreen():
          return const CaptureIncomplete();
        case ParsedRun(:final draft, :final stageBounds):
          final scores = draft.toScores();
          if (scores == null || !scores.allSumsOk) {
            return CaptureNeedsReview(draft, framePath: path, stageBounds: stageBounds);
          }
          final last = await repository.lastRun(sessionId);
          if (last != null && last.scores == scores) return CaptureDuplicate(last.seq);
          return CaptureSaved(await repository.addRun(sessionId, scores, edited: false), scores);
      }
    } finally {
      _busy = false;
    }
  }

  /// Saves a run the user corrected in the edit panel.
  Future<int> saveReviewed(RunScores scores) => repository.addRun(sessionId, scores, edited: true);
}
