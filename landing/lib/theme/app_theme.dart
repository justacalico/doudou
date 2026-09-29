import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData buildSiteTheme() {
  TextStyle geist(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    double spacing = 0,
    Color color = Tk.ink,
  }) => GoogleFonts.geist(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
  );

  final textTheme = TextTheme(
    displayLarge: geist(
      72,
      weight: FontWeight.w600,
      height: 1.05,
      spacing: -2.2,
    ),
    headlineMedium: geist(
      40,
      weight: FontWeight.w600,
      height: 1.12,
      spacing: -1.1,
    ),
    titleLarge: geist(25, weight: FontWeight.w600, height: 1.2, spacing: -0.5),
    titleMedium: geist(20, weight: FontWeight.w600, height: 1.3, spacing: -0.3),
    bodyLarge: geist(17, height: 1.55, color: Tk.ink2),
    bodyMedium: geist(16, height: 1.6, color: Tk.ink2),
    labelLarge: geist(16, weight: FontWeight.w500, height: 1.3, spacing: -0.1),
    labelSmall: geist(13, weight: FontWeight.w500, height: 1.4, color: Tk.muted),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Tk.paper,
    colorScheme: ColorScheme.light(
      surface: Tk.paper,
      primary: Tk.accent,
      onPrimary: Tk.accentInk,
      onSurface: Tk.ink,
    ),
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    hoverColor: const Color(0x00000000),
    highlightColor: const Color(0x00000000),
  );
}
