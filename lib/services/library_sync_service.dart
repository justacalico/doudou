import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/models/album.dart';
import '/models/artist.dart';
import '/models/media_Item_builder.dart';
import '/models/playlist.dart';
import '/models/server.dart';
import '/services/backend/backend_factory.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/utils/helper.dart';
import '/utils/server_storage.dart';

enum LibraryKind { songs, playlists, albums, artists }

class LibrarySyncService extends GetxService {
  static const Duration _syncInterval = Duration(minutes: 30);

  // Backward-compatible aggregate fields.
  final syncVersion = 0.obs;
  final isSyncing = false.obs;
  final lastSyncTimeMs = RxnInt();
  final lastError = ''.obs;

  // Per-library sync state.
  final syncVersionByKind = <LibraryKind, int>{}.obs;
  final isSyncingByKind = <LibraryKind, bool>{}.obs;
  final lastSuccessMsByKind = <LibraryKind, int?>{}.obs;
  final lastErrorByKind = <LibraryKind, String>{}.obs;

  Timer? _timer;
  final _syncInProgressByKind = <LibraryKind, bool>{};
  late final Worker _activeServerWorker;

  @override
  void onInit() {
    super.onInit();
    _initMaps();
    _activeServerWorker = ever(
      Get.find<SettingsScreenController>().activeServerId,
      (_) {
        _loadCurrentServerSyncMeta();
        maybeSyncIfStale();
      },
    );
    _loadCurrentServerSyncMeta();
    _startPeriodicSync();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _activeServerWorker.dispose();
    super.onClose();
  }

  void _initMaps() {
    for (final kind in LibraryKind.values) {
      syncVersionByKind[kind] = 0;
      isSyncingByKind[kind] = false;
      lastSuccessMsByKind[kind] = null;
      lastErrorByKind[kind] = '';
      _syncInProgressByKind[kind] = false;
    }
  }

  Future<void> onAppResumed() async {
    await maybeSyncIfStale();
  }

  // Compatibility: sync all libraries if stale.
  Future<void> maybeSyncIfStale() async {
    await maybeSyncAllIfStale();
  }

  Future<void> maybeSyncAllIfStale() async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server == null || server.type == ServerType.youtubeMusic) return;

    await Future.wait(
      LibraryKind.values.map(maybeSyncKindIfStale),
    );
  }

  Future<void> maybeSyncKindIfStale(LibraryKind kind) async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server == null || server.type == ServerType.youtubeMusic) return;

    final metaBox = await _openMetaBox(server.id);
    final key = _metaKey(kind, 'lastSuccessMs');
    final lastSuccessMs = metaBox.get(key);
    if (lastSuccessMs is! int) {
      await syncKind(kind, force: true);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - lastSuccessMs;
    if (age >= _syncInterval.inMilliseconds) {
      await syncKind(kind);
    }
  }

  // Compatibility: sync all kinds.
  Future<void> syncNow({bool force = false}) async {
    await syncAll(force: force);
  }

  Future<void> syncAll({bool force = false}) async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server == null || server.type == ServerType.youtubeMusic) return;

    await Future.wait(
      LibraryKind.values.map((kind) => syncKind(kind, force: force)),
    );
    _updateAggregateStatus();
  }

  Future<void> syncKind(LibraryKind kind, {bool force = false}) async {
    if (_syncInProgressByKind[kind] == true) return;

    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server == null || server.type == ServerType.youtubeMusic) return;

    _syncInProgressByKind[kind] = true;
    isSyncingByKind[kind] = true;
    _updateAggregateStatus();

    try {
      final metaBox = await _openMetaBox(server.id);
      final now = DateTime.now().millisecondsSinceEpoch;
      await metaBox.put(_metaKey(kind, 'lastAttemptMs'), now);

      if (!force) {
        final lastSuccessMs = metaBox.get(_metaKey(kind, 'lastSuccessMs'));
        if (lastSuccessMs is int &&
            now - lastSuccessMs < _syncInterval.inMilliseconds) {
          _syncInProgressByKind[kind] = false;
          isSyncingByKind[kind] = false;
          _updateAggregateStatus();
          return;
        }
      }

      final backend = createBackend(server);
      switch (kind) {
        case LibraryKind.songs:
          final songs = await backend.getLibrarySongs();
          await _replaceBoxValues(
            await _openCacheBox(librarySongsCacheBoxName(server.id)),
            songs,
          );
          break;
        case LibraryKind.playlists:
          final playlists = await backend.getLibraryPlaylists();
          await _replaceBoxValues(
            await _openCacheBox(libraryPlaylistsCacheBoxName(server.id)),
            playlists.map((e) => e.toJson()).toList(),
          );
          break;
        case LibraryKind.albums:
          final albums = await backend.getLibraryAlbums();
          await _replaceBoxValues(
            await _openCacheBox(libraryAlbumsCacheBoxName(server.id)),
            albums.map((e) => e.toJson()).toList(),
          );
          break;
        case LibraryKind.artists:
          final artists = await backend.getLibraryArtists();
          await _replaceBoxValues(
            await _openCacheBox(libraryArtistsCacheBoxName(server.id)),
            artists.map((e) => e.toJson()).toList(),
          );
          break;
      }

      final successTs = DateTime.now().millisecondsSinceEpoch;
      await metaBox.putAll({
        _metaKey(kind, 'lastSuccessMs'): successTs,
        _metaKey(kind, 'lastError'): '',
      });

      lastSuccessMsByKind[kind] = successTs;
      lastErrorByKind[kind] = '';
      syncVersionByKind[kind] = (syncVersionByKind[kind] ?? 0) + 1;
      syncVersion.value++;
    } catch (e) {
      final metaBox = await _openMetaBox(server.id);
      await metaBox.put(_metaKey(kind, 'lastError'), e.toString());
      lastErrorByKind[kind] = e.toString();
      printERROR('Library ${kind.name} sync failed: $e');
    } finally {
      _syncInProgressByKind[kind] = false;
      isSyncingByKind[kind] = false;
      _updateAggregateStatus();
    }
  }

  String _metaKey(LibraryKind kind, String suffix) => '${kind.name}_$suffix';

  void _updateAggregateStatus() {
    bool anySyncing = false;
    int? latestSuccess;
    String latestErr = '';
    for (final kind in LibraryKind.values) {
      if (isSyncingByKind[kind] == true) anySyncing = true;
      final ts = lastSuccessMsByKind[kind];
      if (ts != null && (latestSuccess == null || ts > latestSuccess)) {
        latestSuccess = ts;
      }
      final err = lastErrorByKind[kind] ?? '';
      if (err.isNotEmpty) latestErr = err;
    }
    isSyncing.value = anySyncing;
    lastSyncTimeMs.value = latestSuccess;
    lastError.value = latestErr;
  }

  Future<List<MediaItem>> getCachedSongs(int serverId) async {
    final box = await _openCacheBox(librarySongsCacheBoxName(serverId));
    return box.values
        .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
        .whereType<MediaItem>()
        .toList();
  }

  Future<List<Album>> getCachedAlbums(int serverId) async {
    final box = await _openCacheBox(libraryAlbumsCacheBoxName(serverId));
    return box.values
        .map<Album?>((item) => Album.fromJson(item))
        .whereType<Album>()
        .toList();
  }

  Future<List<Artist>> getCachedArtists(int serverId) async {
    final box = await _openCacheBox(libraryArtistsCacheBoxName(serverId));
    return box.values
        .map<Artist?>((item) => Artist.fromJson(item))
        .whereType<Artist>()
        .toList();
  }

  Future<List<Playlist>> getCachedPlaylists(int serverId) async {
    final box = await _openCacheBox(libraryPlaylistsCacheBoxName(serverId));
    return box.values
        .map<Playlist?>((item) => Playlist.fromJson(item))
        .whereType<Playlist>()
        .toList();
  }

  Future<void> _loadCurrentServerSyncMeta() async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server == null || server.type == ServerType.youtubeMusic) {
      for (final kind in LibraryKind.values) {
        lastSuccessMsByKind[kind] = null;
        lastErrorByKind[kind] = '';
      }
      _updateAggregateStatus();
      return;
    }

    final box = await _openMetaBox(server.id);
    for (final kind in LibraryKind.values) {
      final ts = box.get(_metaKey(kind, 'lastSuccessMs'));
      final err = box.get(_metaKey(kind, 'lastError'));
      lastSuccessMsByKind[kind] = ts is int ? ts : null;
      lastErrorByKind[kind] = err is String ? err : '';
    }
    _updateAggregateStatus();
  }

  void _startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) {
      maybeSyncAllIfStale();
    });
  }

  Future<Box> _openCacheBox(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);
  }

  Future<Box> _openMetaBox(int serverId) async {
    final name = librarySyncMetaBoxName(serverId);
    return Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);
  }

  Future<void> _replaceBoxValues(Box box, List<dynamic> values) async {
    await box.clear();
    if (values.isEmpty) return;
    final payload = <int, dynamic>{};
    for (var i = 0; i < values.length; i++) {
      payload[i] = values[i];
    }
    await box.putAll(payload);
  }
}
