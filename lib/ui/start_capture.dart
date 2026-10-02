import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:screen_capture/screen_capture.dart';

import '../capture/capture_target.dart';
import '../l10n/app_localizations.dart';
import '../overlay/overlay_sizes.dart';
import 'dialogs.dart';

/// Notifications → overlay permission → capture consent → bubble bound to [sessionId].
Future<bool> startCapture(BuildContext context, int sessionId) async {
  final l = AppLocalizations.of(context);
  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

  // Capture works without it, but toasts stay silent.
  await ScreenCapture.requestNotifications();

  if (!await FlutterOverlayWindow.isPermissionGranted()) {
    if (!context.mounted) return false;
    final go = await confirm(
      context,
      title: l.allowBubbleTitle,
      message: l.allowBubbleMessage,
      action: l.openSettings,
    );
    if (!go) return false;
    await FlutterOverlayWindow.requestPermission();
    if (!await FlutterOverlayWindow.isPermissionGranted()) return false;
  }

  if (!context.mounted) return false;
  final ok = await confirm(
    context,
    title: l.shareScreenTitle,
    message: l.shareScreenMessage,
    action: l.continueAction,
  );
  if (!ok) return false;

  if (!await ScreenCapture.requestConsent()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.captureDeclined)));
    }
    return false;
  }

  try {
    await CaptureTarget.write(sessionId);
    if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
    final bubble = OverlaySizes.showUnits(OverlaySizes.bubbleDp, devicePixelRatio);
    await FlutterOverlayWindow.showOverlay(
      width: bubble,
      height: bubble,
      enableDrag: true,
      alignment: OverlayAlignment.centerRight,
      overlayTitle: l.appTitle,
      overlayContent: l.overlayNotification,
    );

    // The cached overlay engine returns to the bubble and re-reads the target.
    await waitForOverlay();
    await FlutterOverlayWindow.shareData('reset');
  } catch (_) {
    // Without a bubble the projection has no use.
    await ScreenCapture.stop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bubbleFailed)));
    }
    return false;
  }

  // Step aside so the game can be opened straight away.
  await ScreenCapture.moveToBack();
  return true;
}

/// showOverlay returns once the overlay service is asked to start, before
/// it registers the window channel the overlay engine calls on reset.
/// The service reports active only after that channel exists.
Future<bool> waitForOverlay({
  Future<bool> Function() isActive = FlutterOverlayWindow.isActive,
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await isActive()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}

/// Closes the bubble before the projection, so the overlay stays quiet
/// about a stop the user asked for.
Future<void> stopCapture() async {
  if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
  await ScreenCapture.stop();
}

/// The session the bubble saves into, or null while capture is off.
Future<int?> capturingSessionId() async =>
    await ScreenCapture.isRunning() && await FlutterOverlayWindow.isActive()
    ? await CaptureTarget.read()
    : null;

Future<bool> isCapturingInto(int sessionId) async => await capturingSessionId() == sessionId;
