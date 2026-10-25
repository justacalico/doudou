import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/album.dart';
import 'package:doudou/ui/screens/Album/album_screen.dart';
import 'package:doudou/ui/screens/Album/album_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import 'golden_fakes.dart';
import 'golden_helpers.dart';

void main() {
  testWidgets('debug album', (tester) async {
    final hiveDir = await Directory.systemTemp.createTemp('doudou_dbg_');
    Hive.init(hiveDir.path);
    for (final name in ['AppPrefs','SongDownloads','SongsCache','SongsUrlCache','LibraryPlaylists','LIBFAV','LIBRP','homeScreenData','searchQuery','p1']) {
      await Hive.openBox(name);
    }
    final deps = await installGoldenDeps(settings: GoldenSettingsScreenController());
    deps.player.initFlagForPlayer = false;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final albumController = FakeAlbumScreenController();
    Get.put<AlbumScreenController>(albumController, tag: null.hashCode.toString());
    albumController.album.value = Album(title:'Golden Hour', browseId:'a1', artists: const [{'name':'Golden Artist'}], year:'2024', thumbnailUrl:'https://img.example.com/a1.jpg');
    albumController.songList.value = [goldenSong('s1','Sunset Boulevard')];
    albumController.isContentFetched.value = true;
    await tester.pumpWidget(GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: goldenTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepaintBoundary(key: goldenRootKey, child: const AlbumScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    debugPrint('fetched=${albumController.isContentFetched.value} songs=${albumController.songList.length}');
    debugPrint('text GoldenHour found: ${find.text('Golden Hour').evaluate().length}');
    debugPrint('song tiles: ${find.byType(ListView).evaluate().length} listviews');
    final e = tester.takeException();
    debugPrint('exception: $e');
    debugDumpApp();
  });
}
