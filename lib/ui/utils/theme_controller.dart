import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:palette_generator/palette_generator.dart';
import '/ui/design/doudou_theme.dart';
import '/utils/helper.dart';

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
  bool _hasTemporaryDynamicAccent = false;
  Color? _temporaryDynamicAccent;

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
        swatch = _currentDynamicSwatch();
      } else {
        _hasTemporaryDynamicAccent = false;
        _temporaryDynamicAccent = null;
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
    _hasTemporaryDynamicAccent = false;
    _temporaryDynamicAccent = null;
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

  MaterialColor _currentDynamicSwatch() {
    if (_hasTemporaryDynamicAccent && _temporaryDynamicAccent != null) {
      return _createMaterialColor(_temporaryDynamicAccent!);
    }
    return _createMaterialColor(primaryColor.value!);
  }

  void applyTemporaryDynamicAccent(Color color) {
    final savedType =
        themeTypeFromStorage(Hive.box('AppPrefs').get("themeModeType"));
    if (savedType != ThemeType.dynamic) return;
    _hasTemporaryDynamicAccent = true;
    _temporaryDynamicAccent = color;
    themedata.value =
        _createThemeData(_createMaterialColor(color), ThemeType.dynamic);
    setWindowsTitleBarColor(themedata.value!.scaffoldBackgroundColor);
  }

  void clearTemporaryDynamicAccent() {
    if (!_hasTemporaryDynamicAccent && _temporaryDynamicAccent == null) return;
    _hasTemporaryDynamicAccent = false;
    _temporaryDynamicAccent = null;
    final savedType =
        themeTypeFromStorage(Hive.box('AppPrefs').get("themeModeType"));
    if (savedType == ThemeType.dynamic) {
      themedata.value = _createThemeData(
          _createMaterialColor(primaryColor.value!), ThemeType.dynamic);
      setWindowsTitleBarColor(themedata.value!.scaffoldBackgroundColor);
    }
  }

  ThemeData _createThemeData(MaterialColor? primarySwatch, ThemeType themeType,
      {MaterialColor? titleColorSwatch, Color? textColor}) {
    final theme = switch (themeType) {
      ThemeType.dynamic => DoudouTheme.dark(
          accent: (primarySwatch ?? _currentDynamicSwatch())[500] ??
              primaryColor.value ??
              Colors.deepPurple[400]!,
        ),
      ThemeType.dark => DoudouTheme.dark(
          accent: primaryColor.value ?? Colors.deepPurple[400]!,
        ),
      ThemeType.oled => DoudouTheme.oled(
          accent: primaryColor.value ?? Colors.deepPurple[400]!,
        ),
      ThemeType.light => DoudouTheme.light(
          accent: primaryColor.value ?? Colors.deepPurple[400]!,
        ),
      ThemeType.system => DoudouTheme.dark(
          accent: primaryColor.value ?? Colors.deepPurple[400]!,
        ),
    };

    _applySystemUi(theme);
    return theme;
  }

  void _applySystemUi(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: true,
      ),
    );
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
