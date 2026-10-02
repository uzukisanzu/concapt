import 'package:concapt/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark schemes are the fixed designed palette', () {
    final light = buildTheme(Brightness.light).colorScheme;
    final dark = buildTheme(Brightness.dark).colorScheme;
    expect(light.brightness, Brightness.light);
    expect(light.primary, const Color(0xFFE60012));
    expect(light.surface, const Color(0xFFFFFFFF));
    expect(light.onSurface, const Color(0xFF111111));
    expect(dark.brightness, Brightness.dark);
    expect(
      dark.primary,
      isNot(ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark).primary),
    );
    expect(dark.primary, isNot(light.primary));
  });

  test('the light scheme is fixed, with no Dynamic Color', () {
    final light = buildTheme(Brightness.light).colorScheme;
    expect(light, buildTheme(Brightness.light).colorScheme);
    expect(light.surfaceContainerHighest, const Color(0xFFF2F2F2));
    expect(light.outlineVariant, const Color(0xFFE0E0E0));
    expect(light.outline, const Color(0xFFD6D6D6));
    expect(light.onSurfaceVariant, const Color(0xFF6B6B6B));
  });

  test('every text style uses tabular figures', () {
    for (final brightness in Brightness.values) {
      final t = buildTheme(brightness).textTheme;
      final styles = [
        t.displayLarge, t.displayMedium, t.displaySmall,
        t.headlineLarge, t.headlineMedium, t.headlineSmall,
        t.titleLarge, t.titleMedium, t.titleSmall,
        t.bodyLarge, t.bodyMedium, t.bodySmall,
        t.labelLarge, t.labelMedium, t.labelSmall,
      ];
      for (final style in styles) {
        expect(style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    }
  });

  test('bold styles use the bundled Roboto at w700', () {
    final t = buildTheme(Brightness.light).textTheme;
    final weighted = [t.displayLarge, t.headlineSmall, t.titleLarge, t.titleSmall, bold(t.labelLarge)];
    for (final style in weighted) {
      expect(style!.fontWeight, FontWeight.w700);
      expect(style.fontFamily, 'Roboto');
    }
  });
}
