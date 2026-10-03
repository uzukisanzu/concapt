import 'package:concapt/capture/window_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:window_capture/window_capture.dart';

WindowInfo w(int handle, String process, String title) =>
    WindowInfo(handle: handle, title: title, process: process, minimized: false);

void main() {
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  const remembered = RememberedWindow('scrcpy.exe', 'SM-S918B');

  test('matches process and title first', () {
    final windows = [w(1, 'scrcpy.exe', 'Other'), w(2, 'scrcpy.exe', 'SM-S918B')];
    expect(remembered.findIn(windows)?.handle, 2);
  });

  test('falls back to the process when exactly one window has it', () {
    expect(remembered.findIn([w(3, 'scrcpy.exe', 'Pixel 9')])?.handle, 3);
  });

  test('gives up when the process alone is ambiguous', () {
    final windows = [w(1, 'scrcpy.exe', 'A'), w(2, 'scrcpy.exe', 'B')];
    expect(remembered.findIn(windows), isNull);
  });

  test('gives up when the process is gone', () {
    expect(remembered.findIn([w(1, 'gakumas.exe', 'gakumas')]), isNull);
  });

  test('saves and loads', () async {
    expect(await RememberedWindow.load(), isNull);
    await RememberedWindow.of(w(9, 'gakumas.exe', 'gakumas')).save();
    final loaded = (await RememberedWindow.load())!;
    expect([loaded.process, loaded.title], ['gakumas.exe', 'gakumas']);
  });
}
