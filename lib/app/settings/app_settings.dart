import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.localeCode,
    required this.animationSpeedFactor,
    required this.themeModeType,
  });

  final String localeCode;
  final double animationSpeedFactor;
  final int themeModeType;

  static const supportedLocaleCodes = {'en', 'en_AU', 'zh', 'ru'};

  static AppSettings fromPrefs(Box prefs) {
    final stored = prefs.get('currentAppLanguageCode');
    final rawLocale = stored is String ? stored : 'en';
    final localeCode = supportedLocaleCodes.contains(rawLocale) ? rawLocale : 'en';

    final rawFactor = prefs.get('animationSpeedFactor');
    final animationSpeedFactor = switch (rawFactor) {
      num v => v.toDouble().clamp(0.0, 2.0),
      _ => 1.0,
    };

    final rawThemeModeType = prefs.get('themeModeType');
    final themeModeType = rawThemeModeType is int ? rawThemeModeType : 1;

    return AppSettings(
      localeCode: localeCode,
      animationSpeedFactor: animationSpeedFactor,
      themeModeType: themeModeType,
    );
  }

  Locale get locale {
    if (localeCode == 'en_AU') return const Locale('en', 'AU');
    return Locale(localeCode);
  }
}

