import 'dart:io';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/ui/screens/Album/album_screen.dart';
import 'package:doudou/ui/screens/Album/album_screen_controller.dart';
import 'package:doudou/ui/screens/Artists/artist_screen.dart';
import 'package:doudou/ui/screens/Artists/artist_screen_controller.dart';
import 'package:doudou/ui/screens/Home/home_screen.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Library/library.dart';
import 'package:doudou/ui/screens/Library/library_browse_screen.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/screens/Playlist/playlist_screen.dart';
import 'package:doudou/ui/screens/Playlist/playlist_screen_controller.dart';
import 'package:doudou/ui/screens/Search/search_result_screen.dart';
import 'package:doudou/ui/screens/Search/search_result_screen_controller.dart';
import 'package:doudou/ui/screens/Search/search_screen.dart';
import 'package:doudou/ui/screens/Search/search_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen.dart';
import 'package:doudou/ui/screens/tv_lyrics_screen.dart';
import 'package:doudou/ui/screens/tv_now_playing_screen.dart';
import 'package:doudou/ui/screens/tv_queue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';
import 'package:doudou/ui/widgets/song_list_tile.dart';
import 'golden_fakes.dart';
import 'golden_helpers.dart';

void main() {
  late Directory hiveDir;
  late GoldenDeps deps;
  late FakeHomeScreenController homeController;
  late FakeLibraryPlaylistsController playlistsController;
  late FakeLibrarySongsController songsController;
  late FakeLibraryAlbumsController albumsController;
  late FakeLibraryArtistsController artistsController;

  final songs = [
    goldenSong('s1', 'Sunset Boulevard'),
    goldenSong('s2', 'Midnight Train'),
    goldenSong('s3', 'Northern Lights'),
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

  final albums = [
    Album(
        title: 'Golden Hour',
        browseId: 'a1',
        artists: const [
          {'name': 'Golden Artist'}
        ],
        year: '2024',
        thumbnailUrl: 'https://img.example.com/a1.jpg'),
  ];

  final artists = [
    Artist(
        name: 'Golden Artist',
        browseId: 'ar1',
        thumbnailUrl: 'https://img.example.com/ar1.jpg',
        subscribers: '1.2M'),
  ];

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('doudou_golden_screens_');
    Hive.init(hiveDir.path);
    for (final name in [
      'AppPrefs',
      'SongDownloads',
      'SongsCache',
      'SongsUrlCache',
      'LibraryPlaylists',
      'LIBFAV',
      'LIBRP',
      'homeScreenData',
      'searchQuery',
      'p1',
    ]) {
      await Hive.openBox(name);
    }
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

    homeController = FakeHomeScreenController();
    Get.put<HomeScreenController>(homeController);
    playlistsController = FakeLibraryPlaylistsController(playlists);
    Get.put<LibraryPlaylistsController>(playlistsController);
    songsController = FakeLibrarySongsController();
    songsController.librarySongsList = RxList(songs);
    songsController.isSongFetched.value = true;
    Get.put<LibrarySongsController>(songsController);
    albumsController = FakeLibraryAlbumsController();
    albumsController.libraryAlbums = RxList(albums);
    albumsController.isContentFetched.value = true;
    Get.put<LibraryAlbumsController>(albumsController);
    artistsController = FakeLibraryArtistsController();
    artistsController.libraryArtists = RxList(artists);
    artistsController.isContentFetched.value = true;
    Get.put<LibraryArtistsController>(artistsController);
    Get.put<SearchScreenController>(FakeSearchScreenController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('home screen', (tester) async {
    homeController.isContentFetched.value = true;
    await pumpGolden(
      tester,
      const HomeScreen(),
      useScaffold: false,
      size: const Size(1400, 900),
      settle: false,
    );
    await expectGolden(tester, 'screen_home');
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('search screen', (tester) async {
    await pumpGolden(
      tester,
      const SearchScreen(),
      size: const Size(1200, 800),
      settle: false,
    );
    await expectGolden(tester, 'screen_search');
  });

  testWidgets('library browse screen', (tester) async {
    await pumpGolden(
      tester,
      const LibraryBrowseScreen(),
      size: const Size(1400, 900),
      settle: false,
    );
    await expectGolden(tester, 'screen_library_browse');
  });

  testWidgets('songs library widget', (tester) async {
    await pumpGolden(
      tester,
      const SongsLibraryWidget(),
      size: const Size(1000, 700),
      settle: false,
    );
    await expectGolden(tester, 'screen_songs_library');
  });

  testWidgets('playlists library widget', (tester) async {
    await pumpGolden(
      tester,
      const PlaylistNAlbumLibraryWidget(isAlbumContent: false),
      size: const Size(1000, 700),
      settle: false,
    );
    await expectGolden(tester, 'screen_playlists_library');
  });

  testWidgets('albums library widget', (tester) async {
    await pumpGolden(
      tester,
      const PlaylistNAlbumLibraryWidget(),
      size: const Size(1000, 700),
      settle: false,
    );
    await expectGolden(tester, 'screen_albums_library');
  });

  testWidgets('artists library widget', (tester) async {
    await pumpGolden(
      tester,
      const LibraryArtistWidget(),
      size: const Size(1000, 700),
      settle: false,
    );
    await expectGolden(tester, 'screen_artists_library');
  });

  testWidgets('downloads library widget', (tester) async {
    await pumpGolden(
      tester,
      const DownloadsLibraryWidget(),
      size: const Size(1000, 700),
      settle: false,
    );
    await expectGolden(tester, 'screen_downloads_library');
  });

  testWidgets('library list full screen', (tester) async {
    await pumpGolden(
      tester,
      const LibraryListFullScreen(tabIndex: 0),
      useScaffold: false,
      size: const Size(1200, 800),
      settle: false,
    );
    await expectGolden(tester, 'screen_library_list_full');
  });

  testWidgets('settings screen', (tester) async {
    await pumpGolden(
      tester,
      const SettingsScreen(),
      size: const Size(1400, 1000),
      settle: false,
    );
    await expectGolden(tester, 'screen_settings');
  });

  testWidgets('playlist screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final playlist = Playlist(
      title: 'Evening Mix',
      playlistId: 'p1',
      thumbnailUrl: 'https://img.example.com/p1.jpg',
      isCloudPlaylist: false,
    );
    final playlistController = FakePlaylistScreenController();
    Get.put<PlaylistScreenController>(playlistController,
        tag: null.hashCode.toString());
    playlistController.playlist.value = playlist;
    playlistController.songList.value = songs;
    playlistController.isContentFetched.value = true;
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goldenTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
            key: goldenRootKey, child: const PlaylistScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectGolden(tester, 'screen_playlist');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('album screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final albumController = FakeAlbumScreenController();
    Get.put<AlbumScreenController>(albumController,
        tag: null.hashCode.toString());
    albumController.album.value = albums[0];
    albumController.songList.value = songs;
    albumController.isContentFetched.value = true;
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goldenTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(key: goldenRootKey, child: const AlbumScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectGolden(tester, 'screen_album');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('artist screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final artistController = FakeArtistScreenController();
    Get.put<ArtistScreenController>(artistController,
        tag: null.hashCode.toString());
    artistController.artist_ = artists[0];
    artistController.isArtistContentFetced.value = true;
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goldenTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(key: goldenRootKey, child: const ArtistScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectGolden(tester, 'screen_artist');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search result screen', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final resultController = FakeSearchResultScreenController();
    Get.put<SearchResultScreenController>(resultController,
        tag: null.hashCode.toString());
    resultController.isResultContentFetched.value = true;
    resultController.queryString.value = 'golden';
    resultController.resultContent.value = {'Songs': songs};
    resultController.railItems.value = ['Songs'];
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goldenTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultTabController(
          length: 2,
          child: RepaintBoundary(
              key: goldenRootKey, child: const SearchResultScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectGolden(tester, 'screen_search_result');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tv now playing screen', (tester) async {
    await pumpGolden(
      tester,
      const TvNowPlayingScreen(),
      useScaffold: false,
      size: const Size(1400, 800),
      settle: false,
    );
    await expectGolden(tester, 'screen_tv_now_playing');
  });

  testWidgets('tv queue screen', (tester) async {
    await pumpGolden(
      tester,
      const TvQueueScreen(),
      useScaffold: false,
      size: const Size(1400, 800),
      settle: false,
    );
    await expectGolden(tester, 'screen_tv_queue');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tv lyrics screen', (tester) async {
    await pumpGolden(
      tester,
      const TvLyricsScreen(),
      useScaffold: false,
      size: const Size(1400, 800),
      settle: false,
    );
    await expectGolden(tester, 'screen_tv_lyrics');
  });
}
