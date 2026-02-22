import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Apple Design Language Theme System
/// Implements iOS/macOS Human Interface Guidelines with:
/// - Glassmorphism effects
/// - SF Pro typography
/// - 8pt grid system
/// - Spring-based animations
/// - Adaptive colors for light/dark mode

class AppleDesignSystem {
  AppleDesignSystem._();

  // ============================================
  // TYPOGRAPHY - SF Pro Scale
  // ============================================

  /// SF Pro Display/Text font family with fallback
  static const String fontFamily = '.SF Pro Display';
  static const List<String> fontFamilyFallback = [
    '.SF Pro Text',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// Type scale following Apple HIG (11px to 34px)
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

  /// Font weights (medium-heavy: 500-600)
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // ============================================
  // SPACING - 8pt Grid System
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
  // CORNER RADIUS - Smooth Continuous Curves
  // ============================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusRound = 100.0;

  // ============================================
  // BLUR & VIBRANCY - System Materials
  // ============================================

  /// Ultra-thin material blur
  static const double blurUltraThin = 10.0;

  /// Thin material blur
  static const double blurThin = 20.0;

  /// Regular material blur
  static const double blurRegular = 30.0;

  /// Thick material blur
  static const double blurThick = 40.0;

  /// Saturation for vibrancy effect
  static const double saturationDefault = 1.8;

  // ============================================
  // ANIMATION CURVES - Spring-based
  // ============================================

  /// Standard spring curve (iOS default)
  static const Curve springCurve = Curves.easeOutCubic;

  /// Interactive spring (for press states)
  static const Curve interactiveCurve = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Snappy spring (for quick animations)
  static const Curve snappyCurve = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Gentle spring (for subtle animations)
  static const Curve gentleCurve = Cubic(0.25, 0.1, 0.25, 1.0);

  // ============================================
  // ANIMATION DURATIONS
  // ============================================

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationMedium = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ============================================
  // INTERACTIVE STATES
  // ============================================

  /// Hover scale transform
  static const double hoverScale = 1.02;

  /// Press scale transform
  static const double pressScale = 0.98;

  /// Press opacity
  static const double pressOpacity = 0.7;

  /// Hover opacity
  static const double hoverOpacity = 0.9;

  // ============================================
  // SHADOWS - Depth System
  // ============================================

  static List<BoxShadow> shadowSmall(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withOpacity(0.08),
      offset: const Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: shadowColor.withOpacity(0.04),
      offset: const Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> shadowMedium(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withOpacity(0.12),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: shadowColor.withOpacity(0.06),
      offset: const Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> shadowLarge(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withOpacity(0.16),
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: shadowColor.withOpacity(0.08),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> shadowXLarge(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withOpacity(0.20),
      offset: const Offset(0, 16),
      blurRadius: 48,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: shadowColor.withOpacity(0.10),
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];
}

// ============================================
// APPLE COLOR SYSTEM
// ============================================

class AppleColors {
  AppleColors._();

  // System Colors - Light Mode
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemIndigo = Color(0xFF5856D6);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemPink = Color(0xFFFF2D55);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemTeal = Color(0xFF5AC8FA);
  static const Color systemYellow = Color(0xFFFFCC00);

  // System Colors - Dark Mode Variants
  static const Color systemBlueDark = Color(0xFF0A84FF);
  static const Color systemGreenDark = Color(0xFF30D158);
  static const Color systemIndigoDark = Color(0xFF5E5CE6);
  static const Color systemOrangeDark = Color(0xFFFF9F0A);
  static const Color systemPinkDark = Color(0xFFFF375F);
  static const Color systemPurpleDark = Color(0xFFBF5AF2);
  static const Color systemRedDark = Color(0xFFFF453A);
  static const Color systemTealDark = Color(0xFF64D2FF);
  static const Color systemYellowDark = Color(0xFFFFD60A);

  // Grayscale - Light Mode
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemGray5 = Color(0xFFE5E5EA);
  static const Color systemGray6 = Color(0xFFF2F2F7);

  // Grayscale - Dark Mode
  static const Color systemGrayDark = Color(0xFF8E8E93);
  static const Color systemGray2Dark = Color(0xFF636366);
  static const Color systemGray3Dark = Color(0xFF48484A);
  static const Color systemGray4Dark = Color(0xFF3A3A3C);
  static const Color systemGray5Dark = Color(0xFF2C2C2E);
  static const Color systemGray6Dark = Color(0xFF1C1C1E);

  // Background Colors - Light Mode
  static const Color backgroundPrimary = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF2F2F7);
  static const Color backgroundTertiary = Color(0xFFFFFFFF);
  static const Color backgroundGrouped = Color(0xFFF2F2F7);
  static const Color backgroundGroupedSecondary = Color(0xFFFFFFFF);

  // Background Colors - Dark Mode (dark gray, not pure black; use OLED for pure black)
  static const Color backgroundPrimaryDark = Color(0xFF1C1C1E);
  static const Color backgroundSecondaryDark = Color(0xFF1C1C1E);
  static const Color backgroundTertiaryDark = Color(0xFF2C2C2E);
  static const Color backgroundGroupedDark = Color(0xFF1C1C1E);
  static const Color backgroundGroupedSecondaryDark = Color(0xFF1C1C1E);

  // Elevated Surface Colors (for Dark Mode cards/modals)
  static const Color elevatedPrimaryDark = Color(0xFF1C1C1E);
  static const Color elevatedSecondaryDark = Color(0xFF2C2C2E);
  static const Color elevatedTertiaryDark = Color(0xFF3A3A3C);

  // Fill Colors - Light Mode
  static const Color fillPrimary = Color(0x33787880);
  static const Color fillSecondary = Color(0x29787880);
  static const Color fillTertiary = Color(0x1F787880);
  static const Color fillQuaternary = Color(0x14787880);

  // Fill Colors - Dark Mode
  static const Color fillPrimaryDark = Color(0x5C787880);
  static const Color fillSecondaryDark = Color(0x52787880);
  static const Color fillTertiaryDark = Color(0x3D787880);
  static const Color fillQuaternaryDark = Color(0x2E787880);

  // Label Colors - Light Mode
  static const Color labelPrimary = Color(0xFF000000);
  static const Color labelSecondary = Color(0x993C3C43);
  static const Color labelTertiary = Color(0x4D3C3C43);
  static const Color labelQuaternary = Color(0x2E3C3C43);

  // Label Colors - Dark Mode
  static const Color labelPrimaryDark = Color(0xFFFFFFFF);
  static const Color labelSecondaryDark = Color(0x99EBEBF5);
  static const Color labelTertiaryDark = Color(0x4DEBEBF5);
  static const Color labelQuaternaryDark = Color(0x29EBEBF5);

  // Separator Colors
  static const Color separator = Color(0x4D3C3C43);
  static const Color separatorOpaque = Color(0xFFC6C6C8);
  static const Color separatorDark = Color(0x99545458);
  static const Color separatorOpaqueDark = Color(0xFF38383A);

  // Glassmorphism Background Colors
  static Color glassLight = const Color(0xFFFFFFFF).withOpacity(0.72);
  static Color glassDark = const Color(0xFF1C1C1E).withOpacity(0.80);
  static Color glassLightThin = const Color(0xFFFFFFFF).withOpacity(0.50);
  static Color glassDarkThin = const Color(0xFF1C1C1E).withOpacity(0.60);
  static Color glassLightUltraThin = const Color(0xFFFFFFFF).withOpacity(0.30);
  static Color glassDarkUltraThin = const Color(0xFF1C1C1E).withOpacity(0.40);

  // Vibrancy Overlays
  static Color vibrancyLight = const Color(0xFFFFFFFF).withOpacity(0.15);
  static Color vibrancyDark = const Color(0xFF000000).withOpacity(0.25);
}

// ============================================
// TEXT STYLES
// ============================================

class AppleTextStyles {
  AppleTextStyles._();

  static const String _fontFamily = AppleDesignSystem.fontFamily;
  static const List<String> _fontFamilyFallback =
      AppleDesignSystem.fontFamilyFallback;

  // Large Title - 34px Bold
  static TextStyle largeTitle({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleLargeTitle,
    fontWeight: AppleDesignSystem.weightBold,
    letterSpacing: 0.41,
    height: 1.2,
    color: color,
  );

  // Title 1 - 28px Bold
  static TextStyle title1({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleTitle1,
    fontWeight: AppleDesignSystem.weightBold,
    letterSpacing: 0.36,
    height: 1.21,
    color: color,
  );

  // Title 2 - 22px Bold
  static TextStyle title2({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleTitle2,
    fontWeight: AppleDesignSystem.weightBold,
    letterSpacing: 0.35,
    height: 1.27,
    color: color,
  );

  // Title 3 - 20px SemiBold
  static TextStyle title3({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleTitle3,
    fontWeight: AppleDesignSystem.weightSemiBold,
    letterSpacing: 0.38,
    height: 1.25,
    color: color,
  );

  // Headline - 17px SemiBold
  static TextStyle headline({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleHeadline,
    fontWeight: AppleDesignSystem.weightSemiBold,
    letterSpacing: -0.41,
    height: 1.29,
    color: color,
  );

  // Body - 17px Regular
  static TextStyle body({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleBody,
    fontWeight: AppleDesignSystem.weightRegular,
    letterSpacing: -0.41,
    height: 1.29,
    color: color,
  );

  // Callout - 16px Regular
  static TextStyle callout({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleCallout,
    fontWeight: AppleDesignSystem.weightRegular,
    letterSpacing: -0.32,
    height: 1.31,
    color: color,
  );

  // Subheadline - 15px Regular
  static TextStyle subheadline({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleSubheadline,
    fontWeight: AppleDesignSystem.weightRegular,
    letterSpacing: -0.24,
    height: 1.33,
    color: color,
  );

  // Footnote - 13px Regular
  static TextStyle footnote({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleFootnote,
    fontWeight: AppleDesignSystem.weightRegular,
    letterSpacing: -0.08,
    height: 1.38,
    color: color,
  );

  // Caption 1 - 12px Regular
  static TextStyle caption1({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleCaption1,
    fontWeight: AppleDesignSystem.weightRegular,
    letterSpacing: 0,
    height: 1.33,
    color: color,
  );

  // Caption 2 - 11px Regular
  static TextStyle caption2({Color? color}) => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: AppleDesignSystem.typeScaleCaption2,
    fontWeight: AppleDesignSystem.weightRegular,
    letterSpacing: 0.07,
    height: 1.18,
    color: color,
  );
}

// ============================================
// THEME DATA BUILDERS
// ============================================

class AppleTheme {
  AppleTheme._();

  /// Creates a Light Theme following Apple HIG
  static ThemeData light({Color? accentColor}) {
    final primaryColor = accentColor ?? AppleColors.systemPurple;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppleDesignSystem.fontFamily,
      fontFamilyFallback: AppleDesignSystem.fontFamilyFallback,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryColor.withOpacity(0.12),
        secondary: AppleColors.systemGray,
        secondaryContainer: AppleColors.systemGray5,
        surface: AppleColors.backgroundPrimary,
        surfaceContainerHighest: AppleColors.backgroundSecondary,
        error: AppleColors.systemRed,
        onPrimary: Colors.white,
        onSecondary: AppleColors.labelPrimary,
        onSurface: AppleColors.labelPrimary,
        onSurfaceVariant: AppleColors.labelSecondary.withOpacity(1),
        outline: AppleColors.separator,
        outlineVariant: AppleColors.separatorOpaque,
        shadow: Colors.black,
        inverseSurface: AppleColors.labelPrimary,
        onInverseSurface: AppleColors.backgroundPrimary,
      ),
      scaffoldBackgroundColor: AppleColors.backgroundPrimary,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
        ),
        color: AppleColors.backgroundTertiary,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppleColors.backgroundPrimary.withOpacity(0.8),
        foregroundColor: AppleColors.labelPrimary,
        titleTextStyle: AppleTextStyles.headline(
          color: AppleColors.labelPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppleColors.backgroundPrimary.withOpacity(0.8),
        indicatorColor: primaryColor.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.all(
          AppleTextStyles.caption2(color: AppleColors.labelSecondary),
        ),
      ),
      iconTheme: const IconThemeData(color: AppleColors.labelPrimary, size: 24),
      textTheme: TextTheme(
        displayLarge: AppleTextStyles.largeTitle(
          color: AppleColors.labelPrimary,
        ),
        displayMedium: AppleTextStyles.title1(color: AppleColors.labelPrimary),
        displaySmall: AppleTextStyles.title2(color: AppleColors.labelPrimary),
        headlineLarge: AppleTextStyles.title1(color: AppleColors.labelPrimary),
        headlineMedium: AppleTextStyles.title2(color: AppleColors.labelPrimary),
        headlineSmall: AppleTextStyles.title3(color: AppleColors.labelPrimary),
        titleLarge: AppleTextStyles.headline(color: AppleColors.labelPrimary),
        titleMedium: AppleTextStyles.callout(color: AppleColors.labelPrimary),
        titleSmall: AppleTextStyles.subheadline(
          color: AppleColors.labelPrimary,
        ),
        bodyLarge: AppleTextStyles.body(color: AppleColors.labelPrimary),
        bodyMedium: AppleTextStyles.callout(color: AppleColors.labelPrimary),
        bodySmall: AppleTextStyles.footnote(color: AppleColors.labelSecondary),
        labelLarge: AppleTextStyles.subheadline(
          color: AppleColors.labelPrimary,
        ),
        labelMedium: AppleTextStyles.footnote(
          color: AppleColors.labelSecondary,
        ),
        labelSmall: AppleTextStyles.caption1(color: AppleColors.labelTertiary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppleColors.separator,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleDesignSystem.spacing16,
          vertical: AppleDesignSystem.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
        ),
        selectedTileColor: primaryColor.withOpacity(0.12),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: AppleColors.systemGray5,
        thumbColor: Colors.white,
        overlayColor: primaryColor.withOpacity(0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return AppleColors.systemGray4;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  /// Pure black for OLED mode.
  static const Color _oledBlack = Color(0xFF000000);

  /// Creates a Dark Theme following Apple HIG. When [oled] is true, all surfaces use pure black (#000000).
  static ThemeData dark({Color? accentColor, bool oled = false}) {
    final primaryColor = accentColor ?? AppleColors.systemPurpleDark;
    final bgPrimary = oled ? _oledBlack : AppleColors.backgroundPrimaryDark;
    final bgSecondary = oled ? _oledBlack : AppleColors.backgroundSecondaryDark;
    final bgTertiary = oled ? _oledBlack : AppleColors.backgroundTertiaryDark;
    final elevated = oled ? _oledBlack : AppleColors.elevatedPrimaryDark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppleDesignSystem.fontFamily,
      fontFamilyFallback: AppleDesignSystem.fontFamilyFallback,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: primaryColor.withOpacity(0.24),
        secondary: AppleColors.systemGrayDark,
        secondaryContainer: AppleColors.systemGray4Dark,
        surface: bgSecondary,
        surfaceContainerHighest: bgTertiary,
        error: AppleColors.systemRedDark,
        onPrimary: Colors.white,
        onSecondary: AppleColors.labelPrimaryDark,
        onSurface: AppleColors.labelPrimaryDark,
        onSurfaceVariant: AppleColors.labelSecondaryDark.withOpacity(1),
        outline: AppleColors.separatorDark,
        outlineVariant: AppleColors.separatorOpaqueDark,
        shadow: Colors.black,
        inverseSurface: AppleColors.labelPrimaryDark,
        onInverseSurface: bgPrimary,
      ),
      scaffoldBackgroundColor: bgPrimary,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
        ),
        color: elevated,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: oled ? _oledBlack : AppleColors.backgroundPrimaryDark.withOpacity(0.8),
        foregroundColor: AppleColors.labelPrimaryDark,
        titleTextStyle: AppleTextStyles.headline(
          color: AppleColors.labelPrimaryDark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: oled ? _oledBlack : AppleColors.backgroundSecondaryDark.withOpacity(0.8),
        indicatorColor: primaryColor.withOpacity(0.24),
        labelTextStyle: WidgetStateProperty.all(
          AppleTextStyles.caption2(color: AppleColors.labelSecondaryDark),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: oled ? _oledBlack : AppleColors.elevatedPrimaryDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: oled ? _oledBlack : AppleColors.elevatedPrimaryDark,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppleDesignSystem.radiusLarge)),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppleColors.labelPrimaryDark,
        size: 24,
      ),
      textTheme: TextTheme(
        displayLarge: AppleTextStyles.largeTitle(
          color: AppleColors.labelPrimaryDark,
        ),
        displayMedium: AppleTextStyles.title1(
          color: AppleColors.labelPrimaryDark,
        ),
        displaySmall: AppleTextStyles.title2(
          color: AppleColors.labelPrimaryDark,
        ),
        headlineLarge: AppleTextStyles.title1(
          color: AppleColors.labelPrimaryDark,
        ),
        headlineMedium: AppleTextStyles.title2(
          color: AppleColors.labelPrimaryDark,
        ),
        headlineSmall: AppleTextStyles.title3(
          color: AppleColors.labelPrimaryDark,
        ),
        titleLarge: AppleTextStyles.headline(
          color: AppleColors.labelPrimaryDark,
        ),
        titleMedium: AppleTextStyles.callout(
          color: AppleColors.labelPrimaryDark,
        ),
        titleSmall: AppleTextStyles.subheadline(
          color: AppleColors.labelPrimaryDark,
        ),
        bodyLarge: AppleTextStyles.body(color: AppleColors.labelPrimaryDark),
        bodyMedium: AppleTextStyles.callout(
          color: AppleColors.labelPrimaryDark,
        ),
        bodySmall: AppleTextStyles.footnote(
          color: AppleColors.labelSecondaryDark,
        ),
        labelLarge: AppleTextStyles.subheadline(
          color: AppleColors.labelPrimaryDark,
        ),
        labelMedium: AppleTextStyles.footnote(
          color: AppleColors.labelSecondaryDark,
        ),
        labelSmall: AppleTextStyles.caption1(
          color: AppleColors.labelTertiaryDark,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppleColors.separatorDark,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleDesignSystem.spacing16,
          vertical: AppleDesignSystem.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
        ),
        selectedTileColor: primaryColor.withOpacity(0.24),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: AppleColors.systemGray4Dark,
        thumbColor: Colors.white,
        overlayColor: primaryColor.withOpacity(0.24),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return AppleColors.systemGray3Dark;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  /// Creates a Cupertino Theme for mobile
  static CupertinoThemeData cupertino({
    Color? accentColor,
    Brightness brightness = Brightness.dark,
  }) {
    final primaryColor =
        accentColor ??
        (brightness == Brightness.dark
            ? AppleColors.systemPurpleDark
            : AppleColors.systemPurple);

    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      primaryContrastingColor: Colors.white,
      barBackgroundColor: brightness == Brightness.dark
          ? AppleColors.backgroundSecondaryDark.withOpacity(0.8)
          : AppleColors.backgroundPrimary.withOpacity(0.8),
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? AppleColors.backgroundPrimaryDark
          : AppleColors.backgroundPrimary,
      textTheme: CupertinoTextThemeData(
        primaryColor: primaryColor,
        textStyle: AppleTextStyles.body(
          color: brightness == Brightness.dark
              ? AppleColors.labelPrimaryDark
              : AppleColors.labelPrimary,
        ),
        navLargeTitleTextStyle: AppleTextStyles.largeTitle(
          color: brightness == Brightness.dark
              ? AppleColors.labelPrimaryDark
              : AppleColors.labelPrimary,
        ),
        navTitleTextStyle: AppleTextStyles.headline(
          color: brightness == Brightness.dark
              ? AppleColors.labelPrimaryDark
              : AppleColors.labelPrimary,
        ),
        tabLabelTextStyle: AppleTextStyles.caption2(
          color: brightness == Brightness.dark
              ? AppleColors.labelSecondaryDark
              : AppleColors.labelSecondary,
        ),
      ),
    );
  }
}

// ============================================
// HELPER EXTENSIONS
// ============================================

extension AppleColorExtension on BuildContext {
  /// Get adaptive colors based on brightness
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get applePrimary =>
      isDarkMode ? AppleColors.systemPurpleDark : AppleColors.systemPurple;
  Color get appleBackground => isDarkMode
      ? AppleColors.backgroundPrimaryDark
      : AppleColors.backgroundPrimary;
  Color get appleSecondaryBackground => isDarkMode
      ? AppleColors.backgroundSecondaryDark
      : AppleColors.backgroundSecondary;
  Color get appleSurface => isDarkMode
      ? AppleColors.elevatedPrimaryDark
      : AppleColors.backgroundTertiary;
  Color get appleLabel =>
      isDarkMode ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary;
  Color get appleSecondaryLabel =>
      isDarkMode ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary;
  Color get appleSeparator =>
      isDarkMode ? AppleColors.separatorDark : AppleColors.separator;
  Color get appleGlass =>
      isDarkMode ? AppleColors.glassDark : AppleColors.glassLight;
  Color get appleGlassThin =>
      isDarkMode ? AppleColors.glassDarkThin : AppleColors.glassLightThin;
}
