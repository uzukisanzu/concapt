/// Thrown when the screen projection has ended.
class CaptureStoppedException implements Exception {
  const CaptureStoppedException();
}

/// Captures the screen to an image file and returns its path.
abstract interface class CaptureSource {
  Future<String> capture();
}
