import 'dart:async';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/server/doudou_server.dart' show kSyncProtocolName;
import '/server/sync_boxes.dart';
import '/server/sync_client.dart';
import '/server/sync_engine.dart';
import '/server/sync_merge.dart' show KeyBase;
import '/ui/screens/Library/library_controller.dart';
import '/utils/app_l10n.dart';
import '/utils/helper.dart';
import '/utils/server_storage.dart';

/// Keeps the local library Hive boxes in sync with a doudou sync server so
/// every logged in device shares favorites, playlists, recently played and
/// the rest of the library data.
///
/// Nothing playback related ever crosses the wire: only the boxes listed by
/// [syncedBoxNames] are exchanged, which excludes caches, downloads, stream
/// URLs and device settings.
class ServerSyncService extends GetxService {
  static const stateBoxName = '_doudouSyncState';
  static const urlPrefsKey = 'deviceSyncUrl';
  static const passwordPrefsKey = 'deviceSyncPassword';
  static const tokenPrefsKey = 'deviceSyncToken';
  static const enabledPrefsKey = 'deviceSyncEnabled';
  static const syncInterval = Duration(seconds: 30);

  final enabled = false.obs;
  final connected = false.obs;
  final isSyncing = false.obs;
  final serverUrl = ''.obs;
  final lastSyncAt = Rxn<DateTime>();
  final lastError = ''.obs;

  Box get _prefs => Hive.box('AppPrefs');
  DoudouSyncClient? _client;
  Timer? _timer;
  bool _cycleRunning = false;

  @override
  void onInit() {
    super.onInit();
    enabled.value = _prefs.get(enabledPrefsKey) == true;
    serverUrl.value = (_prefs.get(urlPrefsKey) as String?) ?? '';
    if (enabled.value && serverUrl.value.isNotEmpty) {
      _client = DoudouSyncClient(
        baseUrl: DoudouSyncClient.normalizeUrl(serverUrl.value),
        token: _prefs.get(tokenPrefsKey) as String?,
      );
      _startTimer();
      unawaited(syncNow());
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _client?.close();
    super.onClose();
  }

  /// Logs in against [url] with [password]. On success the sync config is
  /// persisted and background sync starts. Returns an error message, or null
  /// when the connection worked.
  Future<String?> connect({
    required String url,
    required String password,
  }) async {
    final normalized = DoudouSyncClient.normalizeUrl(url);
    if (normalized.isEmpty) return l10nFromPrefs().serverUrlRequired;

    final client = DoudouSyncClient(baseUrl: normalized);
    try {
      final info = await client.ping();
      if (info['name'] != kSyncProtocolName) {
        client.close();
        return l10nFromPrefs().notDoudouSyncServer;
      }
      await client.login(password);
    } on SyncServerException catch (e) {
      client.close();
      return e.message;
    } catch (e) {
      client.close();
      return '$e';
    }

    _client?.close();
    _client = client;
    serverUrl.value = normalized;
    enabled.value = true;
    connected.value = true;
    lastError.value = '';
    await _prefs.put(urlPrefsKey, normalized);
    await _prefs.put(passwordPrefsKey, password);
    await _prefs.put(tokenPrefsKey, client.token);
    await _prefs.put(enabledPrefsKey, true);
    _startTimer();
    unawaited(syncNow());
    return null;
  }

  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _client?.close();
    _client = null;
    enabled.value = false;
    connected.value = false;
    serverUrl.value = '';
    await _prefs.delete(urlPrefsKey);
    await _prefs.delete(passwordPrefsKey);
    await _prefs.delete(tokenPrefsKey);
    await _prefs.put(enabledPrefsKey, false);
  }

  void onAppResumed() {
    if (enabled.value) unawaited(syncNow());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(syncInterval, (_) => unawaited(syncNow()));
  }

  /// Runs one full sync cycle. Safe to call any time; overlapping calls are
  /// skipped and the whole cycle is a no-op while disconnected.
  Future<void> syncNow() async {
    final client = _client;
    if (!enabled.value || client == null || _cycleRunning) return;
    _cycleRunning = true;
    isSyncing.value = true;
    try {
      await _runCycle(client);
      connected.value = true;
      lastSyncAt.value = DateTime.now();
      lastError.value = '';
    } on SyncServerException catch (e) {
      if (e.isAuthError) {
        // The server token may have been rotated: try one fresh login with
        // the stored password, then run the cycle again.
        final password = _prefs.get(passwordPrefsKey) as String?;
        if (password != null && await _relogin(client, password)) {
          try {
            await _runCycle(client);
            connected.value = true;
            lastSyncAt.value = DateTime.now();
            lastError.value = '';
            return;
          } catch (e2) {
            lastError.value = '$e2';
          }
        } else {
          lastError.value = 'Login failed';
        }
      } else {
        lastError.value = e.message;
      }
      connected.value = false;
    } catch (e, st) {
      printWarning('[RECOVERABLE][opId=serverSync.cycle] $e\n$st');
      lastError.value = '$e';
      connected.value = false;
    } finally {
      _cycleRunning = false;
      isSyncing.value = false;
    }
  }

  Future<bool> _relogin(DoudouSyncClient client, String password) async {
    try {
      await client.login(password);
      await _prefs.put(tokenPrefsKey, client.token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _runCycle(DoudouSyncClient client) async {
    final serverId = currentServerId();
    await Hive.openBox(stateBoxName);
    final remoteRevs = {for (final b in await client.listBoxes()) b.name: b};
    final engine = BoxSyncEngine(
      client: client,
      state: _HiveSyncStateStore(),
      local: _HiveLocalBoxStore(),
    );
    var remoteApplied = false;

    for (final boxName in await _targetBoxNames(serverId)) {
      try {
        final applied = await engine.syncBox(boxName,
            remoteRevision: remoteRevs[boxName]?.revision);
        remoteApplied = remoteApplied || applied;
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=serverSync.box] failed to sync $boxName: $e\n$st');
      }
    }
    if (remoteApplied) _refreshLibraryControllers();
  }

  Future<Set<String>> _targetBoxNames(int serverId) async {
    final playlistsBox = await Hive.openBox(libraryPlaylistsBox);
    final playlistIds = playlistSongBoxNames(serverId, playlistsBox.toMap());
    return syncedBoxNames(serverId, playlistIds);
  }

  void _refreshLibraryControllers() {
    try {
      if (Get.isRegistered<LibraryPlaylistsController>()) {
        Get.find<LibraryPlaylistsController>().refreshLib();
      }
      if (Get.isRegistered<LibrarySongsController>()) {
        unawaited(Get.find<LibrarySongsController>().init());
      }
      if (Get.isRegistered<LibraryAlbumsController>()) {
        Get.find<LibraryAlbumsController>().refreshLib();
      }
      if (Get.isRegistered<LibraryArtistsController>()) {
        Get.find<LibraryArtistsController>().refreshLib();
      }
    } catch (e, st) {
      printWarning('[RECOVERABLE][opId=serverSync.refresh] $e\n$st');
    }
  }
}

/// Keeps the merge bookkeeping inside a dedicated local box so nothing but
/// the synced data itself ever reaches the server.
class _HiveSyncStateStore implements SyncStateStore {
  Box get _box => Hive.box(ServerSyncService.stateBoxName);

  @override
  Map<String, KeyBase> readBase(String boxName) {
    final raw = _box.get('base:$boxName');
    final out = <String, KeyBase>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final parsed = KeyBase.fromJson(v);
        if (parsed != null) out[k.toString()] = parsed;
      });
    }
    return out;
  }

  @override
  Map<String, int> readDirtyTs(String boxName) {
    final raw = _box.get('dirty:$boxName');
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  @override
  int readRevision(String boxName) =>
      (_box.get('rev:$boxName') as num?)?.toInt() ?? -1;

  @override
  Future<void> write(
    String boxName, {
    required int revision,
    required Map<String, KeyBase> base,
    required Map<String, int> dirtyTs,
  }) async {
    await _box.put('rev:$boxName', revision);
    await _box.put(
      'base:$boxName',
      base.map((k, v) => MapEntry(k, v.toJson())),
    );
    await _box.put('dirty:$boxName', dirtyTs);
  }
}

class _HiveLocalBoxStore implements LocalBoxStore {
  @override
  Future<Map<String, Object?>> readAll(String boxName) async {
    final box = await Hive.openBox(boxName);
    final out = <String, Object?>{};
    for (final key in box.keys) {
      out[key.toString()] = box.get(key);
    }
    return out;
  }

  @override
  Future<void> applyRemote(
    String boxName, {
    required Map<String, Object?> puts,
    required Set<String> deletes,
  }) async {
    final box = await Hive.openBox(boxName);
    for (final key in deletes) {
      await box.delete(key);
    }
    for (final entry in puts.entries) {
      await box.put(entry.key, entry.value);
    }
  }
}
