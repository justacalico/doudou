import 'dart:io';

import 'package:doudou/app/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box box;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_test_');
    Hive.init(dir.path);
    box = await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await box.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    await box.clear();
  });

  test('defaults to en locale and factor 1.0', () {
    final s = AppSettings.fromPrefs(box);
    expect(s.localeCode, 'en_AU');
    expect(s.locale.languageCode, 'en');
    expect(s.locale.countryCode, 'AU');
    expect(s.animationSpeedFactor, 1.0);
  });

  test('clamps animationSpeedFactor and validates locale', () async {
    await box.put('animationSpeedFactor', 99);
    await box.put('currentAppLanguageCode', 'en_AU');
    final s = AppSettings.fromPrefs(box);
    expect(s.localeCode, 'en_AU');
    expect(s.locale.languageCode, 'en');
    expect(s.locale.countryCode, 'AU');
    expect(s.animationSpeedFactor, 2.0);

    await box.put('currentAppLanguageCode', 'xx');
    final s2 = AppSettings.fromPrefs(box);
    expect(s2.localeCode, 'en_AU');
  });
}

