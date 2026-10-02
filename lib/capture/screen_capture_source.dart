import 'package:flutter/services.dart';
import 'package:screen_capture/screen_capture.dart';

import 'capture_source.dart';

class ScreenCaptureSource implements CaptureSource {
  @override
  Future<String> capture() async {
    try {
      return await ScreenCapture.capture();
    } on PlatformException catch (e) {
      if (e.code == 'not_running') throw const CaptureStoppedException();
      rethrow;
    }
  }
}
