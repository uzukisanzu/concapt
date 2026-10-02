import 'package:flutter/services.dart';

/// Screen capture through a MediaProjection foreground service.
///
/// Capture state lives in the Android process, so every Flutter engine
/// sees the same session.
abstract final class ScreenCapture {
  static const _methods = MethodChannel('concapt/screen_capture');
  static const _events = EventChannel('concapt/screen_capture/events');

  /// Shows Android's capture prompt and starts the service on approval.
  /// Needs the main app's Activity in the foreground. Throws
  /// [PlatformException] with code `consent_pending` while the prompt is up.
  static Future<bool> requestConsent() async =>
      await _methods.invokeMethod<bool>('requestConsent') ?? false;

  /// Asks for notification permission, which Android also requires for toasts
  /// while the app is in the background. True when granted or not needed.
  static Future<bool> requestNotifications() async =>
      await _methods.invokeMethod<bool>('requestNotifications') ?? false;

  static Future<bool> isRunning() async => await _methods.invokeMethod<bool>('isRunning') ?? false;

  /// Writes the newest screen frame to a PNG file and returns its path.
  /// Throws [PlatformException] with code `not_running` when capture stopped.
  static Future<String> capture() async => (await _methods.invokeMethod<String>('capture'))!;

  /// Completes once the projection is released.
  static Future<void> stop() => _methods.invokeMethod<void>('stop');

  /// Sends the app's task to the background, as Home would. No-op without an activity.
  static Future<void> moveToBack() => _methods.invokeMethod<void>('moveToBack');

  static Future<void> toast(String message) =>
      _methods.invokeMethod<void>('toast', {'message': message});

  /// Emits `stopped` when the projection ends for any reason.
  static Stream<String> get events => _events.receiveBroadcastStream().cast<String>();
}
