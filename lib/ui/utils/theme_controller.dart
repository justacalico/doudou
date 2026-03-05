import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:palette_generator/palette_generator.dart';
import '/utils/helper.dart';

TextTheme _interTextTheme(TextTheme base) {
  try {
    return GoogleFonts.interTextTheme(base);
  } catch (_) {
    return base;
  }
}

ThemeType themeTypeFromStorage(dynamic rawThemeModeType) {
  if (rawThemeModeType is! int) return ThemeType.system;
  switch (rawThemeModeType) {
    case 0:
      return ThemeType.dynamic;
    case 1:
      return ThemeType.system;
    case 2:
      return ThemeType.dark;
    case 3:
      return ThemeType.light;
    case 4:
      return ThemeType.oled;
    case 5:
      return ThemeType.system;
    default:
      return ThemeType.system;
  }
}

int themeTypeToStorage(ThemeType themeType) =>
    ThemeType.values.indexOf(themeType);

class ThemeController extends GetxController {
  final primaryColor = Colors.deepPurple[400].obs;
  final dynamicColor = Colors.deepPurple[400]!.obs;
  final textColor = Colors.white24.obs;
  final themedata = Rxn<ThemeData>();

  /// The method channel for setting the title bar color on Windows.
  final platform = const MethodChannel('win_titlebar_color');
  String? currentSongId;
  late Brightness systemBrightness;

  ThemeController() {
    systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final appPrefs = Hive.box('AppPrefs');
    final primaryInt = appPrefs.get("themePrimaryColor") ?? 4278199603;
    primaryColor.value = Color(primaryInt);

    final dynamicColorInt = appPrefs.get("dynamicColorPrimary") ?? primaryInt;
    dynamicColor.value = Color(dynamicColorInt);
    final rawThemeType = appPrefs.get("themeModeType");
    final savedThemeType = themeTypeFromStorage(rawThemeType);
    if (rawThemeType is! int ||
        rawThemeType < 0 ||
        rawThemeType >= ThemeType.values.length) {
      appPrefs.put("themeModeType", themeTypeToStorage(savedThemeType));
    }
    changeThemeModeType(savedThemeType);

    _listenSystemBrightness();

    super.onInit();
  }

  void _listenSystemBrightness() {
    final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
    platformDispatcher.onPlatformBrightnessChanged = () {
      systemBrightness = platformDispatcher.platformBrightness;
      changeThemeModeType(
          themeTypeFromStorage(Hive.box('AppPrefs').get("themeModeType")),
          sysCall: true);
    };
  }

  void changeThemeModeType(dynamic value, {bool sysCall = false}) {
    final type = value as ThemeType;
    if (type == ThemeType.system) {
      themedata.value = _createThemeData(
          null,
          systemBrightness == Brightness.light
              ? ThemeType.light
              : ThemeType.dark);
    } else {
      if (sysCall) return;
      MaterialColor? swatch;
      if (type == ThemeType.dynamic) {
        swatch = _createMaterialColor(primaryColor.value!);
      }
      themedata.value = _createThemeData(swatch, type);
    }
    setWindowsTitleBarColor(themedata.value!.scaffoldBackgroundColor);
  }

  void setTheme(ImageProvider imageProvider, String songId) async {
    if (songId == currentSongId) return;
    PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
        ResizeImage(imageProvider, height: 200, width: 200));
    //final colorList = generator.colors;
    final paletteColor = generator.dominantColor ??
        generator.darkMutedColor ??
        generator.darkVibrantColor ??
        generator.lightMutedColor ??
        generator.lightVibrantColor;
    primaryColor.value = paletteColor!.color;
    textColor.value = paletteColor.bodyTextColor;
    // printINFO(paletteColor.color.computeLuminance().toString());0.11 ref
    if (paletteColor.color.computeLuminance() > 0.10) {
      primaryColor.value = paletteColor.color.withLightness(0.10);
      textColor.value = Colors.white54;
    }
    final primarySwatch = _createMaterialColor(primaryColor.value!);
    final appPrefs = Hive.box('AppPrefs');
    currentSongId = songId;
    appPrefs.put("themePrimaryColor", (primaryColor.value!).toARGB32());
    final savedType = themeTypeFromStorage(appPrefs.get("themeModeType"));
    if (savedType == ThemeType.dynamic) {
      themedata.value = _createThemeData(primarySwatch, ThemeType.dynamic,
          textColor: textColor.value,
          titleColorSwatch: _createMaterialColor(textColor.value));
      setWindowsTitleBarColor(themedata.value!.scaffoldBackgroundColor);
      return;
    }
    changeThemeModeType(savedType);
  }

  void setDynamicColor(Color color) {
    dynamicColor.value = color;
    final appPrefs = Hive.box('AppPrefs');
    appPrefs.put("dynamicColorPrimary", color.toARGB32());
    final savedType = themeTypeFromStorage(appPrefs.get("themeModeType"));
    if (savedType == ThemeType.dynamic) {
      primaryColor.value = color;
      final swatch = _createMaterialColor(color);
      themedata.value = _createThemeData(swatch, ThemeType.dynamic);
      setWindowsTitleBarColor(themedata.value!.scaffoldBackgroundColor);
      return;
    }
    changeThemeModeType(savedType);
  }

  ThemeData _createThemeData(MaterialColor? primarySwatch, ThemeType themeType,
      {MaterialColor? titleColorSwatch, Color? textColor}) {
    if (themeType == ThemeType.dynamic) {
      final dynamicSwatch =
          primarySwatch ?? _createMaterialColor(dynamicColor.value);
      final accentSwatch = dynamicSwatch;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.white.withValues(alpha: 0.002),
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: true),
      );

      final baseScheme = ColorScheme.fromSwatch(
          accentColor: dynamicSwatch[600],
          brightness: Brightness.dark,
          backgroundColor: dynamicSwatch[700],
          primarySwatch: dynamicSwatch);
      final scheme = baseScheme.copyWith(
          primary: accentSwatch[500],
          surface: dynamicSwatch[800],
          surfaceContainerHighest: dynamicSwatch[600],
          onSurface: Colors.white,
          secondary: accentSwatch[600],
          onSecondary: Colors.white);
      final baseTheme = ThemeData(
          useMaterial3: false,
          primaryColor: accentSwatch[500],
          colorScheme: scheme,
          //accentColor: primarySwatch[200],
          dialogTheme: DialogThemeData(backgroundColor: dynamicSwatch[700]),
          cardColor: dynamicSwatch[600],
          primaryColorLight: accentSwatch[400],
          primaryColorDark: dynamicSwatch[700],
          //secondaryHeaderColor: primarySwatch[50],
          canvasColor: dynamicSwatch[700],
          //scaffoldBackgroundColor: primarySwatch[700],
          bottomSheetTheme: BottomSheetThemeData(
              backgroundColor: dynamicSwatch[600],
              modalBarrierColor: dynamicSwatch[400]),
          textTheme: TextTheme(
            titleLarge: const TextStyle(
                fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white),
            titleMedium: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
            titleSmall: TextStyle(color: dynamicSwatch[100]),
            bodyMedium: TextStyle(color: dynamicSwatch[100]),
            labelMedium: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 23,
                color: textColor ?? dynamicSwatch[50]),
            labelSmall: TextStyle(
                fontSize: 15,
                color: titleColorSwatch != null
                    ? titleColorSwatch[900]
                    : dynamicSwatch[100],
                letterSpacing: 0,
                fontWeight: FontWeight.bold),
          ),
          tabBarTheme: const TabBarThemeData(indicatorColor: Colors.white),
          progressIndicatorTheme: ProgressIndicatorThemeData(
              linearTrackColor: (dynamicSwatch[300])!.computeLuminance() > 0.3
                  ? Colors.black54
                  : Colors.white70,
              color: textColor),
          navigationRailTheme: NavigationRailThemeData(
              backgroundColor: dynamicSwatch[700],
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedIconTheme: IconThemeData(color: dynamicSwatch[100]),
              selectedLabelTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              unselectedLabelTextStyle: TextStyle(
                  color: dynamicSwatch[100], fontWeight: FontWeight.bold)),
          sliderTheme: SliderThemeData(
            inactiveTrackColor: dynamicSwatch[300],
            activeTrackColor: textColor,
            valueIndicatorColor: accentSwatch[400],
            thumbColor: Colors.white,
          ),
          textSelectionTheme: TextSelectionThemeData(
              cursorColor: accentSwatch[200],
              selectionColor: accentSwatch[200],
              selectionHandleColor: accentSwatch[200]),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: dynamicSwatch[700],
              focusColor: Colors.white,
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white)))
          //scaffoldBackgroundColor: primarySwatch[700]
          );
      return baseTheme.copyWith(
          textTheme: _interTextTheme(baseTheme.textTheme));
    } else if (themeType == ThemeType.dark) {
      const darkSurface = Color(0xFF121212);
      const darkBackground = Color(0xFF1E1E1E);
      const darkSurfaceContainer = Color(0xFF2C2C2C);
      final darkAccent500 = Colors.grey[600]!;
      final darkAccent600 = Colors.grey[700]!;
      final darkAccent400 = Colors.grey[600]!;
      final darkAccent300 = Colors.grey[600]!;
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: darkSurface,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: true),
      );
      final darkScheme = ColorScheme.fromSwatch(
          accentColor: darkAccent600,
          brightness: Brightness.dark,
          backgroundColor: darkSurface);
      final scheme = darkScheme.copyWith(
          primary: darkAccent500,
          surface: darkSurface,
          surfaceContainerHighest: darkSurfaceContainer,
          onSurface: Colors.white,
          secondary: darkAccent600,
          onSecondary: Colors.white);
      final baseTheme = ThemeData(
          useMaterial3: false,
          brightness: Brightness.dark,
          canvasColor: darkSurface,
          scaffoldBackgroundColor: darkSurface,
          primaryColor: darkSurface,
          primaryColorDark: darkBackground,
          primaryColorLight: darkAccent600,
          colorScheme: scheme,
          progressIndicatorTheme: ProgressIndicatorThemeData(
              color: darkAccent500, linearTrackColor: Colors.white70),
          textTheme: const TextTheme(
              titleLarge: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
              titleMedium: TextStyle(
                fontWeight: FontWeight.bold,
              ),
              titleSmall: TextStyle(),
              labelMedium: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 23,
              ),
              labelSmall: TextStyle(
                  fontSize: 15, letterSpacing: 0, fontWeight: FontWeight.bold),
              bodyMedium: TextStyle(color: Colors.grey)),
          navigationRailTheme: NavigationRailThemeData(
              backgroundColor: darkSurface,
              selectedIconTheme: const IconThemeData(
                color: Colors.white,
              ),
              unselectedIconTheme: IconThemeData(color: Colors.grey[500]),
              selectedLabelTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              unselectedLabelTextStyle: TextStyle(
                  color: Colors.grey[500], fontWeight: FontWeight.bold)),
          bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: darkSurface, modalBarrierColor: darkBackground),
          sliderTheme: SliderThemeData(
              inactiveTrackColor: Colors.grey[600],
              activeTrackColor: darkAccent500,
              valueIndicatorColor: darkAccent600,
              thumbColor: darkAccent500),
          textSelectionTheme: TextSelectionThemeData(
              cursorColor: darkAccent400,
              selectionColor: darkAccent300,
              selectionHandleColor: darkAccent400),
          inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: darkSurfaceContainer,
              focusColor: Colors.white,
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white))));
      return baseTheme.copyWith(
          textTheme: _interTextTheme(baseTheme.textTheme));
    } else if (themeType == ThemeType.oled) {
      const oledSurfaceContainer = Color(0xFF1A1A1A);
      final oledAccent500 = Colors.grey[700]!;
      final oledAccent600 = Colors.grey[800]!;
      final oledAccent400 = Colors.grey[700]!;
      final oledAccent300 = Colors.grey[700]!;
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: true),
      );
      final oledScheme = ColorScheme.fromSwatch(
          accentColor: oledAccent600, brightness: Brightness.dark);
      final scheme = oledScheme.copyWith(
          primary: oledAccent500,
          surface: Colors.black,
          surfaceContainerHighest: oledSurfaceContainer,
          onSurface: Colors.white38,
          secondary: oledAccent600,
          onSecondary: Colors.white);
      final baseTheme = ThemeData(
          useMaterial3: false,
          brightness: Brightness.dark,
          canvasColor: Colors.black,
          scaffoldBackgroundColor: Colors.black,
          primaryColor: Colors.black,
          primaryColorDark: Colors.black,
          primaryColorLight: oledAccent600,
          colorScheme: scheme,
          progressIndicatorTheme: ProgressIndicatorThemeData(
              color: oledAccent500, linearTrackColor: Colors.white),
          textTheme: const TextTheme(
              titleLarge: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
              titleMedium: TextStyle(
                fontWeight: FontWeight.bold,
              ),
              titleSmall: TextStyle(),
              labelMedium: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 23,
              ),
              labelSmall: TextStyle(
                  fontSize: 15, letterSpacing: 0, fontWeight: FontWeight.bold),
              bodyMedium: TextStyle(color: Colors.grey)),
          navigationRailTheme: const NavigationRailThemeData(
              backgroundColor: Colors.black,
              selectedIconTheme: IconThemeData(
                color: Colors.white,
              ),
              unselectedIconTheme: IconThemeData(color: Colors.white38),
              selectedLabelTextStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              unselectedLabelTextStyle: TextStyle(
                  color: Colors.white38, fontWeight: FontWeight.bold)),
          bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Colors.black, modalBarrierColor: Colors.black),
          sliderTheme: const SliderThemeData(
              inactiveTrackColor: Colors.white30,
              activeTrackColor: Colors.white,
              valueIndicatorColor: Colors.black38,
              thumbColor: Colors.white),
          textSelectionTheme: TextSelectionThemeData(
              cursorColor: oledAccent400,
              selectionColor: oledAccent300,
              selectionHandleColor: oledAccent400),
          inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: oledSurfaceContainer,
              focusColor: Colors.white,
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white))));
      return baseTheme.copyWith(
          textTheme: _interTextTheme(baseTheme.textTheme));
    } else {
      final lightAccent500 = Colors.grey[400]!;
      final lightAccent600 = Colors.grey[800]!;
      final lightAccent200 = Colors.grey[300]!;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.white.withValues(alpha: 0.002),
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false),
      );
      final baseTheme = ThemeData(
          useMaterial3: false,
          brightness: Brightness.light,
          canvasColor: Colors.white,
          colorScheme: ColorScheme.fromSwatch(
                  accentColor: lightAccent500,
                  backgroundColor: Colors.white,
                  cardColor: Colors.white,
                  brightness: Brightness.light)
              .copyWith(
            primary: lightAccent500,
            secondary: lightAccent500,
          ),
          primaryColor: Colors.white,
          primaryColorLight: lightAccent200,
          progressIndicatorTheme: ProgressIndicatorThemeData(
              linearTrackColor: Colors.grey[700], color: lightAccent500),
          textTheme: TextTheme(
              titleLarge: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
              titleMedium: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              titleSmall: const TextStyle(),
              labelMedium: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 23,
              ),
              labelSmall: const TextStyle(
                  fontSize: 15, letterSpacing: 0, fontWeight: FontWeight.bold),
              bodyMedium: TextStyle(color: Colors.grey[700])),
          navigationRailTheme: NavigationRailThemeData(
              backgroundColor: Colors.white,
              selectedIconTheme: const IconThemeData(color: Colors.black),
              unselectedIconTheme: IconThemeData(color: Colors.grey[800]),
              selectedLabelTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              unselectedLabelTextStyle: TextStyle(
                  color: Colors.grey[800], fontWeight: FontWeight.bold)),
          bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Colors.white, modalBarrierColor: Colors.white),
          sliderTheme: SliderThemeData(
            //base bar color
            inactiveTrackColor: Colors.black38,
            //buffered progress
            activeTrackColor: lightAccent600,
            //progress bar color
            valueIndicatorColor: Colors.white38,
            thumbColor: lightAccent600,
          ),
          textSelectionTheme: TextSelectionThemeData(
              cursorColor: lightAccent500,
              selectionColor: lightAccent200,
              selectionHandleColor: lightAccent500),
          dialogTheme: DialogThemeData(backgroundColor: Colors.grey[200]),
          inputDecorationTheme: const InputDecorationTheme(
              focusColor: Colors.black,
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black))));
      return baseTheme.copyWith(
          textTheme: _interTextTheme(baseTheme.textTheme));
    }
  }

  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = (color.r * 255).round().clamp(0, 255);
    final int g = (color.g * 255).round().clamp(0, 255);
    final int b = (color.b * 255).round().clamp(0, 255);

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }

  Future<void> setWindowsTitleBarColor(Color color) async {
    if (!GetPlatform.isWindows) return;
    try {
      Future.delayed(
          const Duration(milliseconds: 350),
          () async => await platform.invokeMethod('setTitleBarColor', {
                'r': (color.r * 255).round().clamp(0, 255),
                'g': (color.g * 255).round().clamp(0, 255),
                'b': (color.b * 255).round().clamp(0, 255),
              }));
    } on PlatformException catch (e) {
      printERROR("Failed to set title bar color: ${e.message}");
    }
  }
}

extension ComplementaryColor on Color {
  Color get complementaryColor => getComplementaryColor(this);
  Color getComplementaryColor(Color color) {
    int r = 255 - (color.r * 255).round().clamp(0, 255);
    int g = 255 - (color.g * 255).round().clamp(0, 255);
    int b = 255 - (color.b * 255).round().clamp(0, 255);
    return Color.fromARGB((color.a * 255).round().clamp(0, 255), r, g, b);
  }
}

extension ColorWithHSL on Color {
  HSLColor get hsl => HSLColor.fromColor(this);

  Color withSaturation(double saturation) {
    return hsl.withSaturation(clampDouble(saturation, 0.0, 1.0)).toColor();
  }

  Color withLightness(double lightness) {
    return hsl.withLightness(clampDouble(lightness, 0.0, 1.0)).toColor();
  }

  Color withHue(double hue) {
    return hsl.withHue(clampDouble(hue, 0.0, 360.0)).toColor();
  }
}

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${((a * 255).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0')}'
      '${((r * 255).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0')}'
      '${((g * 255).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0')}'
      '${((b * 255).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0')}';
}

enum ThemeType {
  dynamic,
  system,
  dark,
  light,
  oled,
}
