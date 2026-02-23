import 'package:flutter/material.dart';

/// Design tokens for "organic refined" aesthetic.
/// Single source of truth for typography, color, spacing, motion.
/// Used by app theme and desktop theme; no Apple/system naming.
class AppTokens {
  AppTokens._();

  // ============================================
  // TYPOGRAPHY (Google Fonts: display + body)
  // ============================================

  /// Display / headings: rounded, characterful
  static const String fontFamilyDisplay = 'Plus Jakarta Sans';

  /// Body: clean, readable
  static const String fontFamilyBody = 'Nunito';

  static const double typeScaleCaption2 = 11.0;
  static const double typeScaleCaption1 = 12.0;
  static const double typeScaleFootnote = 13.0;
  static const double typeScaleSubheadline = 15.0;
  static const double typeScaleCallout = 16.0;
  static const double typeScaleBody = 17.0;
  static const double typeScaleHeadline = 17.0;
  static const double typeScaleTitle3 = 20.0;
  static const double typeScaleTitle2 = 22.0;
  static const double typeScaleTitle1 = 28.0;
  static const double typeScaleLargeTitle = 34.0;

  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // ============================================
  // SPACING (8pt grid)
  // ============================================

  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  // ============================================
  // RADII (soft, rounded)
  // ============================================

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusRound = 100.0;

  // ============================================
  // MOTION
  // ============================================

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationMedium = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 500);

  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSnappy = Cubic(0.2, 0.0, 0.0, 1.0);

  // ============================================
  // COLORS - Light
  // ============================================

  static const Color backgroundPrimaryLight = Color(0xFFF8F7F4);
  static const Color backgroundSecondaryLight = Color(0xFFF0EFEB);
  static const Color backgroundTertiaryLight = Color(0xFFFFFFFF);
  static const Color backgroundDeepLight = Color(0xFFF5F4F0);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF8F7F4);

  static const Color textPrimaryLight = Color(0xFF1A1A1F);
  static const Color textSecondaryLight = Color(0x990F0F12);
  static const Color textTertiaryLight = Color(0x660F0F12);
  static const Color textMutedLight = Color(0x330F0F12);

  static const Color separatorLight = Color(0x1A000000);
  static const Color separatorOpaqueLight = Color(0xFFE0DFDB);

  // ============================================
  // COLORS - Dark (warm dark gray, organic)
  // ============================================

  static const Color backgroundPrimaryDark = Color(0xFF141418);
  static const Color backgroundSecondaryDark = Color(0xFF141418);
  static const Color backgroundTertiaryDark = Color(0xFF1A1A1F);
  static const Color backgroundDeepDark = Color(0xFF0E0E11);
  static const Color backgroundSidebarDark = Color(0xFF101014);
  static const Color surfaceDark = Color(0xFF1A1A1F);
  static const Color surfaceElevatedDark = Color(0xFF1E1E24);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xB3FFFFFF);
  static const Color textTertiaryDark = Color(0x66FFFFFF);
  static const Color textMutedDark = Color(0x33FFFFFF);

  static const Color separatorDark = Color(0x33FFFFFF);
  static const Color separatorOpaqueDark = Color(0xFF2A2A30);

  static const Color systemGray4 = Color(0xFFE4E4E7);
  static const Color systemGray3Dark = Color(0xFF3F3F46);

  static const Color sidebarActiveDark = Color(0x1AFFFFFF);
  static const Color sidebarHoverDark = Color(0x0DFFFFFF);

  // ============================================
  // COLORS - OLED
  // ============================================

  static const Color oledBlack = Color(0xFF000000);

  // ============================================
  // ACCENT (teal - sharp, not purple)
  // ============================================

  static const Color accentDefaultLight = Color(0xFF0D9488);
  static const Color accentDefaultDark = Color(0xFF2DD4BF);

  // ============================================
  // SEMANTIC
  // ============================================

  static const Color successLight = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF22C55E);
  static const Color errorLight = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFEF4444);
  static const Color playGreenLight = Color(0xFF15803D);
  static const Color playGreenDark = Color(0xFF1DB954);
  static const Color heartRedLight = Color(0xFFE11D48);
  static const Color heartRedDark = Color(0xFFEF4444);

  // ============================================
  // GLASS (for nav/player bars)
  // ============================================

  static const Color glassSurfaceDark = Color(0xFF1A1A1F);
  static const Color glassSurfaceLight = Color(0xFFFFFFFF);
  static const Color glassOverlayDark = Color(0x15FFFFFF);
  static const Color glassOverlayLight = Color(0x15000000);
  static const Color glassBorderDark = Color(0x0DFFFFFF);
  static const Color glassBorderLight = Color(0x1A000000);
  static const Color glassHighlightDark = Color(0x08FFFFFF);
  static const Color glassHighlightLight = Color(0x0D000000);

  // ============================================
  // SHADOWS
  // ============================================

  static List<BoxShadow> shadowSm(Color base) => [
        BoxShadow(
          color: base.withOpacity(0.08),
          offset: const Offset(0, 1),
          blurRadius: 3,
        ),
      ];

  static List<BoxShadow> shadowMd(Color base) => [
        BoxShadow(
          color: base.withOpacity(0.12),
          offset: const Offset(0, 4),
          blurRadius: 12,
        ),
      ];

  static List<BoxShadow> shadowLg(Color base) => [
        BoxShadow(
          color: base.withOpacity(0.16),
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ];

  static List<BoxShadow> shadowGlow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 40,
          offset: const Offset(0, 8),
        ),
      ];
}
