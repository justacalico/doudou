import 'dart:io';

import 'package:doudou/app/theme/app_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Box box;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    dir = await Directory.systemTemp.createTemp('doudou_theme_test_');
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

  test('initializes from Hive and can persist accent', () {
    box.put('themePrimaryColor', const Color(0xFF112233).toARGB32());
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final st = container.read(appThemeProvider);
    expect(st.accent, const Color(0xFF112233));

    container.read(appThemeProvider.notifier).setAccent(const Color(0xFF334455));
    final st2 = container.read(appThemeProvider);
    expect(st2.accent, const Color(0xFF334455));
    expect(box.get('themePrimaryColor'), const Color(0xFF334455).toARGB32());
  });
}

