import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/library_sync_service.dart';
import 'package:doudou/ui/constants/layout.dart';
import 'package:doudou/ui/screens/Settings/settings_screen.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/utils/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  late Directory dir;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings_header_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    Get.put<LibrarySyncService>(FakeLibrarySyncService());
    Get.put(ThemeController());
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets(
      'two-pane settings header sits at the top like other pages',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    final header = find.text('Settings');
    expect(header, findsOneWidget);

    final titleTop = tester.getTopLeft(header).dy;
    // Pages place their title at kPageTitleTopSpacing below the status bar;
    // the settings title used to start more than twice as low.
    expect(
      titleTop,
      lessThan(kPageTitleTopSpacing + 30),
      reason: 'header should start near the top edge',
    );
    expect(find.text('Personalisation'), findsWidgets);
  });

  testWidgets('single-pane settings header is also near the top',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    final titleTop = tester.getTopLeft(find.text('Settings')).dy;
    expect(titleTop, lessThan(kPageTitleTopSpacing + 30));
  });
}
