import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'app_settings.dart';

final appPrefsBoxProvider = Provider<Box>((ref) {
  return Hive.box('AppPrefs');
});

final appSettingsProvider = Provider<AppSettings>((ref) {
  final box = ref.watch(appPrefsBoxProvider);
  return AppSettings.fromPrefs(box);
});

