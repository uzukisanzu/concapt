// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'concapt';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get create => 'Create';

  @override
  String get continueAction => 'Continue';

  @override
  String get listSeparator => ', ';

  @override
  String stageLabel(int stage) {
    return 'Stage $stage';
  }

  @override
  String get slotLeft => '#1';

  @override
  String get slotMiddle => '#2';

  @override
  String get slotRight => '#3';

  @override
  String get fieldBonus => 'Bonus';

  @override
  String get fieldTotal => 'Total';

  @override
  String get statusAddsUp => 'Adds up';

  @override
  String get statusMissing => 'Missing values';

  @override
  String statusOffBy(String diff) {
    return 'Off by $diff';
  }

  @override
  String get saveAnywayTitle => 'Save anyway?';

  @override
  String saveAnywayMessage(String stages) {
    return '$stages doesn\'t add up.';
  }

  @override
  String quickFix(String field, String value) {
    return '$field → $value';
  }

  @override
  String get showCapture => 'Show capture';

  @override
  String get hideCapture => 'Hide capture';

  @override
  String get movePanel => 'Move panel';

  @override
  String get saveAnywayAction => 'Save anyway';

  @override
  String runSaved(int seq, String totals) {
    return 'Run $seq saved\n$totals';
  }

  @override
  String runDuplicate(int seq) {
    return 'Same as run $seq, skipped';
  }

  @override
  String get noResultScreen => 'No result screen detected';

  @override
  String get incompleteScreen => 'Couldn\'t read all three stages, try again';

  @override
  String get readFailed => 'Couldn\'t read screen, try again';

  @override
  String get bubbleFailed =>
      'Couldn\'t start the bubble. Start again from the app.';

  @override
  String get saveFailed => 'Couldn\'t save the run. Try again.';

  @override
  String get exportFailed => 'Couldn\'t export the CSV.';

  @override
  String get loadFailed => 'Couldn\'t load sessions.';

  @override
  String get captureStopped => 'Capture stopped. Start again from the app.';

  @override
  String get checkHighlightedStage => 'Check the highlighted stage';

  @override
  String get noSessionSelected =>
      'No session selected. Start capturing from the app.';

  @override
  String get sessionsEmpty =>
      'No sessions yet. Make one for each team you rehearse.';

  @override
  String get newSession => 'New session';

  @override
  String get newSessionHint => 'e.g. Contest week 3 · team A';

  @override
  String get renameSession => 'Rename session';

  @override
  String deleteSessionTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String deleteSessionMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count runs',
      one: '1 run',
    );
    return 'This deletes its $_temp0.';
  }

  @override
  String runCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count runs',
      one: '1 run',
    );
    return '$_temp0';
  }

  @override
  String sessionSubtitle(String runs, String last) {
    return '$runs · last $last';
  }

  @override
  String histogramLabel(String runs) {
    return 'Histogram of $runs';
  }

  @override
  String get allowBubbleTitle => 'Allow the bubble';

  @override
  String get allowBubbleMessage =>
      'concapt needs \"Display over other apps\" to show its capture bubble over the game.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get shareScreenTitle => 'Share your screen';

  @override
  String get shareScreenMessage =>
      'On the next screen, choose \"Entire screen\", or pick the game if Android asks for a single app.';

  @override
  String get captureDeclined => 'Screen capture was declined.';

  @override
  String get overlayNotification => 'Capture bubble is active';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get capturing => 'Capturing';

  @override
  String get startCapturing => 'Start capturing';

  @override
  String get stopCapturing => 'Stop capturing';

  @override
  String runsHeading(int count) {
    return 'Runs ($count)';
  }

  @override
  String runTitle(int seq) {
    return 'Run $seq';
  }

  @override
  String get edited => 'edited';

  @override
  String deleteRunTitle(int seq) {
    return 'Delete run $seq?';
  }

  @override
  String get deleteRunMessage => 'Its scores leave the statistics.';

  @override
  String get statN => 'n';

  @override
  String get statMean => 'Mean';

  @override
  String get statMedian => 'Median';

  @override
  String get statMin => 'Min';

  @override
  String get statMax => 'Max';

  @override
  String get statP25 => 'P25';

  @override
  String get statP75 => 'P75';

  @override
  String slotColumnSemantics(String stage, String slot, String mean, String n) {
    return '$stage $slot, mean $mean, n $n';
  }

  @override
  String seriesTitle(int stage, String slot) {
    return 'Stage $stage · $slot';
  }

  @override
  String get noRunsYet => 'No runs yet';

  @override
  String legendMean(String value) {
    return 'Mean $value';
  }

  @override
  String legendMedian(String value) {
    return 'Median $value';
  }
}
