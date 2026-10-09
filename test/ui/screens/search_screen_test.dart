import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/screens/Search/search_screen.dart';
import 'package:doudou/ui/screens/Search/search_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('search_screen_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    Get.put(ShellController());
    Get.put(SearchScreenController());
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        locale: Locale('en', 'AU'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('title has no purple accent dot', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Search'), findsWidgets);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == kDoudouPurple;
      }),
      findsNothing,
    );
  });
}
