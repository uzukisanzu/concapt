import 'package:shared_preferences/shared_preferences.dart';

/// The session the bubble saves into, shared between the two engines.
abstract final class CaptureTarget {
  static const _key = 'captureSessionId';

  static Future<void> write(int sessionId) => SharedPreferencesAsync().setInt(_key, sessionId);

  static Future<int?> read() => SharedPreferencesAsync().getInt(_key);
}
