import 'package:flutter/services.dart';

/// Windows APIs for concapt: OCR.
abstract final class WindowCapture {
  static const _methods = MethodChannel('concapt/window_capture');

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
}
