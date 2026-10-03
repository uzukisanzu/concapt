import 'package:flutter/services.dart';

/// A top-level window that can be captured.
class WindowInfo {
  const WindowInfo({
    required this.handle,
    required this.title,
    required this.process,
    required this.minimized,
  });

  factory WindowInfo.fromMap(Map<Object?, Object?> map) => WindowInfo(
    handle: map['handle']! as int,
    title: map['title']! as String,
    process: map['process']! as String,
    minimized: map['minimized']! as bool,
  );

  final int handle;
  final String title;

  /// Executable file name, like `scrcpy.exe`. Empty when Windows won't say.
  final String process;
  final bool minimized;
}

/// Windows APIs for concapt: window capture, a global hotkey, OCR, and the
/// runner window's taskbar flash and z-order.
abstract final class WindowCapture {
  static const _methods = MethodChannel('concapt/window_capture');
  static const _hotkey = EventChannel('concapt/window_capture/hotkey');

  /// Visible titled top-level windows, concapt's own excluded.
  static Future<List<WindowInfo>> listWindows() async => [
    for (final map
        in await _methods.invokeListMethod<Map<Object?, Object?>>('listWindows') ?? const [])
      WindowInfo.fromMap(map),
  ];

  /// Saves one frame of [handle]'s client area as a PNG at [path]. Throws
  /// [PlatformException] with code `closed` or `minimized` when the window
  /// can't be captured.
  static Future<void> captureWindow(int handle, String path) =>
      _methods.invokeMethod<void>('captureWindow', {'handle': handle, 'path': path});

  /// OCR words with boxes in image pixels, as maps of `text`, `l`, `t`, `r`, `b`.
  /// With [blueOnly], reads a copy keyed to blue text and enlarged to the
  /// engine's size limit, which finds the bonus pills the plain read misses.
  /// Throws [PlatformException] with code `no_language` when no OCR language is usable.
  static Future<List<Map<Object?, Object?>>> recognize(
    String path, {
    bool blueOnly = false,
  }) async =>
      await _methods.invokeListMethod<Map<Object?, Object?>>('recognize', {
        'path': path,
        'blueOnly': blueOnly,
      }) ??
      const [];

  /// Whether English or another Latin-script OCR language is installed.
  static Future<bool> ocrAvailable() async =>
      await _methods.invokeMethod<bool>('ocrAvailable') ?? false;

  /// Binds [virtualKey] with Win32 `MOD_*` [modifiers] system-wide, replacing
  /// any earlier binding. False when another app holds the combination.
  static Future<bool> registerHotkey(int virtualKey, int modifiers) async =>
      await _methods.invokeMethod<bool>('registerHotkey', {
        'key': virtualKey,
        'modifiers': modifiers,
      }) ??
      false;

  static Future<void> unregisterHotkey() => _methods.invokeMethod<void>('unregisterHotkey');

  /// One event per hotkey press.
  static Stream<void> get hotkeyPresses => _hotkey.receiveBroadcastStream().map((_) {});

  /// Flashes concapt's taskbar button until concapt comes to the front.
  static Future<void> flashWindow() => _methods.invokeMethod<void>('flashWindow');

  static Future<void> setAlwaysOnTop(bool onTop) =>
      _methods.invokeMethod<void>('setAlwaysOnTop', {'onTop': onTop});
}
