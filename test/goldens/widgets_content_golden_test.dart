import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/models/quick_picks.dart';
import 'package:doudou/ui/screens/Search/search_result_screen_controller.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/widgets/adaptive_tab_screen.dart';
import 'package:doudou/ui/widgets/content_list_widget.dart';
import 'package:doudou/ui/widgets/content_list_widget_item.dart';
import 'package:doudou/ui/widgets/image_widget.dart';
import 'package:doudou/ui/widgets/list_widget.dart';
import 'package:doudou/ui/widgets/quickpickswidget.dart';
import 'package:doudou/ui/widgets/separate_tab_item_widget.dart';
import 'package:doudou/ui/widgets/snackbar.dart';
import 'package:doudou/ui/widgets/song_list_tile.dart';
import 'package:doudou/ui/widgets/sort_widget.dart';
import 'package:doudou/ui/widgets/animated_screen_transition.dart';
import 'package:doudou/ui/widgets/shimmer_widgets/basic_container.dart';
import 'package:doudou/ui/widgets/shimmer_widgets/home_shimmer.dart';
import 'package:doudou/ui/widgets/shimmer_widgets/song_list_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';
import 'golden_fakes.dart';
import 'golden_helpers.dart';

void main() {
  late Directory hiveDir;

  final albums = [
    Album(
        title: 'Golden Hour',
        browseId: 'a1',
        artists: const [
          {'name': 'Golden Artist'}
        ],
        year: '2024',
        thumbnailUrl: 'https://img.example.com/a1.jpg'),
    Album(
        title: 'Night Drive',
        browseId: 'a2',
        artists: const [
          {'name': 'Another Artist'}
        ],
        year: '2023',
        thumbnailUrl: 'https://img.example.com/a2.jpg'),
  ];

  final playlists = [
    Playlist(
        title: 'Evening Mix',
        playlistId: 'p1',
        thumbnailUrl: 'https://img.example.com/p1.jpg',
        songCount: '24'),
    Playlist(
        title: 'Workout',
        playlistId: 'p2',
        thumbnailUrl: 'https://img.example.com/p2.jpg',
        songCount: '51'),
  ];

  final songs = [
    goldenSong('s1', 'Sunset Boulevard'),
    goldenSong('s2', 'Midnight Train'),
    goldenSong('s3', 'Northern Lights'),
  ];

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('doudou_golden_content_');
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
    await installGoldenDeps();
    Get.put<LibraryPlaylistsController>(
        FakeLibraryPlaylistsController(playlists));
    Get.put<LibrarySongsController>(FakeLibrarySongsController());
    Get.put<LibraryAlbumsController>(FakeLibraryAlbumsController());
    Get.put<LibraryArtistsController>(FakeLibraryArtistsController());
    Get.put<SearchResultScreenController>(
        FakeSearchResultScreenController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('image widget for song', (tester) async {
    await pumpGolden(
      tester,
      Center(child: ImageWidget(song: songs[0], size: 160)),
      size: const Size(300, 300),
      settle: false,
    );
    await expectGolden(tester, 'image_widget_song');
  });

  testWidgets('image widget for album and playlist', (tester) async {
    await pumpGolden(
      tester,
      Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ImageWidget(album: albums[0], size: 140),
            const SizedBox(width: 24),
            ImageWidget(playlist: playlists[0], size: 140),
          ],
        ),
      ),
      size: const Size(400, 240),
      settle: false,
    );
    await expectGolden(tester, 'image_widget_album_playlist');
  });

  testWidgets('song list tile', (tester) async {
    await pumpGolden(
      tester,
      ListView(
        children: [
          SongListTile(song: songs[0], onTap: () {}),
          SongListTile(song: songs[1], onTap: () {}),
          SongListTile(
            song: songs[2],
            isPlaylistOrAlbum: true,
            thumbReplacementWithIndex: true,
            index: 2,
            onTap: () {},
          ),
        ],
      ),
      size: const Size(700, 320),
    );
    await expectGolden(tester, 'song_list_tile');
  });

  testWidgets('list widget with songs', (tester) async {
    await pumpGolden(
      tester,
      Column(
        children: [
          ListWidget(songs, 'Top songs', true),
        ],
      ),
      size: const Size(700, 500),
    );
    await expectGolden(tester, 'list_widget');
  });

  testWidgets('separate tab item widget', (tester) async {
    await pumpGolden(
      tester,
      ListView(
        children: [
          SeparateTabItemWidget(
            items: songs,
            title: 'Songs',
            isCompleteList: false,
            searchResultController:
                Get.find<SearchResultScreenController>(),
          ),
        ],
      ),
      size: const Size(700, 500),
    );
    await expectGolden(tester, 'separate_tab_item_widget');
  });

  testWidgets('content list item album', (tester) async {
    await pumpGolden(
      tester,
      Center(
        child: SizedBox(
          width: 180,
          child: ContentListItem(content: albums[0]),
        ),
      ),
      size: const Size(300, 320),
      settle: false,
    );
    await expectGolden(tester, 'content_list_item_album');
  });

  testWidgets('content list widget albums', (tester) async {
    await pumpGolden(
      tester,
      ContentListWidget(
        content: AlbumContent(title: 'New albums', albumList: albums),
      ),
      size: const Size(800, 340),
      settle: false,
    );
    await expectGolden(tester, 'content_list_widget_albums');
  });

  testWidgets('content list widget playlists', (tester) async {
    await pumpGolden(
      tester,
      ContentListWidget(
        content:
            PlaylistContent(title: 'Made for you', playlistList: playlists),
      ),
      size: const Size(800, 340),
      settle: false,
    );
    await expectGolden(tester, 'content_list_widget_playlists');
  });

  testWidgets('quick picks widget', (tester) async {
    await pumpGolden(
      tester,
      QuickPicksWidget(content: QuickPicks(songs, title: 'Quick picks')),
      size: const Size(800, 400),
      settle: false,
    );
    await expectGolden(tester, 'quick_picks_widget');
  });

  testWidgets('sort widget', (tester) async {
    await pumpGolden(
      tester,
      Column(
        children: [
          SortWidget(
            tag: 'golden_sort',
            itemCountTitle: '3 songs',
            screenController: Get.find<LibrarySongsController>(),
            requiredSortTypes: const {
              SortType.Name,
              SortType.Date,
              SortType.Duration
            },
            onSort: (_, __) {},
          ),
        ],
      ),
      size: const Size(800, 120),
    );
    await expectGolden(tester, 'sort_widget');
  });

  testWidgets('snackbar', (tester) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goldenTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => ScaffoldMessenger.of(context)
                    .showSnackBar(snackbar(context, 'Added to playlist')),
                child: const Text('Show snackbar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectGoldenView(tester, 'snackbar');
  });

  testWidgets('adaptive tab screen narrow', (tester) async {
    await pumpGolden(
      tester,
      const AdaptiveTabScreen(
        narrowChild: Center(child: Text('Narrow layout')),
        wideChild: Center(child: Text('Wide layout')),
      ),
      size: const Size(500, 400),
    );
    await expectGolden(tester, 'adaptive_tab_screen_narrow');
  });

  testWidgets('animated screen transition', (tester) async {
    await pumpGolden(
      tester,
      const AnimatedScreenTransition(
        enabled: false,
        child: Center(child: Text('Transition content')),
      ),
      size: const Size(500, 300),
    );
    await expectGolden(tester, 'animated_screen_transition');
  });

  testWidgets('shimmer widgets', (tester) async {
    await pumpGolden(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: BasicShimmerContainer(Size(120, 120)),
            ),
            const SizedBox(height: 820, child: HomeShimmer()),
            const SizedBox(height: 300, child: SongListShimmer()),
          ],
        ),
      ),
      size: const Size(900, 1400),
      settle: false,
    );
    await expectGolden(tester, 'shimmer_widgets');
  });
}
