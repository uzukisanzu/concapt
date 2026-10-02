import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'concapt'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @stageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage}'**
  String stageLabel(int stage);

  /// No description provided for @slotLeft.
  ///
  /// In en, this message translates to:
  /// **'#1'**
  String get slotLeft;

  /// No description provided for @slotMiddle.
  ///
  /// In en, this message translates to:
  /// **'#2'**
  String get slotMiddle;

  /// No description provided for @slotRight.
  ///
  /// In en, this message translates to:
  /// **'#3'**
  String get slotRight;

  /// No description provided for @fieldBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get fieldBonus;

  /// No description provided for @fieldTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get fieldTotal;

  /// No description provided for @statusAddsUp.
  ///
  /// In en, this message translates to:
  /// **'Adds up'**
  String get statusAddsUp;

  /// No description provided for @statusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing values'**
  String get statusMissing;

  /// No description provided for @statusOffBy.
  ///
  /// In en, this message translates to:
  /// **'Off by {diff}'**
  String statusOffBy(String diff);

  /// No description provided for @saveAnywayTitle.
  ///
  /// In en, this message translates to:
  /// **'Save anyway?'**
  String get saveAnywayTitle;

  /// No description provided for @saveAnywayMessage.
  ///
  /// In en, this message translates to:
  /// **'{stages} doesn\'t add up.'**
  String saveAnywayMessage(String stages);

  /// No description provided for @quickFix.
  ///
  /// In en, this message translates to:
  /// **'{field} → {value}'**
  String quickFix(String field, String value);

  /// No description provided for @showCapture.
  ///
  /// In en, this message translates to:
  /// **'Show capture'**
  String get showCapture;

  /// No description provided for @hideCapture.
  ///
  /// In en, this message translates to:
  /// **'Hide capture'**
  String get hideCapture;

  /// No description provided for @movePanel.
  ///
  /// In en, this message translates to:
  /// **'Move panel'**
  String get movePanel;

  /// No description provided for @saveAnywayAction.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnywayAction;

  /// No description provided for @runSaved.
  ///
  /// In en, this message translates to:
  /// **'Run {seq} saved\n{totals}'**
  String runSaved(int seq, String totals);

  /// No description provided for @runDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Same as run {seq}, skipped'**
  String runDuplicate(int seq);

  /// No description provided for @noResultScreen.
  ///
  /// In en, this message translates to:
  /// **'No result screen detected'**
  String get noResultScreen;

  /// No description provided for @incompleteScreen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read all three stages, try again'**
  String get incompleteScreen;

  /// No description provided for @readFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read screen, try again'**
  String get readFailed;

  /// No description provided for @bubbleFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the bubble. Start again from the app.'**
  String get bubbleFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the run. Try again.'**
  String get saveFailed;

  /// No description provided for @captureStopped.
  ///
  /// In en, this message translates to:
  /// **'Capture stopped. Start again from the app.'**
  String get captureStopped;

  /// No description provided for @checkHighlightedStage.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted stage'**
  String get checkHighlightedStage;

  /// No description provided for @noSessionSelected.
  ///
  /// In en, this message translates to:
  /// **'No session selected. Start capturing from the app.'**
  String get noSessionSelected;

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet. Make one for each team you rehearse.'**
  String get sessionsEmpty;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @newSessionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Contest week 3 · team A'**
  String get newSessionHint;

  /// No description provided for @renameSession.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get renameSession;

  /// No description provided for @deleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteSessionTitle(String name);

  /// No description provided for @deleteSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes its {count, plural, =1{1 run} other{{count} runs}}.'**
  String deleteSessionMessage(int count);

  /// No description provided for @runCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 run} other{{count} runs}}'**
  String runCount(int count);

  /// No description provided for @sessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{runs} · last {last}'**
  String sessionSubtitle(String runs, String last);

  /// No description provided for @allowBubbleTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow the bubble'**
  String get allowBubbleTitle;

  /// No description provided for @allowBubbleMessage.
  ///
  /// In en, this message translates to:
  /// **'concapt needs \"Display over other apps\" to show its capture bubble over the game.'**
  String get allowBubbleMessage;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @shareScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your screen'**
  String get shareScreenTitle;

  /// No description provided for @shareScreenMessage.
  ///
  /// In en, this message translates to:
  /// **'On the next screen, choose \"Entire screen\", or pick the game if Android asks for a single app.'**
  String get shareScreenMessage;

  /// No description provided for @captureDeclined.
  ///
  /// In en, this message translates to:
  /// **'Screen capture was declined.'**
  String get captureDeclined;

  /// No description provided for @overlayNotification.
  ///
  /// In en, this message translates to:
  /// **'Capture bubble is active'**
  String get overlayNotification;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @capturing.
  ///
  /// In en, this message translates to:
  /// **'Capturing'**
  String get capturing;

  /// No description provided for @startCapturing.
  ///
  /// In en, this message translates to:
  /// **'Start capturing'**
  String get startCapturing;

  /// No description provided for @stopCapturing.
  ///
  /// In en, this message translates to:
  /// **'Stop capturing'**
  String get stopCapturing;

  /// No description provided for @runsHeading.
  ///
  /// In en, this message translates to:
  /// **'Runs ({count})'**
  String runsHeading(int count);

  /// No description provided for @runTitle.
  ///
  /// In en, this message translates to:
  /// **'Run {seq}'**
  String runTitle(int seq);

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @deleteRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete run {seq}?'**
  String deleteRunTitle(int seq);

  /// No description provided for @deleteRunMessage.
  ///
  /// In en, this message translates to:
  /// **'Its scores leave the statistics.'**
  String get deleteRunMessage;

  /// No description provided for @statN.
  ///
  /// In en, this message translates to:
  /// **'n'**
  String get statN;

  /// No description provided for @statMean.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get statMean;

  /// No description provided for @statMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get statMedian;

  /// No description provided for @statMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get statMin;

  /// No description provided for @statMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get statMax;

  /// No description provided for @statP25.
  ///
  /// In en, this message translates to:
  /// **'P25'**
  String get statP25;

  /// No description provided for @statP75.
  ///
  /// In en, this message translates to:
  /// **'P75'**
  String get statP75;

  /// No description provided for @slotColumnSemantics.
  ///
  /// In en, this message translates to:
  /// **'{stage} {slot}, mean {mean}, n {n}'**
  String slotColumnSemantics(String stage, String slot, String mean, String n);

  /// No description provided for @seriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} · {slot}'**
  String seriesTitle(int stage, String slot);

  /// No description provided for @noRunsYet.
  ///
  /// In en, this message translates to:
  /// **'No runs yet'**
  String get noRunsYet;

  /// No description provided for @legendMean.
  ///
  /// In en, this message translates to:
  /// **'Mean {value}'**
  String legendMean(String value);

  /// No description provided for @legendMedian.
  ///
  /// In en, this message translates to:
  /// **'Median {value}'**
  String legendMedian(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
