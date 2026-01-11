import 'package:flutter/cupertino.dart';

/// Apple Music-inspired theme constants
class AppTheme {
  // Colors - Light Mode
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color surfaceLight = CupertinoColors.white;
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF8E8E93);
  static const Color separatorLight = Color(0xFFC6C6C8);
  
  // Colors - Dark Mode
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color elevatedDark = Color(0xFF2C2C2E);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8E8E93);
  static const Color separatorDark = Color(0xFF38383A);
  
  // Accent Colors
  static const Color accentPink = Color(0xFFFA2D48);
  static const Color accentRed = Color(0xFFFF3B30);
  
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  
  // Border Radius
  static const double radiusS = 6.0;
  static const double radiusM = 10.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;
  
  // Typography
  static const double fontSizeCaption = 11.0;
  static const double fontSizeFootnote = 13.0;
  static const double fontSizeBody = 17.0;
  static const double fontSizeTitle3 = 20.0;
  static const double fontSizeTitle2 = 22.0;
  static const double fontSizeTitle1 = 28.0;
  static const double fontSizeLargeTitle = 34.0;
  
  // Album Art Sizes
  static const double albumArtSmall = 48.0;
  static const double albumArtMedium = 56.0;
  static const double albumArtLarge = 160.0;
  static const double albumArtXL = 200.0;
  
  // Mini Player Height
  static const double miniPlayerHeight = 64.0;
  static const double tabBarHeight = 50.0;
  
  // Helper methods
  static Color background(BuildContext context) {
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? backgroundDark
        : backgroundLight;
  }
  
  static Color surface(BuildContext context) {
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? surfaceDark
        : surfaceLight;
  }
  
  static Color elevated(BuildContext context) {
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? elevatedDark
        : surfaceLight;
  }
  
  static Color textPrimary(BuildContext context) {
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? textPrimaryDark
        : textPrimaryLight;
  }
  
  static Color textSecondary(BuildContext context) {
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? textSecondaryDark
        : textSecondaryLight;
  }
  
  static Color separator(BuildContext context) {
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? separatorDark
        : separatorLight;
  }
}
