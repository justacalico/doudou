import 'dart:io';

import 'package:doudou/models/playlist.dart';
import 'package:doudou/models/server.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/screens/Playlist/playlist_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_dialogs.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/widgets/add_to_playlist.dart';
import 'package:doudou/ui/widgets/common_dialog_widget.dart';
import 'package:doudou/ui/widgets/playlist_export_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';
import '../../goldens/golden_fakes.dart';
import '../../goldens/golden_helpers.dart';

bool _isOpaqueFill(Widget widget) {
  if (widget is Container && widget.decoration is BoxDecoration) {
    final color = (widget.decoration! as BoxDecoration).color;
    return color != null && color.a >= 1.0 - 1e-6;
  }
  return false;
}

void main() {
  late Directory hiveDir;

  final songs = [
    goldenSong('s1', 'Sunset Boulevard'),
    goldenSong('s2', 'Midnight Train'),
  ];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    hiveDir = await Directory.systemTemp.createTemp('doudou_dialog_surface_');
    Hive.init(hiveDir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox('SongDownloads');
    await Hive.openBox('SongsCache');
    await Hive.openBox('SongsUrlCache');
    await Hive.openBox('LibraryPlaylists');
    await Hive.openBox('LIBFAV');
    await Hive.openBox('LIBRP');
    Directory('/tmp/doudou_dialog_surface_support/Music')
        .createSync(recursive: true);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await installGoldenDeps(
        settings: FakeSettingsScreenController()
          ..serverType = ServerType.subsonic);
    Get.put<PlaylistScreenController>(FakePlaylistScreenController());
    Get.put<HomeScreenController>(FakeHomeScreenController());
    Get.put<LibraryPlaylistsController>(FakeLibraryPlaylistsController([
      Playlist(title: 'Rap', playlistId: 'p1', thumbnailUrl: ''),
    ]));
    Get.put<LibrarySongsController>(FakeLibrarySongsController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('add to playlist list stays translucent', (tester) async {
    await pumpGolden(
      tester,
      Center(child: AddToPlaylist(songs)),
      size: const Size(700, 600),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ListView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AddToPlaylist),
        matching: find.byWidgetPredicate(_isOpaqueFill),
      ),
      findsNothing,
    );
  });

  testWidgets('theme selector options stay translucent', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: ThemeSelectorDialog()),
      size: const Size(600, 500),
    );

    final materials = tester
        .widgetList<Material>(find.descendant(
          of: find.byType(CommonDialog),
          matching: find.byType(Material),
        ))
        .toList();
    expect(materials, isNotEmpty);
    for (final material in materials) {
      expect(
        material.type == MaterialType.transparency ||
            material.color == null ||
            material.color!.a < 1.0,
        isTrue,
        reason: 'selector content must not repaint the modal surface',
      );
    }
  });

  testWidgets('playlist export options stay translucent', (tester) async {
    Get.replace<SettingsScreenController>(FakeSettingsScreenController());
    final controller = Get.find<PlaylistScreenController>();
    controller.playlist.value = Playlist(
      title: 'Evening Mix',
      playlistId: 'p1',
      thumbnailUrl: '',
    );
    controller.songList.assignAll(songs);
    await pumpGolden(
      tester,
      Builder(
        builder: (parentContext) => Center(
          child: PlaylistExportDialog(
            controller: controller,
            parentContext: parentContext,
          ),
        ),
      ),
      size: const Size(700, 600),
    );

    final materials = tester
        .widgetList<Material>(find.descendant(
          of: find.byType(PlaylistExportDialog),
          matching: find.byType(Material),
        ))
        .toList();
    expect(materials.length, greaterThanOrEqualTo(3));
    for (final material in materials) {
      expect(
        material.type == MaterialType.transparency ||
            material.color == null ||
            material.color!.a < 1.0,
        isTrue,
        reason: 'export option buttons must not repaint the modal surface',
      );
    }
  });
}
