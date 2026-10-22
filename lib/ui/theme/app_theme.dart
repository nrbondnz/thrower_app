import 'package:flutter/material.dart';

import '../../settings/appearance_store.dart';

/// The app's colours (app-design story, docs/thrower/AppDesign/Colour and
/// Themes.md): charcoal, amber for wood and axes, red for the bull. The
/// light theme's are darkened to read on a light background.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.text,
    required this.mutedText,
  });

  final Color background;

  /// Cards and panels.
  final Color surface;

  /// Amber: the main button, highlights.
  final Color primary;

  /// Text on [primary].
  final Color onPrimary;

  /// Red: the bull, a highlight.
  final Color accent;
  final Color text;

  /// Labels under numbers, captions.
  final Color mutedText;

  static const dark = AppPalette(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    primary: Color(0xFFD97706),
    onPrimary: Color(0xFF121212),
    accent: Color(0xFFDC2626),
    text: Color(0xFFF3F4F6),
    mutedText: Color(0xFF9CA3AF),
  );

  static const light = AppPalette(
    background: Color(0xFFF7F5F2),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFFB45309),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFB91C1C),
    text: Color(0xFF1F2937),
    mutedText: Color(0xFF6B7280),
  );
}

/// The light and dark [ThemeData], from [AppPalette].
abstract final class AppTheme {
  static ThemeData light() => _from(AppPalette.light, Brightness.light);

  static ThemeData dark() => _from(AppPalette.dark, Brightness.dark);

  static ThemeData _from(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: brightness).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      error: p.accent,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.mutedText,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface,
    );
    final base = ThemeData(colorScheme: scheme, brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: p.text, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: brightness == Brightness.dark ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.25),
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium?.copyWith(color: p.text)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    );
  }

  /// The theme the camera screens always use: dark, whatever the setting
  /// (read from the throwing line, often in a dim range).
  static final cameraDark = dark();
}

/// The [ThemeMode] for an [Appearance] setting.
ThemeMode themeModeOf(Appearance appearance) => switch (appearance) {
  Appearance.phone => ThemeMode.system,
  Appearance.light => ThemeMode.light,
  Appearance.dark => ThemeMode.dark,
};

/// Puts a camera screen in [AppTheme.cameraDark] whatever the Appearance
/// setting (docs/thrower/AppDesign/Colour and Themes.md → The Camera
/// Screens Stay Dark).
class CameraTheme extends StatelessWidget {
  const CameraTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(data: AppTheme.cameraDark, child: child);
}
