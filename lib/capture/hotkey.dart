import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The global capture hotkey: a Win32 virtual-key code and `MOD_*` bits.
class Hotkey {
  const Hotkey(this.virtualKey, this.modifiers, this.label);

  factory Hotkey.fromJson(Map<String, dynamic> json) =>
      Hotkey(json['key'] as int, json['modifiers'] as int, json['label'] as String);

  static const f9 = Hotkey(0x78, 0, 'F9');

  static const _alt = 0x1;
  static const _control = 0x2;
  static const _shift = 0x4;
  static const _prefsKey = 'captureHotkey';

  static final _functionKeys = [
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
    LogicalKeyboardKey.f9,
    LogicalKeyboardKey.f10,
    LogicalKeyboardKey.f11,
    LogicalKeyboardKey.f12,
    LogicalKeyboardKey.f13,
    LogicalKeyboardKey.f14,
    LogicalKeyboardKey.f15,
    LogicalKeyboardKey.f16,
    LogicalKeyboardKey.f17,
    LogicalKeyboardKey.f18,
    LogicalKeyboardKey.f19,
    LogicalKeyboardKey.f20,
    LogicalKeyboardKey.f21,
    LogicalKeyboardKey.f22,
    LogicalKeyboardKey.f23,
    LogicalKeyboardKey.f24,
  ];

  final int virtualKey;
  final int modifiers;

  /// As shown to the user, like `Ctrl+Shift+F9`.
  final String label;

  /// [key] with the held modifiers, or null for a key that can't be bound.
  /// F1–F24, letters, and digits can.
  static Hotkey? fromKey(
    LogicalKeyboardKey key, {
    bool control = false,
    bool alt = false,
    bool shift = false,
  }) {
    final virtualKey = _virtualKey(key);
    if (virtualKey == null) return null;
    return Hotkey(
      virtualKey,
      (control ? _control : 0) | (alt ? _alt : 0) | (shift ? _shift : 0),
      [
        if (control) 'Ctrl',
        if (alt) 'Alt',
        if (shift) 'Shift',
        key.keyLabel.toUpperCase(),
      ].join('+'),
    );
  }

  static int? _virtualKey(LogicalKeyboardKey key) {
    final function = _functionKeys.indexOf(key);
    if (function >= 0) return 0x70 + function;
    final id = key.keyId;
    final a = LogicalKeyboardKey.keyA.keyId;
    if (id >= a && id <= LogicalKeyboardKey.keyZ.keyId) return 0x41 + id - a;
    final zero = LogicalKeyboardKey.digit0.keyId;
    if (id >= zero && id <= LogicalKeyboardKey.digit9.keyId) return 0x30 + id - zero;
    return null;
  }

  static Future<Hotkey> load() async {
    final json = await SharedPreferencesAsync().getString(_prefsKey);
    return json == null ? f9 : Hotkey.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> save() => SharedPreferencesAsync().setString(_prefsKey, jsonEncode(toJson()));

  Map<String, Object> toJson() => {'key': virtualKey, 'modifiers': modifiers, 'label': label};

  @override
  bool operator ==(Object other) =>
      other is Hotkey && other.virtualKey == virtualKey && other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(virtualKey, modifiers);
}
