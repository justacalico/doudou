import 'dart:async';
import 'dart:ui';

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

const Color _peachPinkFallback = Color(0xFFE8A598);

class _PaletteAccentCandidate {
  const _PaletteAccentCandidate(this.palette, this.populationNorm);

  final PaletteColor palette;
  final double populationNorm;
}

class ThemeController extends GetxController {
  final primaryColor = Colors.deepPurple[400].obs;
  final dynamicColor = Colors.deepPurple[400]!.obs;
  final textColor = Colors.white24.obs;
  final themedata = Rxn<ThemeData>();
  bool _hasTemporaryDynamicAccent = false;
  Color? _temporaryDynamicAccent;
  Timer? _trackAccentAnimationTimer;

  final platform = const MethodChannel('win_titlebar_color');
  String? currentSongId;
  late Brightness systemBrightness;

  ThemeController() {
    systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final appPrefs = Hive.box('AppPrefs');
    final primaryInt =
        appPrefs.get("themePrimaryColor") ?? _peachPinkFallback.toARGB32();
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
    final savedType =
        themeTypeFromStorage(Hive.box('AppPrefs').get("themeModeType"));
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
    final generator = await PaletteGenerator.fromImageProvider(
        ResizeImage(imageProvider, height: 200, width: 200));
    final paletteColor = _pickArtworkAccentCandidate(generator);
    final nextAccent = _normalizeArtworkAccent(
      paletteColor?.color ?? _peachPinkFallback,
    );
    textColor.value =
        nextAccent.computeLuminance() > 0.42 ? Colors.black87 : Colors.white70;
    currentSongId = songId;
    _animateTrackAccentTo(nextAccent);
  }

  PaletteColor? _pickArtworkAccentCandidate(PaletteGenerator generator) {
    final source = <PaletteColor?>[
      generator.vibrantColor,
      generator.darkVibrantColor,
      generator.lightVibrantColor,
      generator.dominantColor,
      generator.mutedColor,
      generator.darkMutedColor,
      generator.lightMutedColor,
    ];
    final byColor = <int, PaletteColor>{};
    for (final c in source) {
      if (c == null) continue;
      byColor[c.color.toARGB32()] = c;
    }
    if (byColor.isEmpty) return null;

    final candidates = byColor.values.toList(growable: false);
    var maxPopulation = 1;
    for (final candidate in candidates) {
      if (candidate.population > maxPopulation) {
        maxPopulation = candidate.population;
      }
    }
    final scored = candidates
        .map((c) => _PaletteAccentCandidate(c, c.population / maxPopulation))
        .toList(growable: false);

    scored.sort((a, b) {
      final scoreA = _paletteCandidateScore(a);
      final scoreB = _paletteCandidateScore(b);
      return scoreB.compareTo(scoreA);
    });
    return scored.first.palette;
  }

  double _paletteCandidateScore(_PaletteAccentCandidate candidate) {
    final hsl = HSLColor.fromColor(candidate.palette.color);
    final saturation = hsl.saturation;
    final lightness = hsl.lightness;
    final contrastFit =
        (1.0 - ((lightness - 0.48).abs() * 2.0)).clamp(0.0, 1.0);
    var score = (saturation * 0.65) +
        (candidate.populationNorm * 0.25) +
        (contrastFit * 0.10);

    if (saturation < 0.22) score -= 0.20;
    if (saturation < 0.30 && lightness >= 0.42 && lightness <= 0.74) {
      score -= 0.15;
    }
    if (saturation >= 0.55 && lightness >= 0.28 && lightness <= 0.62) {
      score += 0.12;
    }
    return score;
  }

  Color _normalizeArtworkAccent(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.90))
        .withLightness(hsl.lightness.clamp(0.34, 0.58))
        .toColor();
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
    _trackAccentAnimationTimer?.cancel();
    _trackAccentAnimationTimer = null;
  }

  void _animateTrackAccentTo(Color target) {
    _cancelTrackAccentAnimation();
    final appPrefs = Hive.box('AppPrefs');
    final savedType = themeTypeFromStorage(appPrefs.get("themeModeType"));

    void applyColor(Color color, {bool persist = false}) {
      primaryColor.value = color;
      dynamicColor.value = color;
      changeThemeModeType(savedType);
      if (persist) {
        appPrefs.put("themePrimaryColor", color.toARGB32());
        appPrefs.put("dynamicColorPrimary", color.toARGB32());
      }
    }

    // Avoid timer-driven ThemeData churn. Theme transitions are handled by
    // `AnimatedTheme` at the app boundary.
    applyColor(target, persist: true);
  }

  ThemeData _createThemeData(
      MaterialColor? primarySwatch, ThemeType themeType) {
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
