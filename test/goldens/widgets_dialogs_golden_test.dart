import 'dart:io';

import 'package:doudou/models/playlist.dart';
import 'package:doudou/models/server.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/screens/Playlist/playlist_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/add_server_dialog.dart';
import 'package:doudou/ui/screens/Settings/settings_dialogs.dart';
import 'package:doudou/ui/widgets/add_to_playlist.dart';
import 'package:doudou/ui/widgets/additional_operation_dialog.dart';
import 'package:doudou/ui/widgets/backup_dialog.dart';
import 'package:doudou/ui/widgets/create_playlist_dialog.dart';
import 'package:doudou/ui/widgets/dev_merge_request_dialog.dart';
import 'package:doudou/ui/widgets/export_file_dialog.dart';
import 'package:doudou/ui/widgets/link_piped.dart';
import 'package:doudou/ui/widgets/lyrics_dialog.dart';
import 'package:doudou/ui/widgets/mcp_server_dialog.dart';
import 'package:doudou/ui/widgets/modification_list.dart';
import 'package:doudou/ui/widgets/new_version_dialog.dart';
import 'package:doudou/ui/widgets/playlist_export_dialog.dart';
import 'package:doudou/ui/widgets/restore_dialog.dart';
import 'package:doudou/ui/widgets/sleep_timer_bottom_sheet.dart';
import 'package:doudou/ui/widgets/song_info_dialog.dart';
import 'package:doudou/ui/widgets/songinfo_bottom_sheet.dart';
import 'package:doudou/ui/widgets/sort_widget.dart';
import 'package:doudou/ui/widgets/sync_server_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';
import 'golden_fakes.dart';
import 'golden_helpers.dart';

class FakePlaylistScreenController extends PlaylistScreenController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  late Directory hiveDir;
  late GoldenDeps deps;

  final songs = [
    goldenSong('s1', 'Sunset Boulevard'),
    goldenSong('s2', 'Midnight Train'),
  ];

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('doudou_golden_dialogs_');
    Hive.init(hiveDir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox('SongDownloads');
    await Hive.openBox('SongsCache');
    await Hive.openBox('SongsUrlCache');
    await Hive.openBox('LibraryPlaylists');
    await Hive.openBox('LIBFAV');
    await Hive.openBox('LIBRP');
    Directory('/tmp/doudou_golden_support/Music')
        .createSync(recursive: true);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    deps = await installGoldenDeps(
        settings: GoldenSettingsScreenController());
    Get.put<PlaylistScreenController>(FakePlaylistScreenController());
    Get.put<HomeScreenController>(FakeHomeScreenController());
    Get.put<LibraryPlaylistsController>(FakeLibraryPlaylistsController());
    Get.put<LibrarySongsController>(FakeLibrarySongsController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('new version dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: NewVersionDialog(latestVersion: '24.1.0')),
      size: const Size(800, 600),
      settle: false,
    );
    await expectGolden(tester, 'new_version_dialog');
  });

  testWidgets('dev merge request dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(
        child: DevMergeRequestDialog(
          mergeRequestId: '!42',
          mergeRequestUrl: 'https://gitlab.com/Openlyst/doudou/-/merge_requests/42',
        ),
      ),
      size: const Size(700, 500),
    );
    await expectGolden(tester, 'dev_merge_request_dialog');
  });

  testWidgets('mcp server dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: McpServerDialog()),
      size: const Size(700, 500),
    );
    await expectGolden(tester, 'mcp_server_dialog');
  });

  testWidgets('sync server dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: SyncServerDialog()),
      size: const Size(700, 600),
      settle: false,
    );
    await expectGolden(tester, 'sync_server_dialog');
  });

  testWidgets('link piped dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: LinkPiped()),
      size: const Size(700, 600),
      settle: false,
    );
    await expectGolden(tester, 'link_piped_dialog');
  });

  testWidgets('backup dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: BackupDialog()),
      size: const Size(700, 500),
    );
    await expectGolden(tester, 'backup_dialog');
  });

  testWidgets('restore dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: RestoreDialog()),
      size: const Size(700, 500),
    );
    await expectGolden(tester, 'restore_dialog');
  });

  testWidgets('export file dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: ExportFileDialog()),
      size: const Size(700, 500),
      settle: false,
    );
    drainExceptions(tester);
    await expectGolden(tester, 'export_file_dialog');
  });

  testWidgets('create playlist dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: CreateNRenamePlaylistPopup()),
      size: const Size(700, 600),
    );
    await expectGolden(tester, 'create_playlist_dialog');
  });

  testWidgets('add to playlist', (tester) async {
    await pumpGolden(
      tester,
      Center(child: AddToPlaylist(songs)),
      size: const Size(700, 600),
      settle: false,
    );
    await expectGolden(tester, 'add_to_playlist');
  });

  testWidgets('lyrics dialog', (tester) async {
    deps.player.currentSong.value = songs[0];
    await pumpGolden(
      tester,
      const Center(child: LyricsDialog()),
      size: const Size(800, 600),
      settle: false,
    );
    await expectGolden(tester, 'lyrics_dialog');
  });

  testWidgets('song info dialog', (tester) async {
    await pumpGolden(
      tester,
      Center(child: SongInfoDialog(song: songs[0])),
      size: const Size(700, 700),
    );
    await expectGolden(tester, 'song_info_dialog');
  });

  testWidgets('song info bottom sheet', (tester) async {
    await pumpGolden(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: SongInfoBottomSheet(songs[0]),
      ),
      size: const Size(700, 800),
      settle: false,
    );
    await expectGolden(tester, 'songinfo_bottom_sheet');
  });

  testWidgets('sleep timer bottom sheet', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.bottomCenter,
        child: SleepTimerBottomSheet(),
      ),
      size: const Size(700, 600),
    );
    await expectGolden(tester, 'sleep_timer_bottom_sheet');
  });

  testWidgets('playlist export dialog', (tester) async {
    final controller = Get.find<PlaylistScreenController>();
    controller.playlist.value = Playlist(
      title: 'Evening Mix',
      playlistId: 'p1',
      thumbnailUrl: '',
      isCloudPlaylist: false,
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
    await expectGolden(tester, 'playlist_export_dialog');
  });

  testWidgets('additional operation dialog', (tester) async {
    final controller = Get.find<PlaylistScreenController>();
    controller.additionalOperationTempList.assignAll(songs);
    await pumpGolden(
      tester,
      Center(
        child: AdditionalOperationDialog(
          operationMode: OperationMode.delete,
          screenController: controller,
          controller: SortWidgetController(),
        ),
      ),
      size: const Size(800, 700),
    );
    drainExceptions(tester);
    await expectGolden(tester, 'additional_operation_dialog');
  });

  testWidgets('modification list', (tester) async {
    final controller = Get.find<PlaylistScreenController>();
    controller.additionalOperationTempList.assignAll(songs);
    await pumpGolden(
      tester,
      SizedBox(
        height: 500,
        child: Column(
          children: [
            ModificationList(
              mode: OperationMode.arrange,
              screenController: controller,
            ),
          ],
        ),
      ),
      size: const Size(700, 500),
    );
    await expectGolden(tester, 'modification_list');
  });

  testWidgets('add server dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(
        child: AddServerDialog(serverType: ServerType.jellyfin),
      ),
      size: const Size(700, 700),
      settle: false,
    );
    drainExceptions(tester);
    await expectGolden(tester, 'add_server_dialog');
  });

  testWidgets('theme selector dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: ThemeSelectorDialog()),
      size: const Size(600, 500),
    );
    await expectGolden(tester, 'theme_selector_dialog');
  });

  testWidgets('discover content selector dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: DiscoverContentSelectorDialog()),
      size: const Size(600, 500),
    );
    await expectGolden(tester, 'discover_content_selector_dialog');
  });

  testWidgets('add provider dialog', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: AddProviderDialog()),
      size: const Size(700, 600),
      settle: false,
    );
    drainExceptions(tester);
    await expectGolden(tester, 'add_provider_dialog');
  });
}
