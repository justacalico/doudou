import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'doudou_colors.dart';
import 'doudou_tokens.dart';

class DoudouTheme {
  const DoudouTheme._();

  static ThemeData dark({required Color accent}) {
    final colors = _darkColors(accent: accent);
    return _baseTheme(
      brightness: Brightness.dark,
      colors: colors,
      accent: accent,
    );
  }

  static ThemeData oled({required Color accent}) {
    final colors = _oledColors(accent: accent);
    return _baseTheme(
      brightness: Brightness.dark,
      colors: colors,
      accent: accent,
    );
  }

  static ThemeData light({required Color accent}) {
    final colors = _lightColors(accent: accent);
    return _baseTheme(
      brightness: Brightness.light,
      colors: colors,
      accent: accent,
    );
  }

  static ThemeData _baseTheme({
    required Brightness brightness,
    required DoudouColors colors,
    required Color accent,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accentPrimary,
      onPrimary: colors.onAccent,
      secondary: colors.accentPrimary,
      onSecondary: colors.onAccent,
      error: colors.error,
      onError: Colors.white,
      surface: colors.surfaceBase,
      onSurface: colors.textPrimary,
      outline: colors.borderSubtle,
      surfaceTint: Colors.transparent,
    );

    final baseText = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    final themedBase = GoogleFonts.config.allowRuntimeFetching
        ? GoogleFonts.interTextTheme(baseText)
        : baseText;
    final themedText = themedBase.copyWith(
      displayLarge: DoudouType.display.copyWith(color: colors.textPrimary),
      titleLarge: DoudouType.hero.copyWith(color: colors.textPrimary),
      titleMedium: DoudouType.pageTitle.copyWith(color: colors.textPrimary),
      titleSmall: DoudouType.bodyStrong.copyWith(color: colors.textPrimary),
      bodyLarge: DoudouType.body.copyWith(color: colors.textPrimary),
      bodyMedium: DoudouType.body.copyWith(color: colors.textPrimary),
      bodySmall: DoudouType.meta.copyWith(color: colors.textSecondary),
      labelLarge: DoudouType.controlLabel.copyWith(color: colors.textPrimary),
      labelMedium: DoudouType.navLabel.copyWith(color: colors.textSecondary),
      labelSmall: DoudouType.caption.copyWith(color: colors.textTertiary),
    );

    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.appBackground,
      canvasColor: colors.appBackground,
      cardColor: colors.surfaceBase,
      dividerColor: colors.borderSubtle,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: colors.stateHover,
      textTheme: themedText,
      iconTheme: IconThemeData(color: colors.textSecondary),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceModal,
        shape: const RoundedRectangleBorder(borderRadius: DoudouRadii.r16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceModal,
        modalBackgroundColor: colors.surfaceModal,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        hintStyle: themedText.bodySmall?.copyWith(color: colors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: DoudouRadii.r12,
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DoudouRadii.r12,
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DoudouRadii.r12,
          borderSide: BorderSide(color: colors.accentMuted),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        inactiveTrackColor: colors.borderStrong,
        activeTrackColor: colors.accentPrimary,
        thumbColor: colors.accentPrimary,
        overlayColor: colors.accentMuted,
      ),
      extensions: <ThemeExtension<dynamic>>[
        colors,
      ],
    );
  }

  static DoudouColors _darkColors({required Color accent}) {
    final a = _normalizeAccent(accent);
    return DoudouColors(
      appBackground: const Color(0xFF0A0A0C),
      raisedBackground: const Color(0xFF101014),
      surfaceBase: const Color(0xFF131318),
      surfaceElevated: const Color(0xFF181820),
      surfaceOverlay: const Color(0xCC111117),
      surfaceModal: const Color(0xFF17171F),
      surfaceSelected: const Color(0xFF20202A),
      stateHover: const Color(0x12FFFFFF),
      statePressed: const Color(0x1FFFFFFF),
      borderSubtle: const Color(0x14FFFFFF),
      borderStrong: const Color(0x24FFFFFF),
      textPrimary: const Color(0xFFF4F4F5),
      textSecondary: const Color(0xFFB4B4BE),
      textTertiary: const Color(0xFF7D7D88),
      textDisabled: const Color(0xFF5A5A64),
      accentPrimary: a,
      accentMuted: a.withValues(alpha: 0.45),
      onAccent: const Color(0xFF0B0B0F),
      success: const Color(0xFF4ADE80),
      warning: const Color(0xFFFBBF24),
      error: const Color(0xFFFB7185),
      artworkScrimTop: const Color(0x00000000),
      artworkScrimBottom: const Color(0xD9000000),
      playerBackdropLow: const Color(0xFF0A0A0C),
      playerBackdropHigh: const Color(0xFF14141A),
    );
  }

  static DoudouColors _oledColors({required Color accent}) {
    final a = _normalizeAccent(accent);
    return DoudouColors(
      appBackground: const Color(0xFF000000),
      raisedBackground: const Color(0xFF000000),
      surfaceBase: const Color(0xFF07070A),
      surfaceElevated: const Color(0xFF0C0C10),
      surfaceOverlay: const Color(0xCC000000),
      surfaceModal: const Color(0xFF0A0A0D),
      surfaceSelected: const Color(0xFF111116),
      stateHover: const Color(0x14FFFFFF),
      statePressed: const Color(0x22FFFFFF),
      borderSubtle: const Color(0x14FFFFFF),
      borderStrong: const Color(0x2AFFFFFF),
      textPrimary: const Color(0xFFF4F4F5),
      textSecondary: const Color(0xFFB4B4BE),
      textTertiary: const Color(0xFF7D7D88),
      textDisabled: const Color(0xFF5A5A64),
      accentPrimary: a,
      accentMuted: a.withValues(alpha: 0.45),
      onAccent: const Color(0xFF0B0B0F),
      success: const Color(0xFF4ADE80),
      warning: const Color(0xFFFBBF24),
      error: const Color(0xFFFB7185),
      artworkScrimTop: const Color(0x00000000),
      artworkScrimBottom: const Color(0xE6000000),
      playerBackdropLow: const Color(0xFF000000),
      playerBackdropHigh: const Color(0xFF07070A),
    );
  }

  static DoudouColors _lightColors({required Color accent}) {
    final a = _normalizeAccent(accent);
    return DoudouColors(
      appBackground: const Color(0xFFF7F7FA),
      raisedBackground: const Color(0xFFFFFFFF),
      surfaceBase: const Color(0xFFFFFFFF),
      surfaceElevated: const Color(0xFFF0F0F4),
      surfaceOverlay: const Color(0xE6FFFFFF),
      surfaceModal: const Color(0xFFFFFFFF),
      surfaceSelected: const Color(0xFFEAEAEE),
      stateHover: const Color(0x0A000000),
      statePressed: const Color(0x14000000),
      borderSubtle: const Color(0x14000000),
      borderStrong: const Color(0x24000000),
      textPrimary: const Color(0xFF121217),
      textSecondary: const Color(0xFF3B3B44),
      textTertiary: const Color(0xFF6C6C78),
      textDisabled: const Color(0xFF9A9AA3),
      accentPrimary: a,
      accentMuted: a.withValues(alpha: 0.30),
      onAccent: Colors.white,
      success: const Color(0xFF15803D),
      warning: const Color(0xFFB45309),
      error: const Color(0xFFBE123C),
      artworkScrimTop: const Color(0x00FFFFFF),
      artworkScrimBottom: const Color(0xE6FFFFFF),
      playerBackdropLow: const Color(0xFFFFFFFF),
      playerBackdropHigh: const Color(0xFFF0F0F4),
    );
  }

  static Color _normalizeAccent(Color c) {
    final hsl = HSLColor.fromColor(c);
    final sat = hsl.saturation.clamp(0.45, 0.85);
    final light = hsl.lightness.clamp(0.45, 0.70);
    return hsl.withSaturation(sat).withLightness(light).toColor();
  }
}

