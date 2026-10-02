import 'dart:convert';
import 'dart:io';

import 'package:concapt/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> _messageKeys(String locale) {
  final arb = jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;
  return arb.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  test('Japanese has exactly the English messages', () {
    expect(_messageKeys('ja'), _messageKeys('en'));
  });

  test('both locales load and differ', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ja = lookupAppLocalizations(const Locale('ja'));
    expect(en.runSaved(7), 'Run 7 saved');
    expect(ja.runSaved(7), isNot(en.runSaved(7)));
    expect(en.runCount(1), '1 run');
    expect(en.runCount(3), '3 runs');
  });
}
