import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

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
class DoudouServerSyncService extends GetxService {
  DoudouServerSyncService();

  static const Duration _syncInterval = Duration(minutes: 30);

  final isSyncing = false.obs;
  final lastSyncTimeMs = RxnInt();
  final lastError = ''.obs;
  final isConfigured = false.obs;

  Timer? _timer;
  DoudouServerClient? _client;
  String? _clientId;

  @override
  void onInit() {
    super.onInit();
    _loadConfig();
    _startPeriodicSync();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _client?.close();
    super.onClose();
  }

  // -- config ------------------------------------------------------------

  DoudouServerConfig? _config;

  DoudouServerConfig? get config => _config;

  Future<void> setConfig(DoudouServerConfig? config) async {
    _config = config;
    _client?.close();
    _client = config == null ? null : DoudouServerClient(config);
    isConfigured.value = config != null;
    final box = Hive.box('AppPrefs');
    if (config == null) {
      await box.delete('doudouServer');
    } else {
      await box.put('doudouServer', config.toMap());
    }
    if (config != null) {
      unawaited(syncNow());
    }
  }

  void _loadConfig() {
    final box = Hive.isBoxOpen('AppPrefs') ? Hive.box('AppPrefs') : null;
    if (box == null) return;
    final raw = box.get('doudouServer');
    if (raw is Map) {
      _config = DoudouServerConfig.fromMap(Map<String, dynamic>.from(raw));
      _client = DoudouServerClient(_config!);
      isConfigured.value = true;
    }
  }

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
    final id = _generateClientId();
    await box.put('doudouClientId', id);
    _clientId = id;
    return id;
  }

  String _generateClientId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = ts ^ (ts << 17) ^ (ts >> 3);
    return 'doudou-$ts-$rand';
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
          id: _remoteIdFor(s),
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

  String _remoteIdFor(SettingsServer s) {
    final raw = '${s.type.name}:${s.serverUrl ?? ""}';
    return raw.hashCode.toRadixString(16);
  }

  // -- libraries ---------------------------------------------------------

  Future<void> _pushLocalLibraries(DoudouServerClient client) async {
    final settings = Get.find<SettingsScreenController>();
    final libSync = Get.isRegistered<LibrarySyncService>()
        ? Get.find<LibrarySyncService>()
        : null;
    if (libSync == null) return;

    for (final server in settings.servers.toList()) {
      final remoteId = _remoteIdFor(server);
      for (final kind in LibraryKind.values) {
        try {
          final payload = await _readLocalCache(server.id, kind);
          if (payload == null) continue;
          final version = (libSync.syncVersionByKind[kind] ?? 0);
          await client.pushSnapshot(
            musicServerId: remoteId,
            kind: kind.name,
            version: version,
            payload: payload,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _pullRemoteLibraries(DoudouServerClient client) async {
    final settings = Get.find<SettingsScreenController>();
    final libSync = Get.isRegistered<LibrarySyncService>()
        ? Get.find<LibrarySyncService>()
        : null;
    if (libSync == null) return;

    for (final server in settings.servers.toList()) {
      final remoteId = _remoteIdFor(server);
      final remoteSnapshots = await client.listSnapshots(remoteId);
      for (final snap in remoteSnapshots) {
        final kind = _matchKind(snap.kind);
        if (kind == null) continue;
        final localVersion = libSync.syncVersionByKind[kind] ?? 0;
        if (snap.version <= localVersion) continue;
        await _writeLocalCache(server.id, kind, snap.payload);
        libSync.syncVersionByKind[kind] = snap.version;
        libSync.lastSuccessMsByKind[kind] = snap.updatedAtMs;
      }
    }
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
    return jsonEncode(items);
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
    final decoded = jsonDecode(payload);
    if (decoded is! List) return;
    final map = <int, dynamic>{};
    for (var i = 0; i < decoded.length; i++) {
      map[i] = decoded[i];
    }
    await box.putAll(map);
  }
}
