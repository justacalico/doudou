import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doudou/ui/theme/app_tokens.dart';

// ============================================
// LEGACY ALIASES (delegate to AppTokens for migration)
// ============================================

class AppleDesignSystem {
  AppleDesignSystem._();

  static String get fontFamily => AppTokens.fontFamilyBody;
  static const List<String> fontFamilyFallback = [
    'Nunito',
    'Segoe UI',
    'sans-serif',
  ];

  static double get typeScaleCaption2 => AppTokens.typeScaleCaption2;
  static double get typeScaleCaption1 => AppTokens.typeScaleCaption1;
  static double get typeScaleFootnote => AppTokens.typeScaleFootnote;
  static double get typeScaleSubheadline => AppTokens.typeScaleSubheadline;
  static double get typeScaleCallout => AppTokens.typeScaleCallout;
  static double get typeScaleBody => AppTokens.typeScaleBody;
  static double get typeScaleHeadline => AppTokens.typeScaleHeadline;
  static double get typeScaleTitle3 => AppTokens.typeScaleTitle3;
  static double get typeScaleTitle2 => AppTokens.typeScaleTitle2;
  static double get typeScaleTitle1 => AppTokens.typeScaleTitle1;
  static double get typeScaleLargeTitle => AppTokens.typeScaleLargeTitle;

  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

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

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusRound = 100.0;

  static const double blurUltraThin = 10.0;
  static const double blurThin = 20.0;
  static const double blurRegular = 30.0;
  static const double blurThick = 40.0;
  static const double saturationDefault = 1.8;

  static const Curve springCurve = Curves.easeOutCubic;
  static const Curve interactiveCurve = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve snappyCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve gentleCurve = Cubic(0.25, 0.1, 0.25, 1.0);

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationMedium = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 500);

  static const double hoverScale = 1.02;
  static const double pressScale = 0.98;
  static const double pressOpacity = 0.7;
  static const double hoverOpacity = 0.9;

  static List<BoxShadow> shadowSmall(Color c) => AppTokens.shadowSm(c);
  static List<BoxShadow> shadowMedium(Color c) => AppTokens.shadowMd(c);
  static List<BoxShadow> shadowLarge(Color c) => AppTokens.shadowLg(c);
  static List<BoxShadow> shadowXLarge(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.20),
          offset: const Offset(0, 16),
          blurRadius: 48,
        ),
      ];
}

class AppleColors {
  AppleColors._();

  static const Color systemBlue = Color(0xFF3B82F6);
  static const Color systemGreen = Color(0xFF22C55E);
  static const Color systemIndigo = Color(0xFF6366F1);
  static const Color systemOrange = Color(0xFFF59E0B);
  static const Color systemPink = Color(0xFFEC4899);
  static const Color systemPurple = Color(0xFF0D9488);
  static const Color systemRed = Color(0xFFEF4444);
  static const Color systemTeal = Color(0xFF2DD4BF);
  static const Color systemYellow = Color(0xFFEAB308);

  static const Color systemBlueDark = Color(0xFF60A5FA);
  static const Color systemGreenDark = Color(0xFF22C55E);
  static const Color systemIndigoDark = Color(0xFF818CF8);
  static const Color systemOrangeDark = Color(0xFFFBBF24);
  static const Color systemPinkDark = Color(0xFFF472B6);
  static const Color systemPurpleDark = Color(0xFF2DD4BF);
  static const Color systemRedDark = Color(0xFFEF4444);
  static const Color systemTealDark = Color(0xFF2DD4BF);
  static const Color systemYellowDark = Color(0xFFFACC15);

  static const Color systemGray = Color(0xFF71717A);
  static const Color systemGray2 = Color(0xFFA1A1AA);
  static const Color systemGray3 = Color(0xFFD4D4D8);
  static const Color systemGray4 = Color(0xFFE4E4E7);
  static const Color systemGray5 = Color(0xFFF4F4F5);
  static const Color systemGray6 = Color(0xFFFAFAFA);

  static const Color systemGrayDark = Color(0xFF71717A);
  static const Color systemGray2Dark = Color(0xFF52525B);
  static const Color systemGray3Dark = Color(0xFF3F3F46);
  static const Color systemGray4Dark = Color(0xFF27272A);
  static const Color systemGray5Dark = Color(0xFF18181B);
  static const Color systemGray6Dark = Color(0xFF09090B);

  static const Color backgroundPrimary = Color(0xFFF8F7F4);
  static const Color backgroundSecondary = Color(0xFFF0EFEB);
  static const Color backgroundTertiary = Color(0xFFFFFFFF);
  static const Color backgroundGrouped = Color(0xFFF0EFEB);
  static const Color backgroundGroupedSecondary = Color(0xFFFFFFFF);

  static const Color backgroundPrimaryDark = Color(0xFF141418);
  static const Color backgroundSecondaryDark = Color(0xFF141418);
  static const Color backgroundTertiaryDark = Color(0xFF1A1A1F);
  static const Color backgroundGroupedDark = Color(0xFF141418);
  static const Color backgroundGroupedSecondaryDark = Color(0xFF1A1A1F);

  static const Color elevatedPrimaryDark = Color(0xFF1A1A1F);
  static const Color elevatedSecondaryDark = Color(0xFF1E1E24);
  static const Color elevatedTertiaryDark = Color(0xFF27272A);

  static const Color fillPrimary = Color(0x33787880);
  static const Color fillSecondary = Color(0x29787880);
  static const Color fillTertiary = Color(0x1F787880);
  static const Color fillQuaternary = Color(0x14787880);

  static const Color fillPrimaryDark = Color(0x5C787880);
  static const Color fillSecondaryDark = Color(0x52787880);
  static const Color fillTertiaryDark = Color(0x3D787880);
  static const Color fillQuaternaryDark = Color(0x2E787880);

  static const Color labelPrimary = Color(0xFF1A1A1F);
  static const Color labelSecondary = Color(0x990F0F12);
  static const Color labelTertiary = Color(0x4D0F0F12);
  static const Color labelQuaternary = Color(0x2E0F0F12);

  static const Color labelPrimaryDark = Color(0xFFFFFFFF);
  static const Color labelSecondaryDark = Color(0xB3FFFFFF);
  static const Color labelTertiaryDark = Color(0x66FFFFFF);
  static const Color labelQuaternaryDark = Color(0x29FFFFFF);

  static const Color separator = Color(0x4D3C3C43);
  static const Color separatorOpaque = Color(0xFFE0DFDB);
  static const Color separatorDark = Color(0x33FFFFFF);
  static const Color separatorOpaqueDark = Color(0xFF2A2A30);

  static Color glassLight = const Color(0xFFFFFFFF).withValues(alpha: 0.72);
  static Color glassDark = const Color(0xFF1A1A1F).withValues(alpha: 0.80);
  static Color glassLightThin = const Color(0xFFFFFFFF).withValues(alpha: 0.50);
  static Color glassDarkThin = const Color(0xFF1A1A1F).withValues(alpha: 0.60);
  static Color glassLightUltraThin = const Color(0xFFFFFFFF).withValues(alpha: 0.30);
  static Color glassDarkUltraThin = const Color(0xFF1A1A1F).withValues(alpha: 0.40);

  static Color vibrancyLight = const Color(0xFFFFFFFF).withValues(alpha: 0.15);
  static Color vibrancyDark = const Color(0xFF000000).withValues(alpha: 0.25);
}

// ============================================
// TEXT STYLES (AppTokens typography)
// ============================================

class AppleTextStyles {
  AppleTextStyles._();

  static TextStyle largeTitle({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyDisplay,
        fontSize: AppTokens.typeScaleLargeTitle,
        fontWeight: AppTokens.weightBold,
        letterSpacing: -0.25,
        height: 1.2,
        color: color,
      );

  static TextStyle title1({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyDisplay,
        fontSize: AppTokens.typeScaleTitle1,
        fontWeight: AppTokens.weightBold,
        letterSpacing: -0.2,
        height: 1.22,
        color: color,
      );

  static TextStyle title2({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyDisplay,
        fontSize: AppTokens.typeScaleTitle2,
        fontWeight: AppTokens.weightBold,
        letterSpacing: -0.15,
        height: 1.27,
        color: color,
      );

  static TextStyle title3({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyDisplay,
        fontSize: AppTokens.typeScaleTitle3,
        fontWeight: AppTokens.weightSemiBold,
        letterSpacing: -0.1,
        height: 1.25,
        color: color,
      );

  static TextStyle headline({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyBody,
        fontSize: AppTokens.typeScaleHeadline,
        fontWeight: AppTokens.weightSemiBold,
        letterSpacing: -0.2,
        height: 1.29,
        color: color,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyBody,
        fontSize: AppTokens.typeScaleBody,
        fontWeight: AppTokens.weightRegular,
        letterSpacing: -0.2,
        height: 1.4,
        color: color,
      );

  static TextStyle callout({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyBody,
        fontSize: AppTokens.typeScaleCallout,
        fontWeight: AppTokens.weightRegular,
        letterSpacing: -0.15,
        height: 1.31,
        color: color,
      );

  static TextStyle subheadline({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyBody,
        fontSize: AppTokens.typeScaleSubheadline,
        fontWeight: AppTokens.weightRegular,
        letterSpacing: -0.1,
        height: 1.33,
        color: color,
      );

  static TextStyle footnote({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyBody,
        fontSize: AppTokens.typeScaleFootnote,
        fontWeight: AppTokens.weightRegular,
        letterSpacing: 0,
        height: 1.38,
        color: color,
      );

  static TextStyle caption1({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyBody,
        fontSize: AppTokens.typeScaleCaption1,
        fontWeight: AppTokens.weightRegular,
        letterSpacing: 0,
        height: 1.33,
        color: color,
      );

  static TextStyle caption2({Color? color}) => TextStyle(
        fontFamily: AppTokens.fontFamilyBody,
        fontSize: AppTokens.typeScaleCaption2,
        fontWeight: AppTokens.weightRegular,
        letterSpacing: 0.05,
        height: 1.18,
        color: color,
      );
}

// ============================================
// THEME DATA BUILDERS (AppTokens + Google Fonts)
// ============================================

class AppleTheme {
  AppleTheme._();

  static TextTheme _buildTextThemeLight(Color labelPrimary, Color labelSecondary, Color labelTertiary) {
    return TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: AppTokens.typeScaleLargeTitle,
        fontWeight: AppTokens.weightBold,
        color: labelPrimary,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: AppTokens.typeScaleTitle1,
        fontWeight: AppTokens.weightBold,
        color: labelPrimary,
        height: 1.22,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: AppTokens.typeScaleTitle2,
        fontWeight: AppTokens.weightBold,
        color: labelPrimary,
        height: 1.27,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: AppTokens.typeScaleTitle1,
        fontWeight: AppTokens.weightBold,
        color: labelPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: AppTokens.typeScaleTitle2,
        fontWeight: AppTokens.weightBold,
        color: labelPrimary,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: AppTokens.typeScaleTitle3,
        fontWeight: AppTokens.weightSemiBold,
        color: labelPrimary,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleHeadline,
        fontWeight: AppTokens.weightSemiBold,
        color: labelPrimary,
      ),
      titleMedium: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleCallout,
        fontWeight: AppTokens.weightRegular,
        color: labelPrimary,
      ),
      titleSmall: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleSubheadline,
        fontWeight: AppTokens.weightRegular,
        color: labelPrimary,
      ),
      bodyLarge: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleBody,
        fontWeight: AppTokens.weightRegular,
        color: labelPrimary,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleCallout,
        fontWeight: AppTokens.weightRegular,
        color: labelPrimary,
      ),
      bodySmall: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleFootnote,
        fontWeight: AppTokens.weightRegular,
        color: labelSecondary,
      ),
      labelLarge: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleSubheadline,
        fontWeight: AppTokens.weightRegular,
        color: labelPrimary,
      ),
      labelMedium: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleFootnote,
        fontWeight: AppTokens.weightRegular,
        color: labelSecondary,
      ),
      labelSmall: GoogleFonts.nunito(
        fontSize: AppTokens.typeScaleCaption1,
        fontWeight: AppTokens.weightRegular,
        color: labelTertiary,
      ),
    );
  }

  /// Creates a Light Theme (organic refined palette)
  static ThemeData light({Color? accentColor}) {
    final primaryColor = accentColor ?? AppTokens.accentDefaultLight;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTokens.fontFamilyBody,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryColor.withValues(alpha: 0.15),
        secondary: AppTokens.textSecondaryLight,
        secondaryContainer: AppTokens.backgroundSecondaryLight,
        surface: AppTokens.backgroundPrimaryLight,
        surfaceContainerHighest: AppTokens.backgroundSecondaryLight,
        error: AppTokens.errorLight,
        onPrimary: Colors.white,
        onSecondary: AppTokens.textPrimaryLight,
        onSurface: AppTokens.textPrimaryLight,
        onSurfaceVariant: AppTokens.textSecondaryLight,
        outline: AppTokens.separatorLight,
        outlineVariant: AppTokens.separatorOpaqueLight,
        shadow: Colors.black,
        inverseSurface: AppTokens.textPrimaryLight,
        onInverseSurface: AppTokens.backgroundPrimaryLight,
      ),
      scaffoldBackgroundColor: AppTokens.backgroundPrimaryLight,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        color: AppTokens.surfaceLight,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTokens.backgroundPrimaryLight.withValues(alpha: 0.9),
        foregroundColor: AppTokens.textPrimaryLight,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: AppTokens.typeScaleHeadline,
          fontWeight: AppTokens.weightSemiBold,
          color: AppTokens.textPrimaryLight,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppTokens.backgroundPrimaryLight.withValues(alpha: 0.9),
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.nunito(
            fontSize: AppTokens.typeScaleCaption2,
            color: AppTokens.textSecondaryLight,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: AppTokens.textPrimaryLight, size: 24),
      textTheme: _buildTextThemeLight(
        AppTokens.textPrimaryLight,
        AppTokens.textSecondaryLight,
        AppTokens.textTertiaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.separatorLight,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spacing16,
          vertical: AppTokens.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        selectedTileColor: primaryColor.withValues(alpha: 0.15),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: AppTokens.surfaceElevatedLight,
        thumbColor: Colors.white,
        overlayColor: primaryColor.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return AppTokens.systemGray4;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  static const Color _oledBlack = Color(0xFF000000);

  /// Creates a Dark Theme. When [oled] is true, surfaces use pure black.
  static ThemeData dark({Color? accentColor, bool oled = false}) {
    final primaryColor = accentColor ?? AppTokens.accentDefaultDark;
    final bgPrimary = oled ? _oledBlack : AppTokens.backgroundPrimaryDark;
    final bgSecondary = oled ? _oledBlack : AppTokens.backgroundSecondaryDark;
    final bgTertiary = oled ? _oledBlack : AppTokens.backgroundTertiaryDark;
    final elevated = oled ? _oledBlack : AppTokens.surfaceElevatedDark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTokens.fontFamilyBody,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: primaryColor.withValues(alpha: 0.25),
        secondary: AppTokens.textSecondaryDark,
        secondaryContainer: AppTokens.backgroundTertiaryDark,
        surface: bgSecondary,
        surfaceContainerHighest: bgTertiary,
        error: AppTokens.errorDark,
        onPrimary: Colors.white,
        onSecondary: AppTokens.textPrimaryDark,
        onSurface: AppTokens.textPrimaryDark,
        onSurfaceVariant: AppTokens.textSecondaryDark,
        outline: AppTokens.separatorDark,
        outlineVariant: AppTokens.separatorOpaqueDark,
        shadow: Colors.black,
        inverseSurface: AppTokens.textPrimaryDark,
        onInverseSurface: bgPrimary,
      ),
      scaffoldBackgroundColor: bgPrimary,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        color: elevated,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: oled ? _oledBlack : AppTokens.backgroundPrimaryDark.withValues(alpha: 0.9),
        foregroundColor: AppTokens.textPrimaryDark,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: AppTokens.typeScaleHeadline,
          fontWeight: AppTokens.weightSemiBold,
          color: AppTokens.textPrimaryDark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: oled ? _oledBlack : AppTokens.backgroundSecondaryDark.withValues(alpha: 0.9),
        indicatorColor: primaryColor.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.nunito(
            fontSize: AppTokens.typeScaleCaption2,
            color: AppTokens.textSecondaryDark,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: oled ? _oledBlack : AppTokens.surfaceElevatedDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: oled ? _oledBlack : AppTokens.surfaceElevatedDark,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusLg)),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppTokens.textPrimaryDark,
        size: 24,
      ),
      textTheme: _buildTextThemeLight(
        AppTokens.textPrimaryDark,
        AppTokens.textSecondaryDark,
        AppTokens.textTertiaryDark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.separatorDark,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spacing16,
          vertical: AppTokens.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        selectedTileColor: primaryColor.withValues(alpha: 0.25),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: AppTokens.backgroundTertiaryDark,
        thumbColor: Colors.white,
        overlayColor: primaryColor.withValues(alpha: 0.25),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return AppTokens.systemGray3Dark;
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
          ? AppleColors.backgroundSecondaryDark.withValues(alpha: 0.8)
          : AppleColors.backgroundPrimary.withValues(alpha: 0.8),
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
