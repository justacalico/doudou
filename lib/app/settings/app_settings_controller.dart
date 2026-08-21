import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'app_settings.dart';

class AppSettingsController extends GetxController {
  late final Box _prefs;
  final settings = const AppSettings(
    localeCode: 'en_AU',
    animationSpeedFactor: 1.0,
    themeModeType: 1,
    perfMonitorEnabled: false,
  ).obs;

  @override
  void onInit() {
    super.onInit();
    _prefs = Hive.box('AppPrefs');
    _reload();
  }

  void _reload() => settings.value = AppSettings.fromPrefs(_prefs);

  void setLocale(String localeCode) {
    if (AppSettings.supportedLocaleCodes.contains(localeCode)) {
      _prefs.put('currentAppLanguageCode', localeCode);
      _reload();
    }
  }

  void setAnimationSpeedFactor(double factor) {
    _prefs.put('animationSpeedFactor', factor.clamp(0.0, 2.0));
    _reload();
  }

  void setThemeModeType(int type) {
    _prefs.put('themeModeType', type);
    _reload();
  }

  void setPerfMonitorEnabled(bool enabled) {
    _prefs.put('perfMonitorEnabled', enabled);
    _reload();
  }
}
