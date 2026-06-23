import 'dart:io';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/scheduler.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/l10n/app_localizations.dart';
import '/models/album.dart';
import '/models/media_Item_builder.dart';
import '/models/playlist.dart';
import '/ui/player/player_controller.dart';
import '/ui/screens/Home/home_screen_controller.dart';
import '/ui/screens/Library/library_controller.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '../utils/helper.dart';
import '../utils/server_storage.dart';

// How long to wait for library controllers to finish fetching
const _maxWaitSeconds = 10;

Future<void> _waitForFlag(RxBool flag, {int timeoutSeconds = _maxWaitSeconds}) async {
  if (flag.value) return;
  for (int i = 0; i < timeoutSeconds * 2; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    if (flag.value) return;
  }
}

class AndroidAutoService extends GetxService {
  final FlutterAndroidAuto _androidAuto = FlutterAndroidAuto();

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    _androidAuto.addListenerOnConnectionChange(_onConnectionChange);
    // Defer template setup until after the first frame so Get.context is available
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _setupRootTemplate();
    });
  }

  void _onConnectionChange(ConnectionStatusTypes status) {
    printINFO('Android Auto connection: $status');
    if (status == ConnectionStatusTypes.connected) {
      _setupRootTemplate();
    }
  }

  Future<void> _setupRootTemplate() async {
    if (Get.context == null) {
      printINFO('AndroidAuto: Get.context is null, deferring template setup');
      return;
    }
    final l10n = AppLocalizations.of(Get.context!)!;
    final sid = currentServerId();
    printINFO('AndroidAuto: setting up root template, serverId=$sid');

    // Wait for library controllers to finish fetching data
    final songsCtrl = Get.find<LibrarySongsController>();
    final albumsCtrl = Get.find<LibraryAlbumsController>();
    final playlistsCtrl = Get.find<LibraryPlaylistsController>();

    printINFO('AndroidAuto: waiting for library controllers to finish fetching...');
    await _waitForFlag(songsCtrl.isSongFetched);
    await _waitForFlag(albumsCtrl.isContentFetched);
    await _waitForFlag(playlistsCtrl.isContentFetched);
    printINFO('AndroidAuto: library controllers ready');

    // Build home tab as a grid of quick picks
    final homeGridButtons = await _loadHomeGridButtons();
    printINFO('AndroidAuto: home grid buttons loaded ${homeGridButtons.length}');

    final albumItems = _albumsToListItems(albumsCtrl.libraryAlbums.toList());
    printINFO('AndroidAuto: albums loaded ${albumItems.length}');

    final playlistItems = _playlistsToListItems(playlistsCtrl.libraryPlaylists.toList());
    printINFO('AndroidAuto: playlists loaded ${playlistItems.length}');

    // Load all songs and favorites for the More tab
    final allSongs = songsCtrl.librarySongsList.toList();
    printINFO('AndroidAuto: all songs for shuffle: ${allSongs.length}');

    final favBox = await Hive.openBox(libFavBoxName(sid));
    final favSongs = <MediaItem>[];
    for (final raw in favBox.values.toList()) {
      final song = MediaItemBuilder.fromJson(raw);
      favSongs.add(song);
    }
    printINFO('AndroidAuto: favorites loaded ${favSongs.length}');

    final homeTab = AAGridTemplate(
      title: l10n.home,
      tabTitle: l10n.home,
      systemIcon: 'house',
      buttons: homeGridButtons,
      emptyViewTitleVariants: ['No content available'],
    );

    final albumsTab = AAListTemplate(
      title: l10n.albums,
      tabTitle: l10n.albums,
      systemIcon: 'square.stack.3d.up',
      sections: [AAListSection(items: albumItems)],
      emptyViewTitleVariants: ['No albums in library'],
    );

    final moreItems = <AAListItem>[
      AAListItem(
        title: l10n.shuffleAll,
        subtitle: '${allSongs.length} songs',
        onPress: (complete, item) {
          Get.find<HomeScreenController>().shuffleAll(
            emptyMessage: l10n.noSongsInLibrary,
            playFromName: l10n.shuffleAll,
          );
          complete();
        },
      ),
      AAListItem(
        title: l10n.favorites,
        subtitle: '${favSongs.length} songs',
        onPress: (complete, item) {
          Get.find<HomeScreenController>().shuffleFavorites(
            emptyMessage: l10n.favoritesEmpty,
            playFromName: l10n.favorites,
          );
          complete();
        },
      ),
      AAListItem(
        title: l10n.playlists,
        subtitle: '${playlistItems.length} playlists',
        isBrowsable: true,
        onPress: (complete, item) async {
          await _openPlaylistsList(playlistItems);
          complete();
        },
      ),
    ];

    final moreTab = AAListTemplate(
      title: l10n.more,
      tabTitle: l10n.more,
      systemIcon: 'ellipsis',
      sections: [AAListSection(items: moreItems)],
      emptyViewTitleVariants: ['Nothing here'],
    );

    await FlutterAndroidAuto.setRootTemplate(
      template: AATabBarTemplate(
        tabs: [homeTab, albumsTab, moreTab],
      ),
    );
    // Don't call forceUpdateRootTemplate — it crashes if native side
    // hasn't fully processed setRootTemplate yet
    printINFO('AndroidAuto: root template set');
  }

  // -- Data loaders --

  /// Load home tab grid buttons from HomeScreenController — aggregates quick
  /// picks, continue listening, fresh picks, and based-on-favorites, same as
  /// the app's home screen. Returns card-like buttons for AAGridTemplate.
  Future<List<AAGridButton>> _loadHomeGridButtons() async {
    try {
      if (!Get.isRegistered<HomeScreenController>()) {
        printINFO('AndroidAuto: HomeScreenController not registered');
        return [];
      }
      final homeCtrl = Get.find<HomeScreenController>();
      // Wait for home content to be fetched (up to 10s)
      await _waitForFlag(homeCtrl.isContentFetched);

      final allSongs = <MediaItem>[];

      // 1. Quick picks (discover content from backend)
      final quickPicks = homeCtrl.quickPicks.value.songList;
      printINFO('AndroidAuto: quick picks: ${quickPicks.length}');
      allSongs.addAll(quickPicks);

      // 2. Home library sections (continue listening, fresh picks, etc.)
      try {
        final sections = await homeCtrl.loadHomeLibrarySections();
        printINFO('AndroidAuto: sections - continueListening=${sections.continueListening.length}, freshPicks=${sections.freshPicks.length}, basedOnFavorites=${sections.basedOnFavorites.length}, favoriteSongs=${sections.favoriteSongs.length}');

        // Add continue listening first (most relevant)
        for (final item in sections.continueListening) {
          if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
        }
        // Then fresh picks
        for (final item in sections.freshPicks) {
          if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
        }
        // Based on favorites
        for (final item in sections.basedOnFavorites) {
          if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
        }
        // Favorite songs
        for (final item in sections.favoriteSongs) {
          if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
        }
      } catch (e) {
        printWarning('AndroidAuto: loadHomeLibrarySections failed: $e');
      }

      printINFO('AndroidAuto: total home items: ${allSongs.length}');
      if (allSongs.isEmpty) return [];

      return allSongs.map((song) => AAGridButton(
        titleVariants: [song.title],
        image: song.artUri?.toString(),
        onPress: (complete, self) {
          _playSongs([song], 0);
          complete();
          return Future.value();
        },
      )).toList();
    } catch (e) {
      printWarning('AndroidAuto: _loadHomeGridButtons failed: $e');
      return [];
    }
  }

  List<AAListItem> _albumsToListItems(List<Album> albums) {
    return albums.map((album) {
      return AAListItem(
        title: album.title,
        subtitle: album.artists?.map((a) => a['name'] ?? '').join(', ') ?? '',
        imageUrl: album.thumbnailUrl.isNotEmpty
            ? album.thumbnailUrl
            : null,
        isBrowsable: true,
        onPress: (complete, item) async {
          await _openAlbumSongs(album.browseId, album.title);
          complete();
        },
      );
    }).toList();
  }

  List<AAListItem> _playlistsToListItems(List<Playlist> playlists) {
    return playlists.map((pl) {
      return AAListItem(
        title: pl.title,
        subtitle: (pl.songCount != null && pl.songCount!.isNotEmpty)
            ? '${pl.songCount} songs'
            : '',
        imageUrl:
            pl.thumbnailUrl.isNotEmpty ? pl.thumbnailUrl : null,
        isBrowsable: true,
        onPress: (complete, item) async {
          await _openPlaylistSongs(pl.playlistId, pl.title);
          complete();
        },
      );
    }).toList();
  }

  // -- Navigation helpers --

  Future<void> _openPlaylistsList(List<AAListItem> playlistItems) async {
    final l10n = AppLocalizations.of(Get.context!)!;
    printINFO('AndroidAuto: opening playlists list (${playlistItems.length})');

    if (playlistItems.isEmpty) {
      await FlutterAndroidAuto.push(
        template: AAMessageTemplate(
          title: l10n.playlists,
          message: 'No playlists available.',
        ),
      );
      return;
    }

    await FlutterAndroidAuto.push(
      template: AAListTemplate(
        title: l10n.playlists,
        sections: [
          AAListSection(items: playlistItems),
        ],
        emptyViewTitleVariants: ['No playlists available'],
      ),
    );
  }

  Future<void> _openAlbumSongs(String albumId, String title) async {
    printINFO('AndroidAuto: opening album $albumId ($title)');
    final songs = await _fetchAlbumOrPlaylistSongs(albumId: albumId);
    printINFO('AndroidAuto: album $albumId fetched ${songs.length} songs');
    if (songs.isEmpty) {
      await FlutterAndroidAuto.push(
        template: AAMessageTemplate(
          title: title,
          message: 'No songs found for this album.',
        ),
      );
      return;
    }

    await FlutterAndroidAuto.push(
      template: AAListTemplate(
        title: title,
        sections: [
          AAListSection(
            items: songs.map((song) {
              return AAListItem(
                title: song.title,
                subtitle: song.artist ?? '',
                imageUrl: song.artUri?.toString(),
                onPress: (complete, item) {
                  _playSongs(songs, songs.indexOf(song));
                  complete();
                },
              );
            }).toList(),
          ),
        ],
        emptyViewTitleVariants: ['No songs in this album'],
      ),
    );
  }

  Future<void> _openPlaylistSongs(String playlistId, String title) async {
    printINFO('AndroidAuto: opening playlist $playlistId ($title)');
    final songs = await _fetchAlbumOrPlaylistSongs(playlistId: playlistId);
    printINFO('AndroidAuto: playlist $playlistId fetched ${songs.length} songs');
    if (songs.isEmpty) {
      await FlutterAndroidAuto.push(
        template: AAMessageTemplate(
          title: title,
          message: 'No songs found for this playlist.',
        ),
      );
      return;
    }

    await FlutterAndroidAuto.push(
      template: AAListTemplate(
        title: title,
        sections: [
          AAListSection(
            items: songs.map((song) {
              return AAListItem(
                title: song.title,
                subtitle: song.artist ?? '',
                imageUrl: song.artUri?.toString(),
                onPress: (complete, item) {
                  _playSongs(songs, songs.indexOf(song));
                  complete();
                },
              );
            }).toList(),
          ),
        ],
        emptyViewTitleVariants: ['No songs in this playlist'],
      ),
    );
  }

  // -- Data fetching --

  Future<List<MediaItem>> _fetchAlbumOrPlaylistSongs({
    String? albumId,
    String? playlistId,
  }) async {
    // Try local Hive box first (cached album/playlist songs)
    final id = albumId ?? playlistId;
    if (id != null && await Hive.boxExists(id)) {
      try {
        final box = await Hive.openBox(id);
        final songs = box.values
            .map((item) => MediaItemBuilder.fromJson(item))
            .whereType<MediaItem>()
            .toList();
        // Don't close — might be cached and used elsewhere
        if (songs.isNotEmpty) return songs;
      } catch (e) {
        printWarning('AndroidAuto: failed to load local box $id: $e');
      }
    }

    // Fall back to backend
    try {
      final settings = Get.find<SettingsScreenController>();
      final backend = settings.currentBackend;
      final result = await backend.getPlaylistOrAlbumSongs(
        albumId: albumId,
        playlistId: playlistId,
      );
      final tracks = (result['tracks'] as List?) ?? [];
      return tracks
          .map((item) => MediaItemBuilder.fromJson(item))
          .whereType<MediaItem>()
          .toList();
    } catch (e) {
      printWarning('AndroidAuto: failed to fetch songs from backend: $e');
      return [];
    }
  }

  // -- Playback --

  void _playSongs(List<MediaItem> songs, int index) {
    if (songs.isEmpty || index < 0 || index >= songs.length) return;
    printINFO('AndroidAuto: playing song at index $index of ${songs.length}');
    final player = Get.find<PlayerController>();
    player.playPlayListSong(songs, index);
  }

  @override
  void onClose() {
    _androidAuto.removeListenerOnConnectionChange();
    super.onClose();
  }
}
