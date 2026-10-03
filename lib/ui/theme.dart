import 'package:flutter/material.dart';

/// Fixed schemes with no Dynamic Color, so pass/fail colors, the edited
/// tag, and histogram markers look the same on every phone.
const _light = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFE60012),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFE5E6),
  onPrimaryContainer: Color(0xFF7A0009),
  secondary: Color(0xFF111111),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFF2F2F2),
  onSecondaryContainer: Color(0xFF111111),
  error: Color(0xFFC4000F),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFDECEC),
  onErrorContainer: Color(0xFF8C000B),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF111111),
  onSurfaceVariant: Color(0xFF6B6B6B),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFAFAFA),
  surfaceContainer: Color(0xFFF7F7F7),
  surfaceContainerHigh: Color(0xFFF5F5F5),
  surfaceContainerHighest: Color(0xFFF2F2F2),
  outline: Color(0xFFD6D6D6),
  outlineVariant: Color(0xFFE0E0E0),
  inverseSurface: Color(0xFF111111),
  onInverseSurface: Color(0xFFFFFFFF),
  inversePrimary: Color(0xFFFF5A5F),
  surfaceTint: Colors.transparent,
);

/// Near-black ground, warm off-white ink, and a red lifted for contrast.
const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFF5A5F),
  onPrimary: Color(0xFF2B0003),
  primaryContainer: Color(0xFF5C0008),
  onPrimaryContainer: Color(0xFFFFDAD9),
  secondary: Color(0xFFEDE8E3),
  onSecondary: Color(0xFF151413),
  secondaryContainer: Color(0xFF2A2826),
  onSecondaryContainer: Color(0xFFEDE8E3),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF4A1210),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF151413),
  onSurface: Color(0xFFEDE8E3),
  onSurfaceVariant: Color(0xFFA39E99),
  surfaceContainerLowest: Color(0xFF0F0E0D),
  surfaceContainerLow: Color(0xFF1A1918),
  surfaceContainer: Color(0xFF1E1D1B),
  surfaceContainerHigh: Color(0xFF232220),
  surfaceContainerHighest: Color(0xFF2A2826),
  outline: Color(0xFF4A4744),
  outlineVariant: Color(0xFF33312F),
  inverseSurface: Color(0xFFEDE8E3),
  onInverseSurface: Color(0xFF151413),
  inversePrimary: Color(0xFFE60012),
  surfaceTint: Colors.transparent,
);

const _tabular = [FontFeature.tabularFigures()];

/// [style] set bold.
TextStyle? bold(TextStyle? style) => style?.copyWith(fontWeight: FontWeight.w700);

/// Bundled Roboto (Regular and Bold) with a Japanese fallback, tight leading,
/// and tabular figures, so score columns line up. Bundling keeps the face
/// fixed on phones whose system font isn't Roboto. Sizes stay on the
/// Material scale.
TextStyle _style(double height, [FontWeight? weight]) => TextStyle(
  fontFamily: 'Roboto',
  fontFamilyFallback: const ['Noto Sans JP'],
  fontFeatures: _tabular,
  fontWeight: weight,
  height: height,
  leadingDistribution: TextLeadingDistribution.even,
);

final _textTheme = TextTheme(
  displayLarge: _style(1.1, FontWeight.w700),
  displayMedium: _style(1.1, FontWeight.w700),
  displaySmall: _style(1.1, FontWeight.w700),
  headlineLarge: _style(1.15, FontWeight.w700),
  headlineMedium: _style(1.15, FontWeight.w700),
  headlineSmall: _style(1.15, FontWeight.w700),
  titleLarge: _style(1.2, FontWeight.w700),
  titleMedium: _style(1.2, FontWeight.w700),
  titleSmall: _style(1.2, FontWeight.w700),
  bodyLarge: _style(1.3),
  bodyMedium: _style(1.3),
  bodySmall: _style(1.3),
  labelLarge: _style(1.2),
  labelMedium: _style(1.2),
  labelSmall: _style(1.2),
);

const _square = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4)));

/// The one theme both engines use, in light and dark.
ThemeData buildTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? _light : _dark;
  final rule = BorderSide(color: scheme.outlineVariant);
  OutlineInputBorder box(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(2)),
    borderSide: BorderSide(color: color, width: width),
  );
  return ThemeData(
    colorScheme: scheme,
    textTheme: _textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: rule),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: Border.fromBorderSide(rule),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: _square,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: _square)),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: _square)),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surface, shape: _square),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: box(scheme.outline),
      enabledBorder: box(scheme.outline),
      disabledBorder: box(scheme.outlineVariant),
      focusedBorder: box(scheme.primary, 2),
      errorBorder: box(scheme.error),
      focusedErrorBorder: box(scheme.error, 2),
    ),
  );
}
