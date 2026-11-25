import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/widgets/side_nav_bar.dart';
import 'package:doudou/ui/widgets/window_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../goldens/golden_fakes.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    hiveDir = await Directory.systemTemp.createTemp('side_nav_bar_test_');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    WindowControls.debugIsHyprland = false;
    WindowControls.debugIsKde = false;
    await installGoldenDeps();
    Get.put<HomeScreenController>(FakeHomeScreenController());
  });

  tearDown(() {
    WindowControls.debugIsHyprland = null;
    WindowControls.debugIsKde = null;
    Get.reset();
  });

  Future<void> pumpSidebar(WidgetTester tester, {required bool minimized}) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'AU'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: minimized ? 84 : 260,
            child: SideNavBar(
              minimized: minimized,
              onMinimizeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('minimized sidebar stacks all window controls without overflow',
      (tester) async {
    await pumpSidebar(tester, minimized: true);

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byIcon(Icons.minimize), findsOneWidget);

    final flex = tester.widget<Flex>(
      find.descendant(
        of: find.byType(WindowControls),
        matching: find.byType(Flex),
      ),
    );
    expect(flex.direction, Axis.vertical);

    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded sidebar keeps window controls in a row',
      (tester) async {
    await pumpSidebar(tester, minimized: false);

    final flex = tester.widget<Flex>(
      find.descendant(
        of: find.byType(WindowControls),
        matching: find.byType(Flex),
      ),
    );
    expect(flex.direction, Axis.horizontal);

    expect(tester.takeException(), isNull);
  });
}
