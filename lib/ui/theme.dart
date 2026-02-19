import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark-only theme. Metro + iOS inspired.
/// Background #0D0D0D, surface #1A1A1A. No drop shadows. 12px cards, 999px pills.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF252525);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x66FFFFFF);
  static const Color textMuted = Color(0x33FFFFFF);

  static const double radiusCard = 12.0;
  static const double radiusPill = 999.0;

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  /// Builds dark ThemeData for MaterialApp. Accent from [accentColor].
  static ThemeData dark(Color accentColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: surface,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: textTertiary,
      ),
      textTheme: _textTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      dividerColor: textMuted,
    );
  }

  static TextTheme _textTheme() {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        color: textSecondary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        color: textSecondary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        color: textTertiary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    );
  }
}
