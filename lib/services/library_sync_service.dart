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

class LibrarySyncService extends GetxService {
  static const Duration _syncInterval = Duration(minutes: 30);

  final syncVersion = 0.obs;
  final isSyncing = false.obs;
  final lastSyncTimeMs = RxnInt();
  final lastError = ''.obs;

  Timer? _timer;
  bool _syncInProgress = false;
  late final Worker _activeServerWorker;

  @override
  void onInit() {
    super.onInit();
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

  Future<void> onAppResumed() async {
    await maybeSyncIfStale();
  }

  Future<void> maybeSyncIfStale() async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server == null || server.type == ServerType.youtubeMusic) return;

    final metaBox = await _openMetaBox(server.id);
    final lastSuccessMs = metaBox.get('lastSuccessMs');
    if (lastSuccessMs is! int) {
      await syncNow(force: true);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - lastSuccessMs;
    if (age >= _syncInterval.inMilliseconds) {
      await syncNow();
    }
  }

  Future<void> syncNow({bool force = false}) async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    isSyncing.value = true;

    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server == null || server.type == ServerType.youtubeMusic) {
      _syncInProgress = false;
      isSyncing.value = false;
      return;
    }

    try {
      final metaBox = await _openMetaBox(server.id);
      final now = DateTime.now().millisecondsSinceEpoch;
      await metaBox.put('lastAttemptMs', now);

      if (!force) {
        final lastSuccessMs = metaBox.get('lastSuccessMs');
        if (lastSuccessMs is int &&
            now - lastSuccessMs < _syncInterval.inMilliseconds) {
          _loadCurrentServerSyncMeta();
          return;
        }
      }

      final backend = createBackend(server);
      final songs = await backend.getLibrarySongs();
      final albums = await backend.getLibraryAlbums();
      final artists = await backend.getLibraryArtists();
      final playlists = await backend.getLibraryPlaylists();

      await _replaceBoxValues(
        await _openCacheBox(librarySongsCacheBoxName(server.id)),
        songs,
      );
      await _replaceBoxValues(
        await _openCacheBox(libraryAlbumsCacheBoxName(server.id)),
        albums.map((e) => e.toJson()).toList(),
      );
      await _replaceBoxValues(
        await _openCacheBox(libraryArtistsCacheBoxName(server.id)),
        artists.map((e) => e.toJson()).toList(),
      );
      await _replaceBoxValues(
        await _openCacheBox(libraryPlaylistsCacheBoxName(server.id)),
        playlists.map((e) => e.toJson()).toList(),
      );

      final successTs = DateTime.now().millisecondsSinceEpoch;
      await metaBox.putAll({
        'lastSuccessMs': successTs,
        'lastError': '',
      });

      lastError.value = '';
      lastSyncTimeMs.value = successTs;
      syncVersion.value++;
    } catch (e) {
      final settings = Get.find<SettingsScreenController>();
      final server = settings.activeServer;
      if (server != null) {
        final metaBox = await _openMetaBox(server.id);
        await metaBox.put('lastError', e.toString());
      }
      lastError.value = e.toString();
      printERROR('Library sync failed: $e');
    } finally {
      _syncInProgress = false;
      isSyncing.value = false;
    }
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
      lastSyncTimeMs.value = null;
      lastError.value = '';
      return;
    }

    final box = await _openMetaBox(server.id);
    lastSyncTimeMs.value = box.get('lastSuccessMs');
    final err = box.get('lastError');
    lastError.value = err is String ? err : '';
  }

  void _startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) {
      maybeSyncIfStale();
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
