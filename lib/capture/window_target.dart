import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_capture/window_capture.dart';

/// The window last chosen for capture. Remembered by process and title,
/// since window handles change between runs.
class RememberedWindow {
  const RememberedWindow(this.process, this.title);

  RememberedWindow.of(WindowInfo window) : this(window.process, window.title);

  static const _prefsKey = 'captureWindow';

  final String process;
  final String title;

  static Future<RememberedWindow?> load() async {
    final json = await SharedPreferencesAsync().getString(_prefsKey);
    if (json == null) return null;
    final map = jsonDecode(json) as Map<String, dynamic>;
    return RememberedWindow(map['process'] as String, map['title'] as String);
  }

  Future<void> save() => SharedPreferencesAsync().setString(
    _prefsKey,
    jsonEncode({'process': process, 'title': title}),
  );

  /// This window among [windows]: same process and title first, then the
  /// process alone when exactly one window has it.
  WindowInfo? findIn(List<WindowInfo> windows) {
    for (final window in windows) {
      if (window.process == process && window.title == title) return window;
    }
    final sameProcess = windows.where((w) => w.process == process).toList();
    return sameProcess.length == 1 ? sameProcess.single : null;
  }
}
