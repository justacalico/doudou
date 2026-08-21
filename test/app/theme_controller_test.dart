import 'dart:io';

import 'package:doudou/ui/utils/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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
    Get.reset();
  });

  test('initializes from Hive and can persist accent', () {
    box.put('themePrimaryColor', const Color(0xFF112233).toARGB32());
    final controller = Get.put(ThemeController());

    expect(controller.primaryColor.value, const Color(0xFF112233));

    controller.setNowPlayingAccent(const Color(0xFF334455));
    expect(controller.primaryColor.value, const Color(0xFF334455));
    expect(controller.dynamicColor.value, const Color(0xFF334455));
    expect(box.get('themePrimaryColor'), const Color(0xFF334455).toARGB32());
    expect(box.get('dynamicColorPrimary'), const Color(0xFF334455).toARGB32());
  });
}
