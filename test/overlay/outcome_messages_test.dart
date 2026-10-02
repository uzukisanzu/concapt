import 'package:concapt/capture/capture_controller.dart';
import 'package:concapt/l10n/app_localizations.dart';
import 'package:concapt/overlay/outcome_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ja = lookupAppLocalizations(const Locale('ja'));
  const toasts = <CaptureOutcome>[
    CaptureSaved(7),
    CaptureDuplicate(6),
    CaptureNoResult(),
    CaptureIncomplete(),
    CaptureReadFailed(),
    CaptureStopped(),
  ];

  test('English messages match the spec copy', () {
    expect(toasts.map((o) => outcomeMessage(en, o)), [
      'Run 7 saved',
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
