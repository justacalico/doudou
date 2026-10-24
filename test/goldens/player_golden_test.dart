import 'dart:io';

import 'package:doudou/ui/player/components/albumart_lyrics.dart';
import 'package:doudou/ui/player/components/animated_play_button.dart';
import 'package:doudou/ui/player/components/background_image.dart';
import 'package:doudou/ui/player/components/lyrics_bottom_sheet.dart';
import 'package:doudou/ui/player/components/lyrics_switch.dart';
import 'package:doudou/ui/player/components/lyrics_widget.dart';
import 'package:doudou/ui/player/components/mini_player.dart';
import 'package:doudou/ui/player/components/now_playing_play_button.dart';
import 'package:doudou/ui/player/components/player_control.dart';
import 'package:doudou/ui/player/components/player_mobile_bottom_bar.dart';
import 'package:doudou/ui/player/components/standard_player.dart';
import 'package:doudou/ui/player/player.dart' as doudou_player;
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/widgets/animated_side_bar_local.dart';
import 'package:doudou/ui/widgets/bottom_nav_bar.dart';
import 'package:doudou/ui/widgets/now_playing_side_panel.dart';
import 'package:doudou/ui/widgets/piped_sync_widget.dart';
import 'package:doudou/ui/widgets/playlist_album_scroll_behaviour.dart';
import 'package:doudou/ui/widgets/queue_drawer.dart';
import 'package:doudou/ui/widgets/side_nav_bar.dart';
import 'package:doudou/ui/widgets/sliding_up_panel.dart';
import 'package:doudou/ui/widgets/song_download_btn.dart';
import 'package:doudou/ui/widgets/up_next_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'golden_fakes.dart';
import 'golden_helpers.dart';

void main() {
  late Directory hiveDir;
  late GoldenDeps deps;

  final songs = [
    goldenSong('s1', 'Sunset Boulevard'),
    goldenSong('s2', 'Midnight Train'),
    goldenSong('s3', 'Northern Lights'),
  ];

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('doudou_golden_player_');
    Hive.init(hiveDir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox('SongDownloads');
    await Hive.openBox('LibraryPlaylists');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    deps = await installGoldenDeps(
        settings: GoldenSettingsScreenController());
    deps.player.initFlagForPlayer = false;
    deps.player.currentQueue.assignAll(songs);
    deps.player.currentSong.value = songs[0];
    deps.player.playerPanelMinHeight.value = 110;
    Get.put<HomeScreenController>(FakeHomeScreenController());
    Get.put<LibraryPlaylistsController>(FakeLibraryPlaylistsController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('mini player', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.bottomCenter,
        child: MiniPlayer(),
      ),
      size: const Size(1400, 200),
      settle: false,
    );
    await expectGolden(tester, 'mini_player');
  });

  testWidgets('animated play button', (tester) async {
    await pumpGolden(
      tester,
      const Center(
        child: CircleAvatar(
          radius: 35,
          child: AnimatedPlayButton(),
        ),
      ),
      size: const Size(200, 200),
    );
    await expectGolden(tester, 'animated_play_button');
  });

  testWidgets('background image', (tester) async {
    await pumpGolden(
      tester,
      const BackgroundImage(),
      useScaffold: false,
      size: const Size(800, 500),
      settle: false,
    );
    await expectGolden(tester, 'background_image');
  });

  testWidgets('player control', (tester) async {
    await pumpGolden(
      tester,
      const PlayerControlWidget(),
      size: const Size(900, 500),
      settle: false,
    );
    await expectGolden(tester, 'player_control');
  });

  testWidgets('lyrics switch', (tester) async {
    await pumpGolden(
      tester,
      const Center(child: LyricsSwitch()),
      size: const Size(500, 120),
    );
    await expectGolden(tester, 'lyrics_switch');
  });

  testWidgets('lyrics widget', (tester) async {
    await pumpGolden(
      tester,
      const LyricsWidget(padding: EdgeInsets.all(16)),
      size: const Size(700, 500),
      settle: false,
    );
    await expectGolden(tester, 'lyrics_widget');
  });

  testWidgets('lyrics bottom sheet', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.bottomCenter,
        child: LyricsBottomSheet(),
      ),
      size: const Size(700, 700),
      settle: false,
    );
    await expectGolden(tester, 'lyrics_bottom_sheet');
  });

  testWidgets('now playing play button', (tester) async {
    await pumpGolden(
      tester,
      Center(
        child: NowPlayingPlayButton(
          controller: Get.find<PlayerController>(),
          size: 64,
          iconSize: 30,
          backgroundColor: goldenAccent,
          iconColor: Colors.white,
        ),
      ),
      size: const Size(200, 200),
      settle: false,
    );
    await expectGolden(tester, 'now_playing_play_button');
  });

  testWidgets('player mobile bottom bar', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.bottomCenter,
        child: PlayerMobileBottomBar(),
      ),
      size: const Size(420, 300),
      settle: false,
    );
    await expectGolden(tester, 'player_mobile_bottom_bar');
  });

  testWidgets('standard player', (tester) async {
    await pumpGolden(
      tester,
      const StandardPlayer(),
      size: const Size(1400, 800),
      settle: false,
    );
    await expectGolden(tester, 'standard_player');
  });

  testWidgets('album art and lyrics', (tester) async {
    await pumpGolden(
      tester,
      const AlbumArtNLyrics(playerArtImageSize: 300),
      size: const Size(800, 600),
      settle: false,
    );
    await expectGolden(tester, 'album_art_lyrics');
  });

  testWidgets('player screen', (tester) async {
    await pumpGolden(
      tester,
      const doudou_player.Player(),
      size: const Size(800, 600),
      settle: false,
    );
    await expectGolden(tester, 'player_screen');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('bottom nav bar', (tester) async {
    await pumpGolden(
      tester,
      const BottomNavBar(),
      size: const Size(800, 600),
      settle: false,
    );
    await expectGolden(tester, 'bottom_nav_bar');
  });

  testWidgets('side nav bar', (tester) async {
    await pumpGolden(
      tester,
      Row(
        children: [
          SizedBox(
            width: 280,
            child: SideNavBar(minimized: false, onMinimizeChanged: (_) {}),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
      size: const Size(1000, 800),
      settle: false,
    );
    await expectGolden(tester, 'side_nav_bar');
  });

  testWidgets('side nav bar minimized', (tester) async {
    await pumpGolden(
      tester,
      Row(
        children: [
          SizedBox(
            width: 90,
            child: SideNavBar(minimized: true, onMinimizeChanged: (_) {}),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
      size: const Size(900, 800),
      settle: false,
    );
    await expectGolden(tester, 'side_nav_bar_minimized');
  });

  testWidgets('now playing side panel', (tester) async {
    await pumpGolden(
      tester,
      const NowPlayingSidePanel(),
      size: const Size(1400, 800),
      settle: false,
    );
    await expectGolden(tester, 'now_playing_side_panel');
  });

  testWidgets('queue drawer', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.centerRight,
        child: QueueDrawer(),
      ),
      size: const Size(1000, 700),
      settle: false,
    );
    await expectGolden(tester, 'queue_drawer');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('up next queue', (tester) async {
    await pumpGolden(
      tester,
      const UpNextQueue(),
      size: const Size(500, 700),
      settle: false,
    );
    await expectGolden(tester, 'up_next_queue');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('song download button', (tester) async {
    await pumpGolden(
      tester,
      Center(child: SongDownloadButton(song_: songs[0])),
      size: const Size(200, 120),
      settle: false,
    );
    await expectGolden(tester, 'song_download_button');
  });

  testWidgets('piped sync widget', (tester) async {
    await pumpGolden(
      tester,
      const Align(
        alignment: Alignment.topRight,
        child: PipedSyncWidget(padding: EdgeInsets.all(8)),
      ),
      size: const Size(400, 120),
    );
    await expectGolden(tester, 'piped_sync_widget');
  });

  testWidgets('animated side bar local', (tester) async {
    await pumpGolden(
      tester,
      Row(
        children: [
          SideBarAnimatedLocal(
            mainLogoImage: 'assets/icons/icon.png',
            appName: 'doudou',
            sidebarItems: const [
              SideBarItemLocal(
                  iconSelected: Icons.home, text: 'Home'),
              SideBarItemLocal(
                  iconSelected: Icons.search, text: 'Search'),
              SideBarItemLocal(
                  iconSelected: Icons.library_music,
                  text: 'Library'),
            ],
            widthSwitch: 700,
            onTap: (_) {},
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
      size: const Size(900, 800),
    );
    await expectGolden(tester, 'animated_side_bar_local');
  });

  testWidgets('playlist album scroll behaviour', (tester) async {
    await pumpGolden(
      tester,
      ScrollConfiguration(
        behavior: PlaylistAlbumScrollBehaviour(),
        child: ListView(
          children: List.generate(
            20,
            (i) => ListTile(title: Text('Row $i')),
          ),
        ),
      ),
      size: const Size(500, 500),
    );
    await expectGolden(tester, 'playlist_album_scroll_behaviour');
  });

  testWidgets('sliding up panel', (tester) async {
    await pumpGolden(
      tester,
      SlidingUpPanel(
        minHeight: 90,
        maxHeight: 400,
        defaultPanelState: PanelState.OPEN,
        body: Container(
          color: const Color(0xFF101014),
          child: const Center(child: Text('Main content')),
        ),
        panel: Container(
          color: const Color(0xFF20202A),
          child: const Center(child: Text('Player panel')),
        ),
      ),
      useScaffold: false,
      size: const Size(800, 600),
      settle: false,
    );
    await expectGolden(tester, 'sliding_up_panel');
  });
}
