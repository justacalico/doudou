import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:palette_generator/palette_generator.dart';
import '/ui/design/doudou_motion.dart';
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

const Color _peachPinkFallback = Color(0xFFE8A598);

class ThemeController extends GetxController {
  final primaryColor = Colors.deepPurple[400].obs;
  final dynamicColor = Colors.deepPurple[400]!.obs;
  final textColor = Colors.white24.obs;
  final themedata = Rxn<ThemeData>();
  bool _hasTemporaryDynamicAccent = false;
  Color? _temporaryDynamicAccent;
  Timer? _trackAccentAnimationTimer;
  int _trackAccentAnimationToken = 0;

  final platform = const MethodChannel('win_titlebar_color');
  String? currentSongId;
  late Brightness systemBrightness;

  ThemeController() {
    systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final appPrefs = Hive.box('AppPrefs');
    final primaryInt = appPrefs.get("themePrimaryColor") ?? _peachPinkFallback.toARGB32();
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

  void setNowPlayingAccent(Color? color) {
    _cancelTrackAccentAnimation();
    primaryColor.value = color ?? _peachPinkFallback;
    currentSongId = null;
    if (color != null) {
      final appPrefs = Hive.box('AppPrefs');
      appPrefs.put("themePrimaryColor", primaryColor.value!.toARGB32());
    }
    final savedType = themeTypeFromStorage(Hive.box('AppPrefs').get("themeModeType"));
    changeThemeModeType(savedType);
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
    Color nextAccent = paletteColor!.color;
    textColor.value = paletteColor.bodyTextColor;
    // printINFO(paletteColor.color.computeLuminance().toString());0.11 ref
    if (paletteColor.color.computeLuminance() > 0.10) {
      nextAccent = paletteColor.color.withLightness(0.10);
      textColor.value = Colors.white54;
    }
    currentSongId = songId;
    _animateTrackAccentTo(nextAccent);
  }

  void setDynamicColor(Color color) {
    _cancelTrackAccentAnimation();
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
    _cancelTrackAccentAnimation();
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

  void _cancelTrackAccentAnimation() {
    _trackAccentAnimationToken++;
    _trackAccentAnimationTimer?.cancel();
    _trackAccentAnimationTimer = null;
  }

  void _animateTrackAccentTo(
    Color target, {
    Duration duration = DoudouMotion.theme,
  }) {
    _cancelTrackAccentAnimation();
    final appPrefs = Hive.box('AppPrefs');
    final savedType = themeTypeFromStorage(appPrefs.get("themeModeType"));
    final from = primaryColor.value ?? _peachPinkFallback;
    final token = _trackAccentAnimationToken;
    final start = DateTime.now();
    const tick = Duration(milliseconds: 16);

    void applyColor(Color color, {bool persist = false}) {
      primaryColor.value = color;
      dynamicColor.value = color;
      changeThemeModeType(savedType);
      if (persist) {
        appPrefs.put("themePrimaryColor", color.toARGB32());
        appPrefs.put("dynamicColorPrimary", color.toARGB32());
      }
    }

    if (duration == Duration.zero || from == target) {
      applyColor(target, persist: true);
      return;
    }

    _trackAccentAnimationTimer = Timer.periodic(tick, (timer) {
      if (token != _trackAccentAnimationToken) {
        timer.cancel();
        return;
      }
      final elapsedMs = DateTime.now().difference(start).inMilliseconds;
      final t = (elapsedMs / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(t);
      final next = Color.lerp(from, target, eased) ?? target;
      final done = t >= 1.0;
      applyColor(done ? target : next, persist: done);
      if (done) {
        timer.cancel();
      }
    });
  }

  ThemeData _createThemeData(MaterialColor? primarySwatch, ThemeType themeType) {
    final accent = primaryColor.value ?? _peachPinkFallback;
    final theme = switch (themeType) {
      ThemeType.dynamic => DoudouTheme.dark(
          accent: (primarySwatch ?? _currentDynamicSwatch())[500] ??
              primaryColor.value ??
              _peachPinkFallback,
        ),
      ThemeType.dark => DoudouTheme.dark(accent: accent),
      ThemeType.oled => DoudouTheme.oled(accent: accent),
      ThemeType.light => DoudouTheme.light(accent: accent),
      ThemeType.system => DoudouTheme.dark(accent: accent),
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

  @override
  void onClose() {
    _cancelTrackAccentAnimation();
    super.onClose();
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
