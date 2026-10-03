import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_capture/window_capture.dart';

import 'capture_source.dart';

/// Captures one window, read from [window] at each capture so the picker
/// can change it.
class WindowCaptureSource implements CaptureSource {
  WindowCaptureSource(this.window, {this.directory = getApplicationCacheDirectory});

  final int Function() window;
  final Future<Directory> Function() directory;

  @override
  Future<String> capture() async {
    final dir = await directory();
    await dir.create(recursive: true);
    final path = '${dir.path}${Platform.pathSeparator}capture.png';
    try {
      await WindowCapture.captureWindow(window(), path);
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'closed' => const WindowUnavailableException(WindowUnavailableReason.closed),
        'minimized' => const WindowUnavailableException(WindowUnavailableReason.minimized),
        _ => e,
      };
    }
    return path;
  }
}
