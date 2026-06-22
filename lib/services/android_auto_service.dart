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

    // Pull from in-memory lists — these already have backend + local data
    final songItems = _songsToListItems(songsCtrl.librarySongsList.toList());
    printINFO('AndroidAuto: songs loaded ${songItems.length}');

    final recentItems = await _loadSongItems(recentlyPlayedBoxName(sid));
    printINFO('AndroidAuto: recent loaded ${recentItems.length}');

    final albumItems = _albumsToListItems(albumsCtrl.libraryAlbums.toList());
    printINFO('AndroidAuto: albums loaded ${albumItems.length}');

    final playlistItems = _playlistsToListItems(playlistsCtrl.libraryPlaylists.toList());
    printINFO('AndroidAuto: playlists loaded ${playlistItems.length}');

    final songsTab = AAListTemplate(
      title: l10n.songs,
      tabTitle: l10n.songs,
      systemIcon: 'music.note',
      sections: [AAListSection(items: songItems)],
      emptyViewTitleVariants: ['No songs available'],
    );

    final recentTab = AAListTemplate(
      title: l10n.recentlyPlayed,
      tabTitle: l10n.recentlyPlayed,
      systemIcon: 'clock',
      sections: [AAListSection(items: recentItems)],
      emptyViewTitleVariants: ['Nothing played recently'],
    );

    final albumsTab = AAListTemplate(
      title: l10n.albums,
      tabTitle: l10n.albums,
      systemIcon: 'square.stack.3d.up',
      sections: [AAListSection(items: albumItems)],
      emptyViewTitleVariants: ['No albums in library'],
    );

    final playlistsTab = AAListTemplate(
      title: l10n.playlists,
      tabTitle: l10n.playlists,
      systemIcon: 'music.note.list',
      sections: [AAListSection(items: playlistItems)],
      emptyViewTitleVariants: ['No playlists available'],
    );

    await FlutterAndroidAuto.setRootTemplate(
      template: AATabBarTemplate(
        tabs: [songsTab, recentTab, albumsTab, playlistsTab],
      ),
    );
    // Don't call forceUpdateRootTemplate — it crashes if native side
    // hasn't fully processed setRootTemplate yet
    printINFO('AndroidAuto: root template set');
  }

  // -- Data loaders --

  /// Load songs from a Hive box (used for favorites and recently played
  /// which don't have dedicated controllers with in-memory lists).
  Future<List<AAListItem>> _loadSongItems(String boxName) async {
    Box<dynamic> box;
    try {
      box = await Hive.openBox(boxName);
    } catch (_) {
      box = await Hive.openBox(boxName);
    }

    final songs = <MediaItem>[];
    for (final raw in box.values.toList()) {
      final song = MediaItemBuilder.fromJson(raw);
      songs.add(MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artUri: song.artUri,
        extras: {'libraryId': boxName},
        playable: true,
      ));
    }

    // Don't close — boxes are shared with library controllers and audio_handler

    if (boxName == 'LIBRP' || boxName.startsWith('LIBRP_s_')) {
      return _songsToListItems(songs.reversed.toList());
    }

    return _songsToListItems(songs);
  }

  List<AAListItem> _songsToListItems(List<MediaItem> songs) {
    return songs.map((song) {
      return AAListItem(
        title: song.title,
        subtitle: song.artist ?? '',
        imageUrl: song.artUri?.toString(),
        onPress: (complete, item) {
          _playSongs(songs, songs.indexOf(song));
          complete();
        },
      );
    }).toList();
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
