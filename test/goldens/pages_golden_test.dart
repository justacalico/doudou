import 'dart:io';

import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/models/media_item_builder.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/models/quick_picks.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/ui/player/player.dart' as doudou_player;
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
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';
import 'golden_fakes.dart';
import 'golden_helpers.dart';

enum Form { mobile, desktop }

void main() {
  late Directory hiveDir;
  late GoldenDeps deps;
  late FakeHomeScreenController homeController;
  late FakeLibraryPlaylistsController playlistsController;
  late FakeLibrarySongsController songsController;
  late FakeLibraryAlbumsController albumsController;
  late FakeLibraryArtistsController artistsController;
  late FakeSearchScreenController searchController;
  late FakeSearchResultScreenController resultController;

  final songs = [
    goldenSong('s1', 'Sunset Boulevard'),
    goldenSong('s2', 'Midnight Train'),
    goldenSong('s3', 'Northern Lights'),
    goldenSong('s4', 'Paper Moon'),
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
    Playlist(
        title: 'Road Trip',
        playlistId: 'p3',
        thumbnailUrl: 'https://img.example.com/p3.jpg',
        songCount: '33'),
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
    Album(
        title: 'Night Drive',
        browseId: 'a2',
        artists: const [
          {'name': 'Another Artist'}
        ],
        year: '2023',
        thumbnailUrl: 'https://img.example.com/a2.jpg'),
  ];

  final artists = [
    Artist(
        name: 'Golden Artist',
        browseId: 'ar1',
        thumbnailUrl: 'https://img.example.com/ar1.jpg',
        subscribers: '1.2M'),
    Artist(
        name: 'Another Artist',
        browseId: 'ar2',
        thumbnailUrl: 'https://img.example.com/ar2.jpg',
        subscribers: '420K'),
  ];

  Future<void> seedData() async {
    final downloadsBox = Hive.isBoxOpen('SongDownloads')
        ? Hive.box('SongDownloads')
        : await Hive.openBox('SongDownloads');
    for (final song in songs) {
      await downloadsBox.put(song.id, MediaItemBuilder.toJson(song));
    }
  }

  void populateLibraries() {
    songsController.librarySongsList = RxList(songs);
    songsController.isSongFetched.value = true;
    albumsController.libraryAlbums = RxList(albums);
    albumsController.isContentFetched.value = true;
    artistsController.libraryArtists = RxList(artists);
    artistsController.isContentFetched.value = true;
    playlistsController.libraryPlaylists =
        RxList([...FakeLibraryPlaylistsController.builtins, ...playlists]);
    playlistsController.isContentFetched.value = true;
  }

  void emptyLibraries() {
    songsController.librarySongsList = RxList([]);
    songsController.isSongFetched.value = true;
    albumsController.libraryAlbums = RxList([]);
    albumsController.isContentFetched.value = true;
    artistsController.libraryArtists = RxList([]);
    artistsController.isContentFetched.value = true;
    playlistsController.libraryPlaylists =
        RxList(FakeLibraryPlaylistsController.builtins);
    playlistsController.isContentFetched.value = true;
  }

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('doudou_golden_pages_');
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
      'SongDownloads_s_1',
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
    deps.player.playerPanelMinHeight.value = 110;

    homeController = FakeHomeScreenController();
    Get.put<HomeScreenController>(homeController);
    playlistsController = FakeLibraryPlaylistsController();
    Get.put<LibraryPlaylistsController>(playlistsController);
    songsController = FakeLibrarySongsController();
    Get.put<LibrarySongsController>(songsController);
    albumsController = FakeLibraryAlbumsController();
    Get.put<LibraryAlbumsController>(albumsController);
    artistsController = FakeLibraryArtistsController();
    Get.put<LibraryArtistsController>(artistsController);
    searchController = FakeSearchScreenController();
    Get.put<SearchScreenController>(searchController);
    resultController = FakeSearchResultScreenController();
    Get.put<SearchResultScreenController>(resultController,
        tag: null.hashCode.toString());

    await seedData();
    populateLibraries();
  });

  tearDown(() async {
    Get.reset();
    if (Hive.isBoxOpen('SongDownloads')) {
      await Hive.box('SongDownloads').clear();
    }
  });

  Size formSize(Form form) =>
      form == Form.mobile ? const Size(390, 844) : const Size(1440, 900);

  Future<void> pumpPage(WidgetTester tester, Form form, Widget child) async {
    Get.find<ShellController>().useBottomNav.value = form == Form.mobile;
    await pumpGolden(
      tester,
      child,
      size: formSize(form),
      settle: false,
    );
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  for (final form in Form.values) {
    final f = form.name;

    group('$f pages', () {
      testWidgets('home loading', (tester) async {
        homeController.isContentFetched.value = true;
        (Get.find<MusicServices>() as GoldenMusicServices).hangHome = true;
        await pumpPage(tester, form, const HomeScreen());
        await expectGolden(tester, '$f/home_loading');
        await tester.pump(const Duration(seconds: 12));
      });

      testWidgets('home content', (tester) async {
        homeController.isContentFetched.value = true;
        homeController.quickPicks.value =
            QuickPicks(songs, title: 'Quick picks');
        homeController.youtubeMusicHomeContent.value = [
          {'title': 'Trending now', 'contents': songs},
          {'title': 'Fresh albums', 'contents': albums},
          {'title': 'Your playlists', 'contents': playlists},
        ];
        await pumpPage(tester, form, const HomeScreen());
        await expectGolden(tester, '$f/home_content');
        await tester.pump(const Duration(seconds: 12));
      });

      testWidgets('home error', (tester) async {
        homeController.isContentFetched.value = true;
        homeController.networkError.value = true;
        await pumpPage(tester, form, const HomeScreen());
        await expectGolden(tester, '$f/home_error');
        await tester.pump(const Duration(seconds: 12));
      });

      testWidgets('home empty', (tester) async {
        emptyLibraries();
        homeController.isContentFetched.value = true;
        await pumpPage(tester, form, const HomeScreen());
        await expectGolden(tester, '$f/home_empty');
        await tester.pump(const Duration(seconds: 12));
      });

      testWidgets('search start', (tester) async {
        await pumpPage(tester, form, const SearchScreen());
        await expectGolden(tester, '$f/search_start');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('search history', (tester) async {
        searchController.historyQuerylist.value = [
          'golden hour',
          'midnight train',
          'northern lights'
        ];
        await pumpPage(tester, form, const SearchScreen());
        await expectGolden(tester, '$f/search_history');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('search result loading', (tester) async {
        resultController.queryString.value = 'golden';
        await pumpPage(tester, form, const SearchResultScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/search_result_loading');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('search result content', (tester) async {
        resultController.isResultContentFetched.value = true;
        resultController.queryString.value = 'golden';
        resultController.resultContent.value = {'Songs': songs};
        await pumpPage(tester, form, const SearchResultScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/search_result_content');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('search result empty', (tester) async {
        resultController.isResultContentFetched.value = true;
        resultController.queryString.value = 'unknown query';
        resultController.resultContent.value = {};
        await pumpPage(tester, form, const SearchResultScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/search_result_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library browse populated', (tester) async {
        await pumpPage(tester, form, const LibraryBrowseScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/library_browse_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library browse empty', (tester) async {
        emptyLibraries();
        await pumpPage(tester, form, const LibraryBrowseScreen());
        await expectGolden(tester, '$f/library_browse_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library songs populated', (tester) async {
        await pumpPage(tester, form, const SongsLibraryWidget());
        drainExceptions(tester);
        await expectGolden(tester, '$f/library_songs_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library songs loading', (tester) async {
        songsController.isSongFetched.value = false;
        await pumpPage(tester, form, const SongsLibraryWidget());
        await expectGolden(tester, '$f/library_songs_loading');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library songs empty', (tester) async {
        songsController.librarySongsList = RxList([]);
        await pumpPage(tester, form, const SongsLibraryWidget());
        await expectGolden(tester, '$f/library_songs_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library playlists populated', (tester) async {
        await pumpPage(
            tester, form, const PlaylistNAlbumLibraryWidget(isAlbumContent: false));
        await expectGolden(tester, '$f/library_playlists_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library playlists empty', (tester) async {
        playlistsController.libraryPlaylists = RxList([]);
        await pumpPage(
            tester, form, const PlaylistNAlbumLibraryWidget(isAlbumContent: false));
        await expectGolden(tester, '$f/library_playlists_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library albums populated', (tester) async {
        await pumpPage(tester, form, const PlaylistNAlbumLibraryWidget());
        await expectGolden(tester, '$f/library_albums_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library albums empty', (tester) async {
        albumsController.libraryAlbums = RxList([]);
        await pumpPage(tester, form, const PlaylistNAlbumLibraryWidget());
        await expectGolden(tester, '$f/library_albums_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library artists populated', (tester) async {
        await pumpPage(tester, form, const LibraryArtistWidget());
        await expectGolden(tester, '$f/library_artists_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library artists empty', (tester) async {
        artistsController.libraryArtists = RxList([]);
        await pumpPage(tester, form, const LibraryArtistWidget());
        await expectGolden(tester, '$f/library_artists_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library downloads populated', (tester) async {
        await pumpPage(tester, form, const DownloadsLibraryWidget());
        await expectGolden(tester, '$f/library_downloads_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('library downloads empty', (tester) async {
        Get.find<SettingsScreenController>().activeServerId.value = 1;
        await pumpPage(tester, form, const DownloadsLibraryWidget());
        await expectGolden(tester, '$f/library_downloads_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('playlist populated', skip: form == Form.desktop, (tester) async {
        final playlistController = FakePlaylistScreenController();
        Get.put<PlaylistScreenController>(playlistController,
            tag: null.hashCode.toString());
        playlistController.playlist.value = playlists[0];
        playlistController.songList.value = songs;
        playlistController.isContentFetched.value = true;
        await pumpPage(tester, form, const PlaylistScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/playlist_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('playlist empty', skip: form == Form.desktop, (tester) async {
        final playlistController = FakePlaylistScreenController();
        Get.put<PlaylistScreenController>(playlistController,
            tag: null.hashCode.toString());
        playlistController.playlist.value = Playlist(
          title: 'Fresh Mix',
          playlistId: 'p_empty',
          thumbnailUrl: Playlist.thumbPlaceholderUrl,
          isCloudPlaylist: false,
        );
        playlistController.isContentFetched.value = true;
        await pumpPage(tester, form, const PlaylistScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/playlist_empty');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('album populated', skip: form == Form.desktop, (tester) async {
        final albumController = FakeAlbumScreenController();
        Get.put<AlbumScreenController>(albumController,
            tag: null.hashCode.toString());
        albumController.album.value = albums[0];
        albumController.songList.value = songs;
        albumController.isContentFetched.value = true;
        await pumpPage(tester, form, const AlbumScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/album_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('album loading', skip: form == Form.desktop, (tester) async {
        final albumController = FakeAlbumScreenController();
        Get.put<AlbumScreenController>(albumController,
            tag: null.hashCode.toString());
        albumController.album.value = albums[0];
        await pumpPage(tester, form, const AlbumScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/album_loading');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('artist populated', skip: form == Form.desktop, (tester) async {
        final artistController = FakeArtistScreenController();
        Get.put<ArtistScreenController>(artistController,
            tag: null.hashCode.toString());
        artistController.artist_ = artists[0];
        artistController.isArtistContentFetced.value = true;
        await pumpPage(tester, form, const ArtistScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/artist_populated');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('artist loading', skip: form == Form.desktop, (tester) async {
        final artistController = FakeArtistScreenController();
        Get.put<ArtistScreenController>(artistController,
            tag: null.hashCode.toString());
        artistController.artist_ = artists[0];
        await pumpPage(tester, form, const ArtistScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/artist_loading');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('settings', (tester) async {
        await pumpPage(tester, form, const SettingsScreen());
        drainExceptions(tester);
        await expectGolden(tester, '$f/settings');
        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('player', (tester) async {
        await pumpPage(tester, form, const doudou_player.Player());
        drainExceptions(tester);
        await expectGolden(tester, '$f/player');
        await tester.pump(const Duration(seconds: 11));
        await tester.pump(const Duration(seconds: 12));
      });
    });
  }
}
