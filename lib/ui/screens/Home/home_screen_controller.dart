import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '/models/media_Item_builder.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';
import '/models/quick_picks.dart';
import '/models/server.dart';
import '/services/backend/music_backend.dart';
import '/services/library_sync_service.dart';
import '/services/music_service.dart';
import '/ui/player/player_controller.dart';
import '/ui/screens/Search/search_screen_controller.dart';
import '../../../utils/helper.dart';
import '../../../utils/server_storage.dart';
import '../../../utils/update_check_flag_file.dart';
import '../Library/library_controller.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/navigator.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/new_version_dialog.dart';

class HomeScreenController extends GetxController {
  final MusicServices _musicServices = Get.find<MusicServices>();

  MusicBackend get _backend =>
      Get.find<SettingsScreenController>().currentBackend;
  final isContentFetched = false.obs;
  final tabIndex = 0.obs;
  final networkError = false.obs;
  final quickPicks = QuickPicks([]).obs;
  final middleContent = [].obs;
  final fixedContent = [].obs;
  final showVersionDialog = true.obs;
  //isHomeScreenOnTop var only useful if bottom nav enabled
  final isHomeSreenOnTop = true.obs;
  final List<ScrollController> contentScrollControllers = [];
  bool reverseAnimationtransiton = false;
  final albumsFromFollowedArtists = <Album>[].obs;
  bool _albumsFromFollowedLoadStarted = false;
  Future<HomeLibrarySections>? _homeSectionsFuture;
  HomeLibrarySections? _cachedHomeSections;
  bool _isHomeSectionsRefreshing = false;
  final homeLibrarySectionsVersion = 0.obs;
  static const Duration _homeSectionsCacheTtl = Duration(hours: 8);
  Worker? _librarySyncWorker;

  @override
  onInit() {
    super.onInit();
    final checkOnStartup =
        Hive.box("AppPrefs").get("checkForUpdatesOnStartup") ?? true;
    if (updateCheckFlag && checkOnStartup) _checkNewVersion();
    ever(Get.find<SettingsScreenController>().activeServerId, (_) {
      if (!Get.isRegistered<HomeScreenController>()) return;
      _albumsFromFollowedLoadStarted = false;
      albumsFromFollowedArtists.value = [];
      loadContentFromNetwork(silent: true);
    });
    _librarySyncWorker =
        ever(Get.find<LibrarySyncService>().syncVersionByKind, (_) {
      final settings = Get.find<SettingsScreenController>();
      final server = settings.activeServer;
      if (server == null || server.type == ServerType.youtubeMusic) return;
      // Rebuild immediately so sections appear as each library kind finishes.
      unawaited(refreshHomeLibrarySectionsFromControllers());
    });
  }

  Future<void> loadContent() async {
    final box = Hive.box("AppPrefs");
    final isCachedHomeScreenDataEnabled =
        box.get("cacheHomeScreenData") ?? true;
    if (isCachedHomeScreenDataEnabled) {
      final loaded = await loadContentFromDb();

      if (loaded) {
        final timeKey = "homeScreenDataTime_${currentServerId()}";
        final currTimeSecsDiff = DateTime.now().millisecondsSinceEpoch -
            (box.get(timeKey) ?? DateTime.now().millisecondsSinceEpoch);
        if (currTimeSecsDiff / 1000 > 3600 * 8) {
          loadContentFromNetwork(silent: true);
        }
      } else {
        loadContentFromNetwork();
      }
    } else {
      loadContentFromNetwork();
    }
  }

  Future<bool> loadContentFromDb() async {
    final homeScreenData =
        await Hive.openBox(homeScreenDataBoxName(currentServerId()));
    if (homeScreenData.keys.isNotEmpty) {
      final String quickPicksType = homeScreenData.get("quickPicksType");
      final List quickPicksData = homeScreenData.get("quickPicks");
      final List middleContentData = homeScreenData.get("middleContent") ?? [];
      final List fixedContentData = homeScreenData.get("fixedContent") ?? [];
      quickPicks.value = QuickPicks(
          quickPicksData.map((e) => MediaItemBuilder.fromJson(e)).toList(),
          title: quickPicksType);
      middleContent.value = middleContentData
          .map((e) => e["type"] == "Album Content"
              ? AlbumContent.fromJson(e)
              : PlaylistContent.fromJson(e))
          .toList();
      fixedContent.value = fixedContentData
          .map((e) => e["type"] == "Album Content"
              ? AlbumContent.fromJson(e)
              : PlaylistContent.fromJson(e))
          .toList();
      isContentFetched.value = true;
      printINFO("Loaded from offline db");
      return true;
    } else {
      return false;
    }
  }

  Future<void> loadContentFromNetwork({bool silent = false}) async {
    final backend = _backend;
    final caps = backend.capabilities;
    if (!caps.hasDiscoverContent && !caps.hasCharts) {
      quickPicks.value = QuickPicks([], title: '');
      middleContent.value = [];
      fixedContent.value = [];
      isContentFetched.value = true;
      return;
    }

    final box = Hive.box("AppPrefs");
    String contentType = box.get("discoverContentType") ?? "QP";

    networkError.value = false;
    try {
      List middleContentTemp = [];
      final homeContentListMap = await backend.getHome(
          limit:
              Get.find<SettingsScreenController>().noOfHomeScreenContent.value);
      if (contentType == "TR" && caps.hasTrending) {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Trending");
        if (index != -1 && index != 0) {
          quickPicks.value = QuickPicks(
              List<MediaItem>.from(homeContentListMap[index]["contents"]),
              title: "Trending");
        } else if (index == -1) {
          List charts = await backend.getCharts(contentType);
          final index = charts.indexWhere((element) =>
              element['title'] ==
              (contentType == "TMV" ? "Top Music Videos" : "Trending"));
          if (index != -1) {
            quickPicks.value = QuickPicks(
                List<MediaItem>.from(charts[index]["contents"]),
                title: charts[index]['title']);
            middleContentTemp.addAll(charts);
          }
        }
      } else if (contentType == "TMV" && caps.hasCharts) {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Top music videos");
        if (index != -1 && index != 0) {
          final con = homeContentListMap.removeAt(index);
          quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
              title: con["title"]);
        } else if (index == -1) {
          List charts = await backend.getCharts(contentType);
          final index = charts.indexWhere((element) =>
              element['title'] ==
              (contentType == "TMV" ? "Top Music Videos" : "Trending"));
          if (index != -1) {
            quickPicks.value = QuickPicks(
                List<MediaItem>.from(charts[index]["contents"]),
                title: charts[index]["title"]);
            middleContentTemp.addAll(charts);
          }
        }
      } else if (contentType == "BOLI" && caps.hasDiscoverContent) {
        try {
          final songId = box.get("recentSongId_${currentServerId()}");
          if (songId != null) {
            final rel = (await backend.getContentRelatedToSong(
                songId, getContentHlCode()));
            final con = rel.removeAt(0);
            quickPicks.value =
                QuickPicks(List<MediaItem>.from(con["contents"]));
            middleContentTemp.addAll(rel);
          }
        } catch (e) {
          printERROR(
              "Seems Based on last interaction content currently not available!");
        }
      }

      if (quickPicks.value.songList.isEmpty) {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Quick picks");
        final con = homeContentListMap.removeAt(index);
        quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
            title: "Quick picks");
      }

      middleContent.value = _setContentList(middleContentTemp);
      fixedContent.value = _setContentList(homeContentListMap);

      isContentFetched.value = true;

      // set home content last update time
      cachedHomeScreenData(updateAll: true);
      await Hive.box("AppPrefs").put("homeScreenDataTime_${currentServerId()}",
          DateTime.now().millisecondsSinceEpoch);
      // ignore: unused_catch_stack
    } on NetworkError catch (r, e) {
      printERROR("Home Content not loaded due to ${r.message}");
      await Future.delayed(const Duration(seconds: 1));
      networkError.value = !silent;
    }
  }

  void ensureAlbumsFromFollowedLoaded() {
    if (_albumsFromFollowedLoadStarted) return;
    try {
      final libArtists = Get.find<LibraryArtistsController>().libraryArtists;
      if (libArtists.isEmpty) return;
    } catch (_) {
      return;
    }
    _albumsFromFollowedLoadStarted = true;
    loadAlbumsFromFollowedArtists();
  }

  Future<void> loadAlbumsFromFollowedArtists() async {
    try {
      final libArtists = Get.find<LibraryArtistsController>().libraryArtists;
      if (libArtists.isEmpty) return;
      const limit = 10;
      final artists = libArtists.take(limit).toList();
      final List<Album> aggregated = [];
      final Set<String> seenIds = {};
      for (final artist in artists) {
        try {
          final result = await _musicServices.getArtist(artist.browseId);
          for (final key in ['Albums', 'Singles', 'Singles & EPs']) {
            final section = result[key];
            if (section is! Map) continue;
            final content = section['content'];
            if (content is! List) continue;
            for (final item in content) {
              if (item is! Album) continue;
              if (seenIds.add(item.browseId)) aggregated.add(item);
            }
          }
        } catch (_) {}
      }
      albumsFromFollowedArtists.value = aggregated;
    } catch (_) {}
  }

  List _setContentList(
    List<dynamic> contents,
  ) {
    List contentTemp = [];
    for (var content in contents) {
      if ((content["contents"]).isEmpty) continue;
      if ((content["contents"][0]).runtimeType == Playlist) {
        final tmp = PlaylistContent(
            playlistList: (content["contents"]).whereType<Playlist>().toList(),
            title: content["title"]);
        if (tmp.playlistList.length >= 2) {
          contentTemp.add(tmp);
        }
      } else if ((content["contents"][0]).runtimeType == Album) {
        final tmp = AlbumContent(
            albumList: (content["contents"]).whereType<Album>().toList(),
            title: content["title"]);
        if (tmp.albumList.length >= 2) {
          contentTemp.add(tmp);
        }
      }
    }
    return contentTemp;
  }

  Future<void> changeDiscoverContent(dynamic val, {String? songId}) async {
    final backend = _backend;
    QuickPicks? quickPicks_;
    if (val == 'QP') {
      final homeContentListMap = await backend.getHome(limit: 3);
      quickPicks_ = QuickPicks(
          List<MediaItem>.from(homeContentListMap[0]["contents"]),
          title: homeContentListMap[0]["title"]);
    } else if (val == "TMV" || val == 'TR') {
      try {
        final charts = await backend.getCharts(val);
        final index = charts.indexWhere((element) =>
            element['title'] ==
            (val == "TMV" ? "Top Music Videos" : "Trending"));
        quickPicks_ = QuickPicks(
            List<MediaItem>.from(charts[index]["contents"]),
            title: charts[index]["title"]);
      } catch (e) {
        printERROR(
            "Seems ${val == "TMV" ? "Top music videos" : "Trending songs"} currently not available!");
      }
    } else {
      final songIdKey = "recentSongId_${currentServerId()}";
      songId ??= Hive.box("AppPrefs").get(songIdKey);
      if (songId != null) {
        try {
          final value =
              await backend.getContentRelatedToSong(songId, getContentHlCode());
          middleContent.value = _setContentList(value);
          if (value.isNotEmpty && (value[0]['title']).contains("like")) {
            quickPicks_ =
                QuickPicks(List<MediaItem>.from(value[0]["contents"]));
            Hive.box("AppPrefs").put(songIdKey, songId);
          }
          // ignore: empty_catches
        } catch (e) {}
      }
    }
    if (quickPicks_ == null) return;

    quickPicks.value = quickPicks_;

    // set home content last update time
    cachedHomeScreenData(updateQuickPicksNMiddleContent: true);
    await Hive.box("AppPrefs").put("homeScreenDataTime_${currentServerId()}",
        DateTime.now().millisecondsSinceEpoch);
  }

  String getContentHlCode() {
    const List<String> unsupportedLangIds = ["ia", "ga", "fj", "eo"];
    final userLangId =
        Get.find<SettingsScreenController>().currentAppLanguageCode.value;
    return unsupportedLangIds.contains(userLangId) ? "en" : userLangId;
  }

  void onSideBarTabSelected(int index) {
    final wasHomeTab = tabIndex.value == 0;
    final isOnHome = Get.currentRoute == ScreenNavigationSetup.homeScreen;
    if (isOnHome && index == tabIndex.value) {
      ScreenNavigationSetup.offContentRoute(ScreenNavigationSetup.homeScreen);
      return;
    }
    reverseAnimationtransiton = index > tabIndex.value;
    tabIndex.value = index;
    if (wasHomeTab &&
        index != 0 &&
        Get.isRegistered<SearchScreenController>()) {
      final search = Get.find<SearchScreenController>();
      search.hideSuggestions();
      search.focusNode.unfocus();
    }
    if (!isOnHome) {
      ScreenNavigationSetup.offContentRoute(ScreenNavigationSetup.homeScreen);
    }
  }

  void onBottonBarTabSelected(int index) {
    final isOnHome = Get.currentRoute == ScreenNavigationSetup.homeScreen;
    final wasHomeTab = tabIndex.value == 0;
    reverseAnimationtransiton = index > tabIndex.value;
    tabIndex.value = index;
    if (wasHomeTab &&
        index != 0 &&
        Get.isRegistered<SearchScreenController>()) {
      final search = Get.find<SearchScreenController>();
      search.hideSuggestions();
      search.focusNode.unfocus();
    }
    if (!isOnHome) {
      ScreenNavigationSetup.offContentRoute(ScreenNavigationSetup.homeScreen);
    }
  }

  void remapTabIndexForNavModeChange({required bool useBottomNav}) {
    final current = tabIndex.value;

    if (useBottomNav) {
      // Switching to bottom navigation (mobile).
      if (current == 0) {
        return;
      }

      if (current == 5) {
        tabIndex.value = 3;
      } else if (current >= 1 && current <= 4) {
        tabIndex.value = 2;
      } else if (current < 0 || current > 5) {
        tabIndex.value = 0;
      }
    } else {
      // Switching to sidebar (desktop).
      if (current == 0) {
        return;
      }

      if (current == 1) {
        tabIndex.value = 1;
      } else if (current == 2) {
        tabIndex.value = 2;
      } else if (current == 3) {
        tabIndex.value = 5;
      } else if (current < 0 || current > 5) {
        tabIndex.value = 0;
      }
    }
  }

  void _checkNewVersion() {
    showVersionDialog.value =
        Hive.box("AppPrefs").get("newVersionVisibility") ?? true;
    if (!showVersionDialog.isTrue) return;
    PackageInfo.fromPlatform().then((info) {
      return newVersionCheck(info.version);
    }).then((latest) {
      if (latest != null) {
        final settings = Get.find<SettingsScreenController>();
        settings.latestAvailableVersion.value = latest;
        settings.isNewVersionAvailable.value = true;
        showDialog(
            context: Get.context!,
            builder: (context) => NewVersionDialog(latestVersion: latest));
      }
    });
  }

  void onChangeVersionVisibility(bool val) {
    Hive.box("AppPrefs").put("newVersionVisibility", !val);
    showVersionDialog.value = !val;
  }

  ///This is used to minimized bottom navigation bar by setting [isHomeSreenOnTop.value] to `true` and set mini player height.
  ///
  ///and applicable/useful if bottom nav enabled
  void whenHomeScreenOnTop() {
    final useBottomNav = Get.find<ShellController>().useBottomNav.value;
    if (useBottomNav) {
      final currentRoute = getCurrentRouteName();
      final isHomeOnTop = currentRoute == '/homeScreen';
      final playerCon = Get.find<PlayerController>();

      isHomeSreenOnTop.value = isHomeOnTop;

      // Set miniplayer height accordingly (keep 80 when bottom nav so it stays flush with navbar)
      if (!playerCon.initFlagForPlayer) {
        playerCon.playerPanelMinHeight.value = 80.0;
      }
    }
  }

  Future<void> cachedHomeScreenData({
    bool updateAll = false,
    bool updateQuickPicksNMiddleContent = false,
  }) async {
    if (Get.find<SettingsScreenController>().cacheHomeScreenData.isFalse ||
        quickPicks.value.songList.isEmpty) {
      return;
    }

    final boxName = homeScreenDataBoxName(currentServerId());
    final homeScreenData = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);

    if (updateQuickPicksNMiddleContent) {
      await homeScreenData.putAll({
        "quickPicksType": quickPicks.value.title,
        "quickPicks": _getContentDataInJson(quickPicks.value.songList,
            isQuickPicks: true),
        "middleContent": _getContentDataInJson(middleContent.toList()),
      });
    } else if (updateAll) {
      await homeScreenData.putAll({
        "quickPicksType": quickPicks.value.title,
        "quickPicks": _getContentDataInJson(quickPicks.value.songList,
            isQuickPicks: true),
        "middleContent": _getContentDataInJson(middleContent.toList()),
        "fixedContent": _getContentDataInJson(fixedContent.toList())
      });
    }

    printINFO("Saved Homescreen data data");
  }

  Future<HomeLibrarySections> loadHomeLibrarySections() async {
    if (_cachedHomeSections != null) {
      _refreshHomeLibrarySectionsInBackground();
      return _cachedHomeSections!;
    }
    _homeSectionsFuture ??= _loadHomeLibrarySectionsStaleWhileRevalidate();
    return _homeSectionsFuture!;
  }

  void invalidateHomeLibrarySections() {
    _cachedHomeSections = null;
    _homeSectionsFuture = null;
    homeLibrarySectionsVersion.value++;
  }

  Future<void> refreshHomeLibrarySectionsFromControllers() async {
    if (_isHomeSectionsRefreshing) return;
    _isHomeSectionsRefreshing = true;
    try {
      final fresh = await _buildHomeLibrarySections();
      _cachedHomeSections = fresh;
      _homeSectionsFuture = Future<HomeLibrarySections>.value(fresh);
      homeLibrarySectionsVersion.value++;
      await _cacheHomeLibrarySections(fresh);
    } catch (e) {
      printERROR("Failed to refresh home sections from libraries: $e");
    } finally {
      _isHomeSectionsRefreshing = false;
    }
  }

  Future<HomeLibrarySections>
      _loadHomeLibrarySectionsStaleWhileRevalidate() async {
    final cached = await _loadHomeLibrarySectionsFromDb();
    if (cached != null) {
      _cachedHomeSections = cached;
      _homeSectionsFuture = Future<HomeLibrarySections>.value(cached);
      _refreshHomeLibrarySectionsInBackground();
      return cached;
    }

    final fresh = await _buildHomeLibrarySections();
    _cachedHomeSections = fresh;
    _homeSectionsFuture = Future<HomeLibrarySections>.value(fresh);
    homeLibrarySectionsVersion.value++;
    await _cacheHomeLibrarySections(fresh);
    return fresh;
  }

  void _refreshHomeLibrarySectionsInBackground() {
    if (_isHomeSectionsRefreshing) return;
    if (!_isHomeLibrarySectionsCacheStale()) return;
    _isHomeSectionsRefreshing = true;
    Future<void>(() async {
      try {
        final fresh = await _buildHomeLibrarySections();
        _cachedHomeSections = fresh;
        _homeSectionsFuture = Future<HomeLibrarySections>.value(fresh);
        homeLibrarySectionsVersion.value++;
        await _cacheHomeLibrarySections(fresh);
      } catch (e) {
        printERROR("Failed to refresh home library sections: $e");
      } finally {
        _isHomeSectionsRefreshing = false;
      }
    });
  }

  bool _isHomeLibrarySectionsCacheStale() {
    final appPrefs = Hive.box("AppPrefs");
    final key = "homeLibrarySectionsTime_${currentServerId()}";
    final ts = appPrefs.get(key);
    if (ts is! int) return true;
    final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
    return ageMs > _homeSectionsCacheTtl.inMilliseconds;
  }

  Future<HomeLibrarySections?> _loadHomeLibrarySectionsFromDb() async {
    if (Get.find<SettingsScreenController>().cacheHomeScreenData.isFalse) {
      return null;
    }
    final boxName = "homeLibrarySectionsData_${currentServerId()}";
    try {
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      final raw = box.get("sections");
      if (raw is Map) {
        return HomeLibrarySections.fromJson(Map<dynamic, dynamic>.from(raw));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheHomeLibrarySections(HomeLibrarySections sections) async {
    if (Get.find<SettingsScreenController>().cacheHomeScreenData.isFalse) {
      return;
    }
    final serverId = currentServerId();
    final boxName = "homeLibrarySectionsData_$serverId";
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);
    await box.put("sections", sections.toJson());
    await Hive.box("AppPrefs").put(
      "homeLibrarySectionsTime_$serverId",
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<HomeLibrarySections> _buildHomeLibrarySections() async {
    final songsController = Get.isRegistered<LibrarySongsController>()
        ? Get.find<LibrarySongsController>()
        : null;
    final playlistsController = Get.isRegistered<LibraryPlaylistsController>()
        ? Get.find<LibraryPlaylistsController>()
        : null;
    final albumsController = Get.isRegistered<LibraryAlbumsController>()
        ? Get.find<LibraryAlbumsController>()
        : null;
    final artistsController = Get.isRegistered<LibraryArtistsController>()
        ? Get.find<LibraryArtistsController>()
        : null;

    final allSongs = songsController != null
        ? await songsController.loadAllSongsForShuffle()
        : <MediaItem>[];

    final continueListening = await _loadRecentlyPlayed();
    final basedOnFavorites =
        await _pickTracksFromFavoriteArtists(allSongs: allSongs);

    final playlistsFromCollection = <Playlist>[];
    if (playlistsController != null) {
      final allPlaylists = playlistsController.libraryPlaylists.toList();
      if (allPlaylists.length > LibraryPlaylistsController.initPlst.length) {
        playlistsFromCollection.addAll(
          allPlaylists.skip(LibraryPlaylistsController.initPlst.length),
        );
      }
    }

    final latestAlbums = albumsController?.libraryAlbums.toList() ?? <Album>[];

    final artistsToExplore = artistsController != null
        ? _pickVaried<Artist>(
            artistsController.libraryArtists.toList(),
            10,
            salt: 'artists',
            keyOf: (a) => a.browseId,
          )
        : <Artist>[];

    final freshPicks = _pickVaried<MediaItem>(
      allSongs,
      10,
      salt: 'fresh',
      keyOf: (t) => t.id,
    );

    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTubeServer = server?.type == ServerType.youtubeMusic;
    int favoriteCount = 0;
    if (isYouTubeServer) {
      try {
        final box = await Hive.openBox(libFavBoxName(currentServerId()));
        favoriteCount = box.length;
      } catch (_) {}
    } else {
      try {
        final list = await _backend.getFavoriteSongs();
        favoriteCount = list.length;
      } catch (_) {}
    }

    return HomeLibrarySections(
      continueListening: continueListening,
      basedOnFavorites: basedOnFavorites,
      playlistsFromCollection: playlistsFromCollection,
      latestAlbums: latestAlbums,
      artistsToExplore: artistsToExplore,
      freshPicks: freshPicks,
      favoriteCount: favoriteCount,
    );
  }

  Future<List<MediaItem>> _loadRecentlyPlayed() async {
    try {
      final box = await Hive.openBox(recentlyPlayedBoxName(currentServerId()));
      final values = box.values.toList();
      return values
          .map<MediaItem?>(
              (e) => MediaItemBuilder.fromJson(Map<dynamic, dynamic>.from(e)))
          .whereType<MediaItem>()
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<MediaItem>> _pickTracksFromFavoriteArtists({
    required List<MediaItem> allSongs,
  }) async {
    if (allSongs.isEmpty) return const [];
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTubeServer = server?.type == ServerType.youtubeMusic;

    List<MediaItem> favorites;
    if (isYouTubeServer) {
      final favBoxName = libFavBoxName(currentServerId());
      try {
        final box = await Hive.openBox(favBoxName);
        favorites = box.values
            .map<MediaItem?>(
                (e) => MediaItemBuilder.fromJson(Map<dynamic, dynamic>.from(e)))
            .whereType<MediaItem>()
            .toList();
      } catch (_) {
        favorites = const [];
      }
    } else {
      try {
        final tracks = await settings.currentBackend.getFavoriteSongs();
        favorites = tracks
            .map<MediaItem?>(
                (e) => MediaItemBuilder.fromJson(Map<dynamic, dynamic>.from(e)))
            .whereType<MediaItem>()
            .toList();
      } catch (_) {
        favorites = const [];
      }
    }

    if (favorites.isEmpty) return const [];

    final favoriteArtistNames = favorites
        .map((t) => t.artist ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    if (favoriteArtistNames.isEmpty) return const [];

    final favoriteIds = favorites.map((t) => t.id).toSet();
    final matching = allSongs
        .where(
          (t) =>
              t.artist != null &&
              favoriteArtistNames.contains(t.artist) &&
              !favoriteIds.contains(t.id),
        )
        .toList();

    final source = matching.isEmpty ? favorites : matching;
    return _pickVaried<MediaItem>(
      source,
      10,
      salt: 'favorite-artists',
      keyOf: (t) => t.id,
    );
  }

  List<T> _pickVaried<T>(
    List<T> source,
    int count, {
    required String salt,
    required String Function(T) keyOf,
  }) {
    if (source.isEmpty || count <= 0) return const [];
    final seed = DateTime.now().toUtc().difference(DateTime.utc(2024)).inDays;
    final sorted = List<T>.from(source)
      ..sort((a, b) {
        final ah = Object.hash(seed, salt, keyOf(a));
        final bh = Object.hash(seed, salt, keyOf(b));
        return ah.compareTo(bh);
      });
    return sorted.take(count).toList();
  }

  List<Map<String, dynamic>> _getContentDataInJson(List content,
      {bool isQuickPicks = false}) {
    if (isQuickPicks) {
      return content.toList().map((e) => MediaItemBuilder.toJson(e)).toList();
    } else {
      return content.map((e) {
        if (e.runtimeType == AlbumContent) {
          return (e as AlbumContent).toJson();
        } else {
          return (e as PlaylistContent).toJson();
        }
      }).toList();
    }
  }

  void disposeDetachedScrollControllers({bool disposeAll = false}) {
    final scrollControllersCopy = contentScrollControllers.toList();
    for (final contoller in scrollControllersCopy) {
      if (!contoller.hasClients || disposeAll) {
        contentScrollControllers.remove(contoller);
        contoller.dispose();
      }
    }
  }

  @override
  void dispose() {
    _librarySyncWorker?.dispose();
    disposeDetachedScrollControllers(disposeAll: true);
    super.dispose();
  }
}

class HomeLibrarySections {
  HomeLibrarySections({
    required this.continueListening,
    required this.basedOnFavorites,
    required this.playlistsFromCollection,
    required this.latestAlbums,
    required this.artistsToExplore,
    required this.freshPicks,
    this.favoriteCount = 0,
  });

  final List<MediaItem> continueListening;
  final List<MediaItem> basedOnFavorites;
  final List<Playlist> playlistsFromCollection;
  final List<Album> latestAlbums;
  final List<Artist> artistsToExplore;
  final List<MediaItem> freshPicks;
  final int favoriteCount;

  factory HomeLibrarySections.fromJson(Map<dynamic, dynamic> json) {
    List<MediaItem> parseMediaItems(dynamic value) {
      if (value is! List) return const [];
      return value
          .map<MediaItem?>((e) => MediaItemBuilder.fromJson(e))
          .whereType<MediaItem>()
          .toList();
    }

    List<Playlist> parsePlaylists(dynamic value) {
      if (value is! List) return const [];
      return value
          .map<Playlist?>(
              (e) => Playlist.fromJson(Map<dynamic, dynamic>.from(e)))
          .whereType<Playlist>()
          .toList();
    }

    List<Album> parseAlbums(dynamic value) {
      if (value is! List) return const [];
      return value
          .map<Album?>((e) => Album.fromJson(Map<dynamic, dynamic>.from(e)))
          .whereType<Album>()
          .toList();
    }

    List<Artist> parseArtists(dynamic value) {
      if (value is! List) return const [];
      return value
          .map<Artist?>((e) => Artist.fromJson(Map<dynamic, dynamic>.from(e)))
          .whereType<Artist>()
          .toList();
    }

    return HomeLibrarySections(
      continueListening: parseMediaItems(json["continueListening"]),
      basedOnFavorites: parseMediaItems(json["basedOnFavorites"]),
      playlistsFromCollection: parsePlaylists(json["playlistsFromCollection"]),
      latestAlbums: parseAlbums(json["latestAlbums"]),
      artistsToExplore: parseArtists(json["artistsToExplore"]),
      freshPicks: parseMediaItems(json["freshPicks"]),
      favoriteCount: json["favoriteCount"] is int ? json["favoriteCount"] : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "continueListening":
            continueListening.map((e) => MediaItemBuilder.toJson(e)).toList(),
        "basedOnFavorites":
            basedOnFavorites.map((e) => MediaItemBuilder.toJson(e)).toList(),
        "playlistsFromCollection":
            playlistsFromCollection.map((e) => e.toJson()).toList(),
        "latestAlbums": latestAlbums.map((e) => e.toJson()).toList(),
        "artistsToExplore": artistsToExplore.map((e) => e.toJson()).toList(),
        "freshPicks":
            freshPicks.map((e) => MediaItemBuilder.toJson(e)).toList(),
        "favoriteCount": favoriteCount,
      };
}
