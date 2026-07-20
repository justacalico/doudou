import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '/models/doudou_server.dart';
import '/models/server.dart';
import '/services/doudou_server_client.dart';
import '/services/library_sync_service.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/utils/server_storage.dart';

/// Syncs library snapshots and music server URLs between this doudou client
/// and a configured [DoudouServerConfig].
///
/// The doudou-server is the source of truth for library snapshots. After the
/// local [LibrarySyncService] pulls a fresh library from a music server, this
/// service pushes the resulting cache to doudou-server. Other devices pull
/// from doudou-server into their local cache so they see the same library
/// without having to talk to the music server themselves.
///
/// Music server URLs are mirrored both ways: local servers are pushed up so
/// other devices know about them, and remote servers are pulled down so this
/// device can use them. Credentials never travel through doudou-server, only
/// URLs and display metadata.
///
/// The shared key is stored via flutter_secure_storage (OS keychain/keystore)
/// rather than plaintext Hive, so a compromised Hive box doesn't leak the
/// doudou-server password.
class DoudouServerSyncService extends GetxService {
  DoudouServerSyncService();

  static const Duration _syncInterval = Duration(minutes: 30);
  static const _secureKeyKey = 'doudou_server_key';

  final isSyncing = false.obs;
  final lastSyncTimeMs = RxnInt();
  final lastError = ''.obs;
  final isConfigured = false.obs;
  final config = Rxn<DoudouServerConfig>();

  /// remoteIds of music servers currently being pushed/pulled this round.
  final syncingServerIds = <String>{}.obs;

  /// remoteIds of music servers that have completed at least one successful
  /// sync round with doudou-server. Persisted across restarts.
  final syncedServerIds = <String>{}.obs;

  Timer? _timer;
  DoudouServerClient? _client;
  String? _clientId;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void onInit() {
    super.onInit();
    _loadConfig();
    _loadSyncedServerIds();
    _startPeriodicSync();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _client?.close();
    super.onClose();
  }

  // -- config ------------------------------------------------------------

  Future<void> setConfig(DoudouServerConfig? newConfig) async {
    _client?.close();
    _client = null;
    if (newConfig == null) {
      config.value = null;
      isConfigured.value = false;
      syncingServerIds.clear();
      syncedServerIds.clear();
      await _secureStorage.delete(key: _secureKeyKey);
      final box = Hive.box('AppPrefs');
      await box.delete('doudouServer');
      await box.delete('doudouSyncedServerIds');
    } else {
      // Persist non-secret fields in Hive, the shared key in secure storage.
      await _secureStorage.write(key: _secureKeyKey, value: newConfig.key);
      final box = Hive.box('AppPrefs');
      await box.put('doudouServer', newConfig.copyWith(key: '').toMap());
      config.value = newConfig;
      isConfigured.value = true;
      _client = DoudouServerClient(newConfig);
      unawaited(syncNow());
    }
  }

  Future<void> _loadSyncedServerIds() async {
    final box = Hive.isBoxOpen('AppPrefs') ? Hive.box('AppPrefs') : null;
    if (box == null) return;
    final raw = box.get('doudouSyncedServerIds');
    if (raw is List) {
      syncedServerIds.addAll(raw.whereType<String>());
    }
  }

  Future<void> _persistSyncedServerIds() async {
    final box = Hive.isBoxOpen('AppPrefs') ? Hive.box('AppPrefs') : await Hive.openBox('AppPrefs');
    await box.put('doudouSyncedServerIds', syncedServerIds.toList());
  }

  Future<void> _loadConfig() async {
    final box = Hive.isBoxOpen('AppPrefs') ? Hive.box('AppPrefs') : null;
    if (box == null) return;
    final raw = box.get('doudouServer');
    if (raw is! Map) return;
    final key = await _secureStorage.read(key: _secureKeyKey);
    if (key == null || key.isEmpty) return;
    final loaded = DoudouServerConfig.fromMap(Map<String, dynamic>.from(raw));
    _config = loaded.copyWith(key: key);
    config.value = _config;
    isConfigured.value = true;
    _client = DoudouServerClient(_config!);
  }

  DoudouServerConfig? _config;

  // -- sync --------------------------------------------------------------

  void _startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) => syncNow());
  }

  Future<void> onAppResumed() => syncNow();

  Future<void> syncNow() async {
    final client = _client;
    if (client == null) return;
    if (isSyncing.value) return;

    isSyncing.value = true;
    lastError.value = '';
    try {
      await _ensureRegistered(client);
      await _syncServerUrls(client);
      await _pushLocalLibraries(client);
      await _pullRemoteLibraries(client);
      lastSyncTimeMs.value = DateTime.now().millisecondsSinceEpoch;
    } catch (e) {
      lastError.value = e.toString();
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _ensureRegistered(DoudouServerClient client) async {
    final id = await _clientIdForThisDevice();
    final name = _config?.deviceName ?? Platform.localHostname;
    try {
      await client.registerClient(id, name);
    } catch (_) {
      // Registration is best-effort; the server may not be reachable yet.
    }
  }

  Future<String> _clientIdForThisDevice() async {
    if (_clientId != null) return _clientId!;
    final box = Hive.box('AppPrefs');
    final stored = box.get('doudouClientId');
    if (stored is String && stored.isNotEmpty) {
      _clientId = stored;
      return stored;
    }
    final id = 'doudou-${const Uuid().v4()}';
    await box.put('doudouClientId', id);
    _clientId = id;
    return id;
  }

  // -- server urls -------------------------------------------------------

  Future<void> _syncServerUrls(DoudouServerClient client) async {
    final settings = Get.find<SettingsScreenController>();
    final localServers = settings.servers.toList();

    // Push every non-default local server up. Credentials are stripped.
    for (final s in localServers) {
      if (s.isDefault) continue;
      if (s.serverUrl == null || s.serverUrl!.isEmpty) continue;
      try {
        await client.upsertServer(RemoteMusicServer(
          id: remoteIdFor(s.type, s.serverUrl!),
          name: s.name,
          type: s.type.name,
          url: s.serverUrl!,
          isDefault: false,
        ));
      } catch (_) {}
    }

    // Pull remote servers and mirror them locally. We only add servers we
    // don't already have by URL. We never overwrite credentials.
    final remote = await client.listServers();
    final localUrls = localServers
        .where((s) => s.serverUrl != null)
        .map((s) => s.serverUrl!.toLowerCase())
        .toSet();
    for (final r in remote) {
      if (r.url.isEmpty) continue;
      if (localUrls.contains(r.url.toLowerCase())) continue;
      final type = _parseServerType(r.type);
      if (type == null) continue;
      settings.addServerWithCredentials(
        type,
        serverUrl: r.url,
      );
    }
  }

  ServerType? _parseServerType(String name) {
    for (final t in ServerType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  // -- libraries ---------------------------------------------------------

  Future<void> _pushLocalLibraries(DoudouServerClient client) async {
    final settings = Get.find<SettingsScreenController>();
    final libSync = Get.isRegistered<LibrarySyncService>()
        ? Get.find<LibrarySyncService>()
        : null;
    if (libSync == null) return;

    for (final server in settings.servers.toList()) {
      if (server.serverUrl == null || server.serverUrl!.isEmpty) continue;
      final remoteId = remoteIdFor(server.type, server.serverUrl!);
      syncingServerIds.add(remoteId);
      var anyOk = false;
      for (final kind in LibraryKind.values) {
        try {
          final payload = await _readLocalCache(server.id, kind);
          if (payload == null) continue;
          final version = await _readRevision(remoteId, kind);
          await client.pushSnapshot(
            musicServerId: remoteId,
            kind: kind.name,
            version: version,
            payload: payload,
          );
          anyOk = true;
        } catch (_) {}
      }
      if (anyOk) {
        syncedServerIds.add(remoteId);
      }
      syncingServerIds.remove(remoteId);
    }
    await _persistSyncedServerIds();
  }

  Future<void> _pullRemoteLibraries(DoudouServerClient client) async {
    final settings = Get.find<SettingsScreenController>();
    final libSync = Get.isRegistered<LibrarySyncService>()
        ? Get.find<LibrarySyncService>()
        : null;
    if (libSync == null) return;

    for (final server in settings.servers.toList()) {
      if (server.serverUrl == null || server.serverUrl!.isEmpty) continue;
      final remoteId = remoteIdFor(server.type, server.serverUrl!);
      syncingServerIds.add(remoteId);
      try {
        final remoteSnapshots = await client.listSnapshots(remoteId);
        for (final snap in remoteSnapshots) {
          final kind = _matchKind(snap.kind);
          if (kind == null) continue;
          final localVersion = await _readRevision(remoteId, kind);
          if (snap.version <= localVersion) continue;
          await _writeLocalCache(server.id, kind, snap.payload);
          await _writeRevision(remoteId, kind, snap.version);
          libSync.lastSuccessMsByKind[kind] = snap.updatedAtMs;
        }
        syncedServerIds.add(remoteId);
      } catch (_) {
        // One server failing shouldn't abort the rest.
      }
      syncingServerIds.remove(remoteId);
    }
    await _persistSyncedServerIds();
  }

  LibraryKind? _matchKind(String name) {
    for (final k in LibraryKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }

  Future<String?> _readLocalCache(int serverId, LibraryKind kind) async {
    final boxName = switch (kind) {
      LibraryKind.songs => librarySongsCacheBoxName(serverId),
      LibraryKind.playlists => libraryPlaylistsCacheBoxName(serverId),
      LibraryKind.albums => libraryAlbumsCacheBoxName(serverId),
      LibraryKind.artists => libraryArtistsCacheBoxName(serverId),
    };
    final box = Hive.isBoxOpen(boxName) ? Hive.box(boxName) : await Hive.openBox(boxName);
    if (box.isEmpty) return null;
    final items = box.values
        .map((v) => v is Map ? Map<String, dynamic>.from(v) : v)
        .toList();
    return encodeSnapshotPayload(items.cast<Map<String, dynamic>>());
  }

  Future<void> _writeLocalCache(
      int serverId, LibraryKind kind, String payload) async {
    final boxName = switch (kind) {
      LibraryKind.songs => librarySongsCacheBoxName(serverId),
      LibraryKind.playlists => libraryPlaylistsCacheBoxName(serverId),
      LibraryKind.albums => libraryAlbumsCacheBoxName(serverId),
      LibraryKind.artists => libraryArtistsCacheBoxName(serverId),
    };
    final box = Hive.isBoxOpen(boxName) ? Hive.box(boxName) : await Hive.openBox(boxName);
    await box.clear();
    final decoded = decodeSnapshotPayload(payload);
    final map = <int, dynamic>{};
    for (var i = 0; i < decoded.length; i++) {
      map[i] = decoded[i];
    }
    await box.putAll(map);
  }

  // -- per-server revision tracking --------------------------------------

  String _revisionKey(String remoteId, LibraryKind kind) =>
      'doudou_rev_${remoteId}_${kind.name}';

  Future<int> _readRevision(String remoteId, LibraryKind kind) async {
    final box = Hive.isBoxOpen('AppPrefs') ? Hive.box('AppPrefs') : await Hive.openBox('AppPrefs');
    final v = box.get(_revisionKey(remoteId, kind));
    return v is int ? v : 0;
  }

  Future<void> _writeRevision(String remoteId, LibraryKind kind, int version) async {
    final box = Hive.isBoxOpen('AppPrefs') ? Hive.box('AppPrefs') : await Hive.openBox('AppPrefs');
    await box.put(_revisionKey(remoteId, kind), version);
  }
}

/// Stable, content-derived ID for a music server. Identical type:url inputs
/// produce the same id across devices and builds (unlike Dart's hashCode,
/// which is not guaranteed to be stable across isolates or builds).
String remoteIdFor(ServerType type, String url) {
  final raw = '${type.name}:$url';
  return sha1.convert(utf8.encode(raw)).toString().substring(0, 16);
}
