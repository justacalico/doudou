import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/models/media_item_builder.dart';
import '/models/playlist.dart';
import '/models/server.dart';
import '/services/backend/music_backend.dart';
import '/ui/player/player_controller.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/utils/server_storage.dart';

/// Everything the MCP server can reach inside the running app.
///
/// The interface is deliberately free of GetX, Hive and player types so the
/// tool surface (`mcp_toolset.dart`) and its tests only need a fake bridge.
/// [GetxMcpAppBridge] is the real implementation, resolving app services
/// lazily so nothing is constructed before a tool actually needs it.
abstract class McpAppBridge {
  Map<String, Object?> playbackState();
  Map<String, Object?> queueState();

  Future<void> play();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(int positionMs);
  Future<void> setVolume(int volume);
  Future<void> setShuffle(bool enabled);

  /// [mode] is one of `off`, `one`, `all`.
  Future<void> setRepeat(String mode);

  Future<void> playQueueIndex(int index);
  Future<void> removeQueueIndex(int index);
  Future<void> clearQueue();

  /// Plays [song] (a MediaItemBuilder-compatible json map) immediately,
  /// replacing the queue like tapping a search result does.
  Future<void> playSong(Map<String, Object?> song, {bool radio = false});

  /// Appends [song] to the queue. Returns its queue index.
  Future<int> enqueueSong(Map<String, Object?> song);

  /// Inserts [song] right after the current item. Returns its queue index.
  Future<int> playNextSong(Map<String, Object?> song);

  /// Toggles the favourite flag of the current song. Returns the new state,
  /// or null when nothing is playing.
  Future<bool?> toggleFavorite();

  Future<Map<String, Object?>> search(String query,
      {String? filter, int limit = 10});

  Future<List<Map<String, Object?>>> listPlaylists();

  Future<Map<String, Object?>> getPlaylistOrAlbumSongs(
      {String? playlistId, String? albumId, int limit = 100});
}

/// Recursively converts a value into something `jsonEncode` accepts.
/// [MediaItem]s become their MediaItemBuilder json form (which already
/// scrubs credentials from urls); unknown objects degrade to their string
/// form instead of crashing the whole result.
Object? sanitizeMcpJson(Object? value, {int depth = 0}) {
  if (depth > 16) return null;
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is MediaItem) {
    return sanitizeMcpJson(MediaItemBuilder.toJson(value), depth: depth + 1);
  }
  if (value is Map) {
    final out = <String, Object?>{};
    value.forEach((key, entry) {
      if (key == null) return;
      out[key.toString()] = sanitizeMcpJson(entry, depth: depth + 1);
    });
    return out;
  }
  if (value is Iterable) {
    return value.map((e) => sanitizeMcpJson(e, depth: depth + 1)).toList();
  }
  return value.toString();
}

/// Built-in local playlists shown on the library screen, in display order.
/// Their songs live in per-server Hive boxes rather than on the music
/// server, so the bridge resolves them locally.
const _builtinPlaylists = [
  (id: 'LIBRP', title: 'Recently Played'),
  (id: 'LIBFAV', title: 'Favourites'),
  (id: 'SongsCache', title: 'Cached/Offline'),
  (id: 'SongDownloads', title: 'Downloads'),
];

class GetxMcpAppBridge implements McpAppBridge {
  AudioHandler get _audio => Get.find<AudioHandler>();
  PlayerController get _player => Get.find<PlayerController>();
  MusicBackend get _backend =>
      Get.find<SettingsScreenController>().currentBackend;
  Box get _prefs => Hive.box('AppPrefs');

  bool get _isYouTubeMusic =>
      Get.find<SettingsScreenController>().activeServer?.type ==
      ServerType.youtubeMusic;

  Map<String, Object?> _songJson(MediaItem item) => {
        'id': item.id,
        'title': item.title,
        'artist': item.artist,
        'album': item.album,
        'duration_ms': item.duration?.inMilliseconds,
        'thumbnail_url': item.artUri?.toString(),
      };

  int get _currentVolume {
    if (Get.isRegistered<PlayerController>()) {
      return _player.volume.value;
    }
    final stored = _prefs.get('volume');
    return stored is int ? stored : 100;
  }

  String get _repeatMode {
    if (_prefs.get('isLoopModeEnabled') == true) return 'one';
    if (_prefs.get('queueLoopModeEnabled') == true) return 'all';
    return 'off';
  }

  @override
  Map<String, Object?> playbackState() {
    final state = _audio.playbackState.value;
    final item = _audio.mediaItem.value;
    return {
      'playing': state.playing,
      'processing_state': state.processingState.name,
      'position_ms': state.updatePosition.inMilliseconds,
      'buffered_ms': state.bufferedPosition.inMilliseconds,
      'volume': _currentVolume,
      'shuffle': _prefs.get('isShuffleModeEnabled') == true,
      'repeat_mode': _repeatMode,
      'queue_index': state.queueIndex,
      'queue_length': _audio.queue.value.length,
      'song': item == null ? null : _songJson(item),
    };
  }

  @override
  Map<String, Object?> queueState() {
    final queue = _audio.queue.value;
    final current = _audio.playbackState.value.queueIndex;
    return {
      'queue_index': current,
      'length': queue.length,
      'items': [
        for (var i = 0; i < queue.length; i++)
          {
            'index': i,
            'current': i == current,
            ..._songJson(queue[i]),
          }
      ],
    };
  }

  @override
  Future<void> play() => _audio.play();

  @override
  Future<void> pause() => _audio.pause();

  @override
  Future<void> next() => _audio.skipToNext();

  @override
  Future<void> previous() => _audio.skipToPrevious();

  @override
  Future<void> seek(int positionMs) =>
      _audio.seek(Duration(milliseconds: positionMs));

  @override
  Future<void> setVolume(int volume) => _player.setVolume(volume);

  @override
  Future<void> setShuffle(bool enabled) async {
    await _audio.setShuffleMode(enabled
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none);
    await _prefs.put('isShuffleModeEnabled', enabled);
    if (Get.isRegistered<PlayerController>()) {
      _player.isShuffleModeEnabled.value = enabled;
    }
  }

  @override
  Future<void> setRepeat(String mode) async {
    await _audio.setRepeatMode(mode == 'one'
        ? AudioServiceRepeatMode.one
        : AudioServiceRepeatMode.none);
    await _audio
        .customAction('toggleQueueLoopMode', {'enable': mode == 'all'});
    await _prefs.put('isLoopModeEnabled', mode == 'one');
    await _prefs.put('queueLoopModeEnabled', mode == 'all');
    if (Get.isRegistered<PlayerController>()) {
      _player.isLoopModeEnabled.value = mode == 'one';
      _player.isQueueLoopModeEnabled.value = mode == 'all';
    }
  }

  @override
  Future<void> playQueueIndex(int index) => _audio.skipToQueueItem(index);

  @override
  Future<void> removeQueueIndex(int index) async {
    final queue = _audio.queue.value;
    if (index < 0 || index >= queue.length) {
      throw ArgumentError('Queue index $index out of range');
    }
    await _audio.removeQueueItem(queue[index]);
  }

  @override
  Future<void> clearQueue() => _audio.customAction('clearQueue');

  @override
  Future<void> playSong(Map<String, Object?> song, {bool radio = false}) {
    final item = MediaItemBuilder.fromJson(song);
    if (_isYouTubeMusic) {
      return _player.pushSongToQueue(item, radio: radio);
    }
    // Watch-playlist queues are a YouTube Music concept; other backends play
    // the single item directly.
    return _player.playPlayListSong([item], 0);
  }

  @override
  Future<int> enqueueSong(Map<String, Object?> song) async {
    final item = MediaItemBuilder.fromJson(song);
    await _player.enqueueSong(item);
    return _audio.queue.value.indexWhere((e) => e.id == item.id);
  }

  @override
  Future<int> playNextSong(Map<String, Object?> song) async {
    final item = MediaItemBuilder.fromJson(song);
    _player.playNext(item);
    final index = _audio.queue.value.indexWhere((e) => e.id == item.id);
    if (index >= 0) return index;
    return (_audio.playbackState.value.queueIndex ?? -1) + 1;
  }

  @override
  Future<bool?> toggleFavorite() async {
    if (_player.currentSong.value == null) return null;
    await _player.toggleFavourite();
    return _player.isCurrentSongFav.value;
  }

  @override
  Future<Map<String, Object?>> search(String query,
      {String? filter, int limit = 10}) async {
    final raw = await _backend.search(query, filter: filter, limit: limit);
    final out = <String, Object?>{};
    raw.forEach((key, value) {
      if (value is List) {
        out[key.toString()] =
            value.take(limit).map(sanitizeMcpJson).toList();
      }
    });
    return out;
  }

  Future<Box> _openBox(String name) =>
      Hive.isBoxOpen(name) ? Future.value(Hive.box(name)) : Hive.openBox(name);

  @override
  Future<List<Map<String, Object?>>> listPlaylists() async {
    final serverId = currentServerId();
    final builtin = <Map<String, Object?>>[
      for (final p in _builtinPlaylists)
        Playlist(
          title: p.title,
          playlistId: p.id,
          thumbnailUrl: Playlist.thumbPlaceholderUrl,
          isCloudPlaylist: false,
          songCount:
              (await _openBox(builtinPlaylistSongsBoxName(serverId, p.id)!))
                  .length
                  .toString(),
        ).toJson(),
    ];
    final playlists = await _backend.getLibraryPlaylists();
    return [
      ...builtin,
      ...playlists.map((p) =>
          Map<String, Object?>.from(sanitizeMcpJson(p.toJson()) as Map)),
    ];
  }

  /// Songs of a built-in playlist read from its Hive box, or null when
  /// [playlistId] is not a built-in id.
  Future<Map<String, Object?>?> _builtinPlaylistSongs(
      String playlistId) async {
    final boxName = builtinPlaylistSongsBoxName(currentServerId(), playlistId);
    if (boxName == null) return null;
    final box = await _openBox(boxName);
    var tracks = box.values.map(MediaItemBuilder.fromJson).toList();
    // Recently played is stored oldest first; the app lists it newest first.
    if (playlistId == 'LIBRP') tracks = tracks.reversed.toList();
    return {'playlistId': playlistId, 'tracks': tracks};
  }

  @override
  Future<Map<String, Object?>> getPlaylistOrAlbumSongs(
      {String? playlistId, String? albumId, int limit = 100}) async {
    final raw = (playlistId == null
            ? null
            : await _builtinPlaylistSongs(playlistId)) ??
        await _backend.getPlaylistOrAlbumSongs(
            playlistId: playlistId, albumId: albumId, limit: limit);
    final sanitized = sanitizeMcpJson(raw);
    if (sanitized is! Map) return const {};
    final out = Map<String, Object?>.from(sanitized);
    out.forEach((key, value) {
      if (value is List && value.length > limit) {
        out[key] = value.take(limit).toList();
      }
    });
    return out;
  }
}
