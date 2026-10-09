import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/library_sync_service.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/screens/Library/library_browse_screen.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/utils/server_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library_browse_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox(songDownloadsBoxName(0));
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    Get.put<LibrarySyncService>(FakeLibrarySyncService());
    Get.put(ShellController());
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            // Controllers read AppLocalizations via Get.context on init, so
            // they can only be registered once the app is pumped.
            if (!Get.isRegistered<LibrarySongsController>()) {
              Get.put(LibrarySongsController());
              Get.put(LibraryAlbumsController());
              Get.put(LibraryArtistsController());
              Get.put(LibraryPlaylistsController());
            }
            return const Scaffold(body: LibraryBrowseScreen());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('header subtitle shows only the overview label', (tester) async {
    await pumpScreen(tester, const Locale('en', 'AU'));

    expect(find.text('Overview'), findsOneWidget);
    expect(find.textContaining('Your music collection'), findsNothing);
  });

  testWidgets('header subtitle has no collection suffix in zh', (tester) async {
    await pumpScreen(tester, const Locale('zh'));
    expect(find.text('概览'), findsOneWidget);
  });

  testWidgets('header subtitle has no collection suffix in ru', (tester) async {
    await pumpScreen(tester, const Locale('ru'));
    expect(find.text('Обзор'), findsOneWidget);
  });

  testWidgets('header title has no purple accent dot', (tester) async {
    await pumpScreen(tester, const Locale('en', 'AU'));

    expect(find.text('Library'), findsOneWidget);
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
