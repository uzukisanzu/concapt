import 'package:concapt/capture/hotkey.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  test('function keys, letters, and digits map to virtual keys', () {
    expect(Hotkey.fromKey(LogicalKeyboardKey.f9)?.virtualKey, 0x78);
    expect(Hotkey.fromKey(LogicalKeyboardKey.f24)?.virtualKey, 0x87);
    expect(Hotkey.fromKey(LogicalKeyboardKey.keyQ)?.virtualKey, 0x51);
    expect(Hotkey.fromKey(LogicalKeyboardKey.digit7)?.virtualKey, 0x37);
  });

  test('other keys cannot be bound', () {
    expect(Hotkey.fromKey(LogicalKeyboardKey.enter), isNull);
    expect(Hotkey.fromKey(LogicalKeyboardKey.controlLeft), isNull);
  });

  test('modifiers set MOD_ bits and lead the label', () {
    final hotkey = Hotkey.fromKey(LogicalKeyboardKey.keyQ, control: true, shift: true)!;
    expect(hotkey.modifiers, 0x2 | 0x4);
    expect(hotkey.label, 'Ctrl+Shift+Q');
    expect(Hotkey.fromKey(LogicalKeyboardKey.f9, alt: true)!.modifiers, 0x1);
  });

  test('side buttons map to XBUTTON virtual keys', () {
    expect(Hotkey.fromMouseButtons(kBackMouseButton), const Hotkey(0x05, 0, 'Mouse 4'));
    expect(Hotkey.fromMouseButtons(kForwardMouseButton), const Hotkey(0x06, 0, 'Mouse 5'));
    expect(Hotkey.fromMouseButtons(kPrimaryMouseButton), isNull);
  });

  test('loads F9 until another key is saved', () async {
    expect(await Hotkey.load(), Hotkey.f9);
    final hotkey = Hotkey.fromKey(LogicalKeyboardKey.f10, alt: true)!;
    await hotkey.save();
    expect(await Hotkey.load(), hotkey);
  });
}
