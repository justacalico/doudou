import 'package:flutter/material.dart';

/// Apple Design System Colors
class AppleColors {
  // Light mode colors
  static const Color backgroundPrimary = Color(0xFFF2F2F7);
  static const Color backgroundSecondary = Color(0xFFFFFFFF);
  static const Color backgroundTertiary = Color(0xFFFFFFFF);
  
  // Elevated backgrounds (for cards, dialogs, etc.)
  static const Color elevatedPrimary = Color(0xFFFFFFFF);
  static const Color elevatedSecondary = Color(0xFFF2F2F7);
  static const Color elevatedTertiary = Color(0xFFE5E5EA);
  
  static const Color labelPrimary = Color(0xFF000000);
  static const Color labelSecondary = Color(0xFF3C3C43);
  static const Color labelTertiary = Color(0xFF3C3C4399);
  static const Color labelQuaternary = Color(0xFF3C3C432E);
  
  static const Color fillPrimary = Color(0x33787880);
  static const Color fillSecondary = Color(0x29787880);
  static const Color fillTertiary = Color(0x1F787880);
  static const Color fillQuaternary = Color(0x14787880);
  
  static const Color separator = Color(0x4D3C3C43);
  static const Color separatorOpaque = Color(0xFFC6C6C8);
  
  // Dark mode colors
  static const Color backgroundPrimaryDark = Color(0xFF000000);
  static const Color backgroundSecondaryDark = Color(0xFF1C1C1E);
  static const Color backgroundTertiaryDark = Color(0xFF2C2C2E);
  
  // Elevated backgrounds dark (for cards, dialogs, etc.)
  static const Color elevatedPrimaryDark = Color(0xFF1C1C1E);
  static const Color elevatedSecondaryDark = Color(0xFF2C2C2E);
  static const Color elevatedTertiaryDark = Color(0xFF3A3A3C);
  
  static const Color labelPrimaryDark = Color(0xFFFFFFFF);
  static const Color labelSecondaryDark = Color(0xFFEBEBF5);
  static const Color labelTertiaryDark = Color(0xFFEBEBF54D);
  static const Color labelQuaternaryDark = Color(0xFFEBEBF52E);
  
  static const Color fillPrimaryDark = Color(0x5C787880);
  static const Color fillSecondaryDark = Color(0x52787880);
  static const Color fillTertiaryDark = Color(0x3D787880);
  static const Color fillQuaternaryDark = Color(0x2E787880);
  
  static const Color separatorDark = Color(0x5C545458);
  static const Color separatorOpaqueDark = Color(0xFF38383A);
  
  // System colors - Light
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemIndigo = Color(0xFF5856D6);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemPink = Color(0xFFFF2D55);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemTeal = Color(0xFF5AC8FA);
  static const Color systemYellow = Color(0xFFFFCC00);
  
  // System colors - Dark
  static const Color systemBlueDark = Color(0xFF0A84FF);
  static const Color systemGreenDark = Color(0xFF30D158);
  static const Color systemIndigoDark = Color(0xFF5E5CE6);
  static const Color systemOrangeDark = Color(0xFFFF9F0A);
  static const Color systemPinkDark = Color(0xFFFF375F);
  static const Color systemPurpleDark = Color(0xFFBF5AF2);
  static const Color systemRedDark = Color(0xFFFF453A);
  static const Color systemTealDark = Color(0xFF64D2FF);
  static const Color systemYellowDark = Color(0xFFFFD60A);
  
  // Gray colors
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemGray5 = Color(0xFFE5E5EA);
  static const Color systemGray6 = Color(0xFFF2F2F7);
  
  static const Color systemGrayDark = Color(0xFF8E8E93);
  static const Color systemGray2Dark = Color(0xFF636366);
  static const Color systemGray3Dark = Color(0xFF48484A);
  static const Color systemGray4Dark = Color(0xFF3A3A3C);
  static const Color systemGray5Dark = Color(0xFF2C2C2E);
  static const Color systemGray6Dark = Color(0xFF1C1C1E);
}

/// Apple Design System Spacing and Layout
class AppleDesignSystem {
  // Spacing
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing56 = 56.0;
  static const double spacing64 = 64.0;
  
  // Border Radius
  static const double radiusSmall = 6.0;
  static const double radiusMedium = 10.0;
  static const double radiusLarge = 14.0;
  static const double radiusXLarge = 20.0;
  static const double radiusXXLarge = 26.0;
  static const double radiusRound = 9999.0; // For circular shapes
  
  // Blur
  static const double blurThin = 10.0;
  static const double blurRegular = 20.0;
  static const double blurThick = 30.0;
  static const double blurUltraThick = 50.0;
  
  // Animation Durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationVerySlow = Duration(milliseconds: 600);
  
  // Animation Curves
  static const Curve springCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
  
  // Font Family
  static const String fontFamily = '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", "Helvetica", Arial, sans-serif';
  
  // Type Scale (font sizes)
  static const double typeScaleLargeTitle = 34.0;
  static const double typeScaleTitle1 = 28.0;
  static const double typeScaleTitle2 = 22.0;
  static const double typeScaleTitle3 = 20.0;
  static const double typeScaleHeadline = 17.0;
  static const double typeScaleBody = 17.0;
  static const double typeScaleCallout = 16.0;
  static const double typeScaleSubheadline = 15.0;
  static const double typeScaleFootnote = 13.0;
  static const double typeScaleCaption1 = 12.0;
  static const double typeScaleCaption2 = 11.0;
  
  // Font Weights
  static const FontWeight weightUltraLight = FontWeight.w100;
  static const FontWeight weightThin = FontWeight.w200;
  static const FontWeight weightLight = FontWeight.w300;
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightHeavy = FontWeight.w800;
  static const FontWeight weightBlack = FontWeight.w900;
  
  // Shadows
  static List<BoxShadow> shadowSmall(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMedium(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLarge(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.2),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Apple Text Styles
class AppleTextStyles {
  static TextStyle largeTitle({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 34,
      fontWeight: fontWeight ?? FontWeight.bold,
      letterSpacing: 0.37,
      color: color,
    );
  }
  
  static TextStyle title1({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 28,
      fontWeight: fontWeight ?? FontWeight.bold,
      letterSpacing: 0.36,
      color: color,
    );
  }
  
  static TextStyle title2({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 22,
      fontWeight: fontWeight ?? FontWeight.bold,
      letterSpacing: 0.35,
      color: color,
    );
  }
  
  static TextStyle title3({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 20,
      fontWeight: fontWeight ?? FontWeight.w600,
      letterSpacing: 0.38,
      color: color,
    );
  }
  
  static TextStyle headline({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 17,
      fontWeight: fontWeight ?? FontWeight.w600,
      letterSpacing: -0.41,
      color: color,
    );
  }
  
  static TextStyle body({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 17,
      fontWeight: fontWeight ?? FontWeight.normal,
      letterSpacing: -0.41,
      color: color,
    );
  }
  
  static TextStyle callout({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: fontWeight ?? FontWeight.normal,
      letterSpacing: -0.32,
      color: color,
    );
  }
  
  static TextStyle subheadline({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 15,
      fontWeight: fontWeight ?? FontWeight.normal,
      letterSpacing: -0.24,
      color: color,
    );
  }
  
  static TextStyle footnote({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 13,
      fontWeight: fontWeight ?? FontWeight.normal,
      letterSpacing: -0.08,
      color: color,
    );
  }
  
  static TextStyle caption1({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 12,
      fontWeight: fontWeight ?? FontWeight.normal,
      letterSpacing: 0,
      color: color,
    );
  }
  
  static TextStyle caption2({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 11,
      fontWeight: fontWeight ?? FontWeight.normal,
      letterSpacing: 0.07,
      color: color,
    );
  }
}

/// Apple Theme for MaterialApp
class AppleTheme {
  static ThemeData light({Color? accentColor}) {
    final accent = accentColor ?? AppleColors.systemBlue;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: accent,
        surface: AppleColors.backgroundSecondary,
        error: AppleColors.systemRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppleColors.labelPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppleColors.backgroundPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: AppleColors.backgroundSecondary.withOpacity(0.8),
        foregroundColor: AppleColors.labelPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppleTextStyles.headline(color: AppleColors.labelPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppleColors.backgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppleColors.separator,
        thickness: 0.5,
      ),
      textTheme: TextTheme(
        displayLarge: AppleTextStyles.largeTitle(color: AppleColors.labelPrimary),
        displayMedium: AppleTextStyles.title1(color: AppleColors.labelPrimary),
        displaySmall: AppleTextStyles.title2(color: AppleColors.labelPrimary),
        headlineLarge: AppleTextStyles.title3(color: AppleColors.labelPrimary),
        headlineMedium: AppleTextStyles.headline(color: AppleColors.labelPrimary),
        titleLarge: AppleTextStyles.title3(color: AppleColors.labelPrimary),
        titleMedium: AppleTextStyles.headline(color: AppleColors.labelPrimary),
        titleSmall: AppleTextStyles.subheadline(color: AppleColors.labelPrimary),
        bodyLarge: AppleTextStyles.body(color: AppleColors.labelPrimary),
        bodyMedium: AppleTextStyles.callout(color: AppleColors.labelPrimary),
        bodySmall: AppleTextStyles.footnote(color: AppleColors.labelSecondary),
        labelLarge: AppleTextStyles.headline(color: accent),
        labelMedium: AppleTextStyles.subheadline(color: AppleColors.labelSecondary),
        labelSmall: AppleTextStyles.caption1(color: AppleColors.labelSecondary),
      ),
      iconTheme: const IconThemeData(
        color: AppleColors.labelPrimary,
        size: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppleColors.fillTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleDesignSystem.spacing16,
          vertical: AppleDesignSystem.spacing12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing20,
            vertical: AppleDesignSystem.spacing12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing16,
            vertical: AppleDesignSystem.spacing8,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: AppleColors.fillTertiary,
        thumbColor: Colors.white,
        overlayColor: accent.withOpacity(0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return AppleColors.fillTertiary;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: AppleColors.fillTertiary,
      ),
    );
  }
  
  static ThemeData dark({Color? accentColor}) {
    final accent = accentColor ?? AppleColors.systemBlueDark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: AppleColors.backgroundSecondaryDark,
        error: AppleColors.systemRedDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppleColors.labelPrimaryDark,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppleColors.backgroundPrimaryDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppleColors.backgroundSecondaryDark.withOpacity(0.8),
        foregroundColor: AppleColors.labelPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppleTextStyles.headline(color: AppleColors.labelPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: AppleColors.backgroundSecondaryDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppleColors.separatorDark,
        thickness: 0.5,
      ),
      textTheme: TextTheme(
        displayLarge: AppleTextStyles.largeTitle(color: AppleColors.labelPrimaryDark),
        displayMedium: AppleTextStyles.title1(color: AppleColors.labelPrimaryDark),
        displaySmall: AppleTextStyles.title2(color: AppleColors.labelPrimaryDark),
        headlineLarge: AppleTextStyles.title3(color: AppleColors.labelPrimaryDark),
        headlineMedium: AppleTextStyles.headline(color: AppleColors.labelPrimaryDark),
        titleLarge: AppleTextStyles.title3(color: AppleColors.labelPrimaryDark),
        titleMedium: AppleTextStyles.headline(color: AppleColors.labelPrimaryDark),
        titleSmall: AppleTextStyles.subheadline(color: AppleColors.labelPrimaryDark),
        bodyLarge: AppleTextStyles.body(color: AppleColors.labelPrimaryDark),
        bodyMedium: AppleTextStyles.callout(color: AppleColors.labelPrimaryDark),
        bodySmall: AppleTextStyles.footnote(color: AppleColors.labelSecondaryDark),
        labelLarge: AppleTextStyles.headline(color: accent),
        labelMedium: AppleTextStyles.subheadline(color: AppleColors.labelSecondaryDark),
        labelSmall: AppleTextStyles.caption1(color: AppleColors.labelSecondaryDark),
      ),
      iconTheme: const IconThemeData(
        color: AppleColors.labelPrimaryDark,
        size: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppleColors.fillTertiaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleDesignSystem.spacing16,
          vertical: AppleDesignSystem.spacing12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing20,
            vertical: AppleDesignSystem.spacing12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing16,
            vertical: AppleDesignSystem.spacing8,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: AppleColors.fillTertiaryDark,
        thumbColor: Colors.white,
        overlayColor: accent.withOpacity(0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return AppleColors.fillTertiaryDark;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: AppleColors.fillTertiaryDark,
      ),
    );
  }
}
