part of 'audio_handler.dart';

class MediaLibrary {
  static const albumsRootId = 'albums';
  static const songsRootId = 'songs';
  static const favoritesRootId = "LIBFAV";
  static const playlistsRootId = 'playlists';
  static const recentlyPlayedRootId = 'recentlyPlayed';

  static const homeRootId = 'home';
  static const moreRootId = 'more';
  static const morePlaylistsId = 'more_playlists';
  static const moreShuffleAllId = 'more_shuffleAll';
  static const moreFavoritesId = 'more_favorites';
  static const moreSettingsId = 'more_settings';
  static const moreSettingsServersId = 'more_settings_servers';
  static const moreSettingsAboutId = 'more_settings_about';

  // Track the last browsed album/playlist so playFromMediaId knows
  // which song list to queue up
  String _lastBrowseId = '';

  Future<List<MediaItem>> getByRootId(String id) async {
    printINFO('MediaLibrary: getByRootId "$id"');
    switch (id) {
      case AudioService.browsableRootId:
        return Future.value(getRoot());
      case homeRootId:
        _lastBrowseId = homeRootId;
        return getHomeItems();
      case songsRootId:
        _lastBrowseId = songsRootId;
        return getSongs();
      case favoritesRootId:
        _lastBrowseId = favoritesRootId;
        return getLibSongs(libFavBoxName(currentServerId()));
      case albumsRootId:
        _lastBrowseId = albumsRootId;
        return getAlbums();
      case moreRootId:
        return getMoreMenu();
      case morePlaylistsId:
        _lastBrowseId = morePlaylistsId;
        return getPlaylists();
      case moreSettingsId:
        return getSettingsMenu();
      case moreSettingsServersId:
        return getServersList();
      case moreSettingsAboutId:
        return getAboutInfo();
      case playlistsRootId:
        _lastBrowseId = playlistsRootId;
        return getPlaylists();
      case recentlyPlayedRootId:
        _lastBrowseId = recentlyPlayedRootId;
        return getLibSongs(recentlyPlayedBoxName(currentServerId()));
      case AudioService.recentRootId:
        _lastBrowseId = recentlyPlayedRootId;
        return getLibSongs(recentlyPlayedBoxName(currentServerId()));
      default:
        // Browsing into a specific album/playlist — track it
        _lastBrowseId = id;
        return getLibSongs(id).then((songs) async {
          if (songs.isNotEmpty) return songs;
          return _fetchFromBackend(id);
        });
    }
  }

  List<MediaItem> getRoot() {
    final ctx = Get.context;
    if (ctx == null) {
      return [
        const MediaItem(id: homeRootId, title: 'Home', playable: false),
        const MediaItem(id: albumsRootId, title: 'Albums', playable: false),
        const MediaItem(id: moreRootId, title: 'More', playable: false),
      ];
    }
    final l10n = AppLocalizations.of(ctx)!;
    return [
      MediaItem(id: homeRootId, title: l10n.home, playable: false),
      MediaItem(id: albumsRootId, title: l10n.albums, playable: false),
      MediaItem(id: moreRootId, title: l10n.more, playable: false),
    ];
  }

  /// More menu — shows Shuffle All, Favorites, Playlists, and Settings
  List<MediaItem> getMoreMenu() {
    final ctx = Get.context;
    final l10n = ctx != null ? AppLocalizations.of(ctx)! : null;
    return [
      MediaItem(
        id: moreShuffleAllId,
        title: l10n?.shuffleAll ?? 'Shuffle all',
        playable: true,
      ),
      MediaItem(
        id: moreFavoritesId,
        title: l10n?.favorites ?? 'Favourites',
        playable: true,
      ),
      MediaItem(
        id: morePlaylistsId,
        title: l10n?.playlists ?? 'Playlists',
        playable: false,
      ),
      MediaItem(
        id: moreSettingsId,
        title: l10n?.settings ?? 'Settings',
        playable: false,
      ),
    ];
  }

  /// Settings submenu — Servers and About
  List<MediaItem> getSettingsMenu() {
    final ctx = Get.context;
    final l10n = ctx != null ? AppLocalizations.of(ctx)! : null;
    return [
      MediaItem(
        id: moreSettingsServersId,
        title: l10n?.servers ?? 'Servers',
        playable: false,
      ),
      MediaItem(
        id: moreSettingsAboutId,
        title: l10n?.about ?? 'About',
        playable: false,
      ),
    ];
  }

  /// Servers list — allows switching active server (read-only, no add/edit/remove)
  List<MediaItem> getServersList() {
    final settings = Get.find<SettingsScreenController>();
    final activeId = settings.activeServerId.value;
    return settings.servers.map((s) {
      final isActive = s.id == activeId;
      final title = isActive ? '${s.name} ✓' : s.name;
      final subtitle = s.serverUrl ?? s.type.name;
      return MediaItem(
        id: 'server_switch_${s.id}',
        title: title,
        artist: subtitle,
        playable: true,
      );
    }).toList();
  }

  /// About info — pulled from SettingsScreenController
  List<MediaItem> getAboutInfo() {
    final settings = Get.find<SettingsScreenController>();
    final activeServer = settings.activeServer;
    final ctx = Get.context;
    final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
    return [
      MediaItem(
        id: 'about_app_name',
        title: 'Doudou',
        artist: 'v${settings.currentVersion}',
        playable: true,
      ),
      MediaItem(
        id: 'about_active_server',
        title: l10n?.servers ?? 'Servers',
        artist: activeServer?.name ?? 'None',
        playable: true,
      ),
      MediaItem(
        id: 'about_server_type',
        title: 'Server type',
        artist: activeServer?.type.name ?? 'Unknown',
        playable: true,
      ),
    ];
  }

  /// Pull home items from HomeScreenController — aggregates quick picks,
  /// continue listening, fresh picks, and based-on-favorites, same as
  /// the app's home screen.
  Future<List<MediaItem>> getHomeItems() async {
    try {
      if (Get.isRegistered<HomeScreenController>()) {
        final homeCtrl = Get.find<HomeScreenController>();
        for (int i = 0; i < 20; i++) {
          if (homeCtrl.isContentFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final allSongs = <MediaItem>[];

        // 1. Quick picks (discover content from backend)
        final quickPicks = homeCtrl.quickPicks.value.songList;
        printINFO('MediaLibrary: getHomeItems quick picks: ${quickPicks.length}');
        allSongs.addAll(quickPicks);

        // 2. Home library sections
        try {
          final sections = await homeCtrl.loadHomeLibrarySections();
          printINFO('MediaLibrary: getHomeItems sections - continueListening=${sections.continueListening.length}, freshPicks=${sections.freshPicks.length}, basedOnFavorites=${sections.basedOnFavorites.length}');

          // Skip continueListening (recently played) — too much space in car UI
          for (final item in sections.freshPicks) {
            if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
          }
          for (final item in sections.basedOnFavorites) {
            if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
          }
          for (final item in sections.favoriteSongs) {
            if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
          }
        } catch (e) {
          printWarning('MediaLibrary: getHomeItems sections failed: $e');
        }

        printINFO('MediaLibrary: getHomeItems total: ${allSongs.length}');
        if (allSongs.isNotEmpty) {
          return allSongs.map((s) => MediaItem(
            id: s.id,
            title: s.title,
            artist: s.artist,
            artUri: s.artUri,
            extras: {'libraryId': songDownloadsBoxName(currentServerId())},
            playable: true,
          )).toList();
        }
      }
    } catch (e) {
      printWarning('MediaLibrary: getHomeItems failed: $e');
    }
    // Fallback to songs
    return getSongs();
  }

  /// Pull songs from LibrarySongsController's in-memory list —
  /// this has both backend-fetched and local songs merged together.
  Future<List<MediaItem>> getSongs() async {
    try {
      if (Get.isRegistered<LibrarySongsController>()) {
        final ctrl = Get.find<LibrarySongsController>();
        // Wait for fetch to complete (up to 10s)
        for (int i = 0; i < 20; i++) {
          if (ctrl.isSongFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        final songs = ctrl.librarySongsList.toList();
        printINFO('MediaLibrary: getSongs from controller: ${songs.length}');
        return songs.map((s) => MediaItem(
          id: s.id,
          title: s.title,
          artist: s.artist,
          artUri: s.artUri,
          extras: {'libraryId': songDownloadsBoxName(currentServerId())},
          playable: true,
        )).toList();
      }
    } catch (e) {
      printWarning('MediaLibrary: getSongs from controller failed: $e');
    }
    // Fallback to Hive box
    return getLibSongs(songDownloadsBoxName(currentServerId()));
  }

  Future<List<MediaItem>> getAlbums() async {
    try {
      if (Get.isRegistered<LibraryAlbumsController>()) {
        final ctrl = Get.find<LibraryAlbumsController>();
        for (int i = 0; i < 20; i++) {
          if (ctrl.isContentFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        final albums = ctrl.libraryAlbums.toList();
        printINFO('MediaLibrary: getAlbums from controller: ${albums.length}');
        return albums.map((a) => a.toMediaItem()).toList();
      }
    } catch (e) {
      printWarning('MediaLibrary: getAlbums from controller failed: $e');
    }
    // Fallback to Hive box
    final box = await Hive.openBox(libraryAlbumsBoxName(currentServerId()));
    final albums =
        box.values.map((item) => Album.fromJson(item).toMediaItem()).toList();
    printINFO('MediaLibrary: getAlbums from box: ${albums.length}');
    return albums;
  }

  Future<List<MediaItem>> getPlaylists() async {
    try {
      if (Get.isRegistered<LibraryPlaylistsController>()) {
        final ctrl = Get.find<LibraryPlaylistsController>();
        for (int i = 0; i < 20; i++) {
          if (ctrl.isContentFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        // Filter out LIBFAV — Favorites has its own button in the More menu
        final playlists = ctrl.libraryPlaylists
            .where((p) => p.playlistId != 'LIBFAV')
            .toList();
        printINFO('MediaLibrary: getPlaylists from controller: ${playlists.length}');
        return playlists.map((p) => p.toMediaItem()).toList();
      }
    } catch (e) {
      printWarning('MediaLibrary: getPlaylists from controller failed: $e');
    }
    // Fallback to Hive box
    final box = await Hive.openBox("LibraryPlaylists");
    final prefix = 's_${currentServerId()}_';
    final serverKeys = box.keys
        .where((k) => k is String && k.toString().startsWith(prefix))
        .toList();
    final playlists = [
      ...Get.find<LibraryPlaylistsController>()
          .initPlst
          .where((e) => e.playlistId != 'LIBFAV')
          .map((e) => e.toMediaItem()),
      ...serverKeys.map((k) => box.get(k.toString())).whereType<Map>().map(
          (item) =>
              Playlist.fromJson(Map<dynamic, dynamic>.from(item)).toMediaItem())
    ];
    printINFO('MediaLibrary: getPlaylists from box: ${playlists.length}');
    return playlists;
  }

  Future<List<MediaItem>> getLibSongs(String libId) async {
    Box<dynamic> box;
    try {
      box = await Hive.openBox(libId);
    } catch (e) {
      box = await Hive.openBox(libId);
    }
    final songs = box.values.toList().map((e) {
      final song = MediaItemBuilder.fromJson(e);
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artUri: song.artUri,
        extras: {"libraryId": libId},
        playable: true,
      );
    }).toList();

    // Don't close — boxes are shared with library controllers

    if (libId == "LIBRP" || libId.startsWith("LIBRP_s_")) {
      return songs.reversed.toList();
    }

    printINFO('MediaLibrary: getLibSongs from $libId: ${songs.length}');
    return songs;
  }

  /// Fetch album/playlist songs from backend when not cached locally
  Future<List<MediaItem>> _fetchFromBackend(String id) async {
    try {
      final settings = Get.find<SettingsScreenController>();
      final backend = settings.currentBackend;
      final result = await backend.getPlaylistOrAlbumSongs(
        albumId: id,
        playlistId: id,
      );
      final tracks = (result['tracks'] as List?) ?? [];
      final songs = tracks
          .map((item) => MediaItemBuilder.fromJson(item))
          .whereType<MediaItem>()
          .map((song) => MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            artUri: song.artUri,
            extras: {'libraryId': id},
            playable: true,
          ))
          .toList();
      printINFO('MediaLibrary: _fetchFromBackend for $id: ${songs.length}');
      return songs;
    } catch (e) {
      printWarning('MediaLibrary: _fetchFromBackend failed for $id: $e');
      return [];
    }
  }
}
