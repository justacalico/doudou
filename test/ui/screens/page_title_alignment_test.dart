import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/library_sync_service.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/ui/constants/layout.dart';
import 'package:doudou/ui/screens/Library/library.dart';
import 'package:doudou/ui/screens/Library/library_browse_screen.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/screens/Search/search_screen.dart';
import 'package:doudou/ui/screens/Search/search_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/ui/utils/theme_controller.dart';
import 'package:doudou/utils/server_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

void _ensureLibraryControllers() {
  // Controllers read AppLocalizations via Get.context on init, so they can
  // only be registered once the app is pumped.
  if (!Get.isRegistered<LibrarySongsController>()) {
    Get.put(LibrarySongsController());
    Get.put(LibraryAlbumsController());
    Get.put(LibraryArtistsController());
    Get.put(LibraryPlaylistsController());
  }
}

Widget _wrap(Widget child) {
  return GetMaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        _ensureLibraryControllers();
        return Scaffold(body: child);
      },
    ),
  );
}

void _expectTitleStyle(WidgetTester tester, String title) {
  final widget = tester.widget<Text>(find.text(title));
  expect(widget.style?.fontSize, 24, reason: '$title should use the shared page title size');
  expect(
    widget.style?.fontWeight,
    FontWeight.bold,
    reason: '$title should use the shared page title weight',
  );
}

void main() {
  late Directory dir;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('page_title_alignment_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox(songDownloadsBoxName(0));
    // SearchScreenController opens this lazily in onInit; opening it here
    // keeps the async work from outliving the test.
    await Hive.openBox(searchQueryBoxName(0));
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    Get.put<LibrarySyncService>(FakeLibrarySyncService());
    Get.put(ShellController());
    Get.put(ThemeController());
    Get.put(SearchScreenController());
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets(
      'search, library and settings titles share the same top-left placement',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const SearchScreen()));
    await tester.pumpAndSettle();
    final searchOrigin = tester.getTopLeft(find.text('Search'));
    _expectTitleStyle(tester, 'Search');

    await tester.pumpWidget(_wrap(const LibraryBrowseScreen()));
    await tester.pumpAndSettle();
    final libraryOrigin = tester.getTopLeft(find.text('Library'));
    _expectTitleStyle(tester, 'Library');

    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();
    final settingsOrigin = tester.getTopLeft(find.text('Settings'));
    _expectTitleStyle(tester, 'Settings');

    for (final entry in {
      'Search': searchOrigin,
      'Library': libraryOrigin,
      'Settings': settingsOrigin,
    }.entries) {
      expect(
        entry.value.dy,
        closeTo(kPageTitleTopSpacing, 0.5),
        reason: '${entry.key} title should sit at the shared top spacing',
      );
      expect(
        entry.value.dx,
        lessThan(40),
        reason: '${entry.key} title should be anchored to the left edge',
      );
    }

    expect(
      libraryOrigin.dx,
      closeTo(searchOrigin.dx, 0.5),
      reason: 'library title should align with the search title',
    );
  });

  testWidgets('library section pages place their titles at the top-left',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cases = <(Widget, String)>[
      (const SongsLibraryWidget(), 'Library Songs'),
      (const PlaylistNAlbumLibraryWidget(isAlbumContent: true), 'Library Albums'),
      (const PlaylistNAlbumLibraryWidget(isAlbumContent: false),
          'Library Playlists'),
      (const LibraryArtistWidget(), 'Library Artists'),
      (const DownloadsLibraryWidget(), 'Downloads'),
    ];

    for (final (widget, title) in cases) {
      await tester.pumpWidget(_wrap(widget));
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.text(title));
      expect(
        origin.dy,
        closeTo(kPageTitleTopSpacing, 0.5),
        reason: '$title should sit at the shared top spacing',
      );
      expect(
        origin.dx,
        lessThan(40),
        reason: '$title should be anchored to the left edge',
      );
      _expectTitleStyle(tester, title);
    }
  });
}
