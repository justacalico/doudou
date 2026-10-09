import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/server.dart';
import 'package:doudou/services/library_sync_service.dart';
import 'package:doudou/services/mcp_server_service.dart';
import 'package:doudou/services/server_sync_service.dart';
import 'package:doudou/ui/screens/Settings/settings_screen.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/utils/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';
import '../../services/mcp_server_service_test.dart' show FakeMcpAppBridge;

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
    dir = await Directory.systemTemp.createTemp('settings_misc_mcp_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
    // A non-YouTube active server keeps the servers view's resync Obx
    // reading an observable, which GetX requires.
    Get.put<SettingsScreenController>(
        FakeSettingsScreenController()..serverType = ServerType.jellyfin);
    Get.put<LibrarySyncService>(FakeLibrarySyncService());
    Get.put<ServerSyncService>(ServerSyncService());
    // supported:false keeps onInit from starting a real socket; the tile is
    // still rendered because it is gated on the desktop platform check.
    Get.put<McpServerService>(McpServerService(
      bridge: FakeMcpAppBridge(),
      supported: false,
    ));
    Get.put(ThemeController());
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('MCP server option lives under Misc, not Servers',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Misc'));
    await tester.pumpAndSettle();
    expect(find.text('MCP server'), findsOneWidget);

    await tester.tap(find.text('Servers'));
    await tester.pumpAndSettle();
    expect(find.text('MCP server'), findsNothing);
  });
}
