import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '/ui/design/doudou_theme.dart';
import '/ui/utils/theme_controller.dart' show ThemeType, themeTypeFromStorage;

@immutable
class AppThemeState {
  const AppThemeState({
    required this.theme,
    required this.type,
    required this.accent,
  });

  final ThemeData theme;
  final ThemeType type;
  final Color accent;
}

final appThemeProvider = StateNotifierProvider<AppThemeController, AppThemeState>(
  (ref) => AppThemeController(Hive.box('AppPrefs')),
);

class AppThemeController extends StateNotifier<AppThemeState> {
  AppThemeController(this._prefs)
      : super(_initial(_prefs));

  final Box _prefs;

  static const _fallbackAccent = Color(0xFFE8A598);

  static AppThemeState _initial(Box prefs) {
    final primaryInt = prefs.get('themePrimaryColor');
    final accent = primaryInt is int ? Color(primaryInt) : _fallbackAccent;

    final rawThemeType = prefs.get('themeModeType');
    final savedThemeType = themeTypeFromStorage(rawThemeType);
    final effective = savedThemeType == ThemeType.system
        ? ThemeType.dark
        : savedThemeType;

    return AppThemeState(
      theme: _buildTheme(effective, accent),
      type: savedThemeType,
      accent: accent,
    );
  }

  static ThemeData _buildTheme(ThemeType type, Color accent) {
    return switch (type) {
      ThemeType.dynamic => DoudouTheme.dark(accent: accent),
      ThemeType.dark => DoudouTheme.dark(accent: accent),
      ThemeType.oled => DoudouTheme.oled(accent: accent),
      ThemeType.light => DoudouTheme.light(accent: accent),
      ThemeType.system => DoudouTheme.dark(accent: accent),
    };
  }

  void setThemeType(ThemeType type, {Brightness? systemBrightness}) {
    final effective = type == ThemeType.system
        ? ((systemBrightness ?? Brightness.dark) == Brightness.light
            ? ThemeType.light
            : ThemeType.dark)
        : type;

    _prefs.put('themeModeType', ThemeType.values.indexOf(type));
    state = AppThemeState(
      theme: _buildTheme(effective, state.accent),
      type: type,
      accent: state.accent,
    );
  }

  void setAccent(Color accent, {bool persist = true, ThemeType? typeOverride}) {
    if (persist) {
      _prefs.put('themePrimaryColor', accent.toARGB32());
      _prefs.put('dynamicColorPrimary', accent.toARGB32());
    }

    final type = typeOverride ?? state.type;
    final effective = type == ThemeType.system ? ThemeType.dark : type;
    state = AppThemeState(
      theme: _buildTheme(effective, accent),
      type: type,
      accent: accent,
    );
  }
}

