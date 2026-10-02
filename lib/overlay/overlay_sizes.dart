/// Overlay window sizes for flutter_overlay_window.
abstract final class OverlaySizes {
  static const bubbleDp = 56.0;
  static const panelWidthDp = 340.0;
  static const panelHeightDp = 560.0;

  /// `showOverlay` takes pixels.
  static int showUnits(double dp, double devicePixelRatio) => (dp * devicePixelRatio).round();

  /// `resizeOverlay` takes dp.
  static int resizeUnits(double dp) => dp.round();
}
