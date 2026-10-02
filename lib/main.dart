import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/repository.dart';
import 'l10n/app_localizations.dart';
import 'overlay/overlay_app.dart';
import 'ui/sessions_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ConcaptApp(repository: Repository(AppDatabase.open())));
}

/// Entry point for the overlay engine started by flutter_overlay_window.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

class ConcaptApp extends StatelessWidget {
  const ConcaptApp({super.key, required this.repository});

  final Repository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionsScreen(repository: repository),
    );
  }
}
