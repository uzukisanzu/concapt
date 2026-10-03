import 'package:concapt/capture/capture_controller.dart';
import 'package:concapt/core/models.dart';
import 'package:concapt/l10n/app_localizations.dart';
import 'package:concapt/ui/outcome_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ja = lookupAppLocalizations(const Locale('ja'));
  StageScores stage(int total) =>
      StageScores(left: 0, middle: 0, right: 0, bonus: total, total: total);
  final scores = RunScores([stage(312450), stage(298100), stage(1014622)]);
  final toasts = <CaptureOutcome>[
    CaptureSaved(7, scores),
    CaptureDuplicate(6),
    CaptureNoResult(),
    CaptureIncomplete(),
    CaptureReadFailed(),
    CaptureStopped(),
  ];

  test('English messages match the spec copy', () {
    expect(toasts.map((o) => outcomeMessage(en, o)), [
      'Run 7 saved\n312,450 / 298,100 / 1,014,622',
      'Same as run 6, skipped',
      'No result screen detected',
      "Couldn't read all three stages, try again",
      "Couldn't read screen, try again",
      'Capture stopped. Start again from the app.',
    ]);
  });

  test('every toast has a Japanese message', () {
    for (final o in toasts) {
      expect(outcomeMessage(ja, o), isNot(outcomeMessage(en, o)));
    }
  });
}
