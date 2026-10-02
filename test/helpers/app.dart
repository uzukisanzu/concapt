import 'package:concapt/l10n/app_localizations.dart';
import 'package:concapt/ui/theme.dart';
import 'package:flutter/material.dart';

/// A MaterialApp with the app's theme and localizations around [home].
Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

AppLocalizations en() => lookupAppLocalizations(const Locale('en'));
