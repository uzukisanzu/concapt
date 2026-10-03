/// Thrown when the screen projection has ended.
class CaptureStoppedException implements Exception {
  const CaptureStoppedException();
}

/// Captures the screen to an image file and returns its path.
abstract interface class CaptureSource {
  Future<String> capture();
}

enum WindowUnavailableReason { closed, minimized }

/// Thrown when the chosen window can't be captured.
class WindowUnavailableException implements Exception {
  const WindowUnavailableException(this.reason);

  final WindowUnavailableReason reason;
}
