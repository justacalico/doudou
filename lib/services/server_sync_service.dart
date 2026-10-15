import 'dart:async';

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/models/server.dart';
import '/server/doudou_server.dart' show kSyncProtocolName;
import '/server/hosted_backends.dart';
import '/server/sync_boxes.dart';
import '/server/sync_client.dart';
import '/server/sync_codec.dart';
import '/server/sync_model.dart';
import '/ui/screens/Library/library_controller.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/utils/app_l10n.dart';
import '/utils/helper.dart';
import '/utils/server_storage.dart';

/// Talks to a doudou server like a plain remote store. There is no
/// background sync loop and no three way merge: screens pull the library
/// boxes they are about to read with [pullForRead], and every local write to
/// a synced box is pushed back to the server moments after it happens. The
/// server holds the data, the Hive boxes on device are only its read cache.
class ServerSyncService extends GetxService {
  static const stateBoxName = '_doudouSyncState';
  static const urlPrefsKey = 'deviceSyncUrl';
  static const passwordPrefsKey = 'deviceSyncPassword';
  static const tokenPrefsKey = 'deviceSyncToken';
  static const enabledPrefsKey = 'deviceSyncEnabled';
  static const remoteServersPrefsKey = 'syncedServers';
  static const backendsRevPrefsKey = 'syncedBackendsRev';
  static const _flushDelay = Duration(milliseconds: 500);
  static const _remoteRevsTtl = Duration(seconds: 3);

  final enabled = false.obs;
  final connected = false.obs;

  /// True when the stored token was rejected and no password is held, so the
  /// user must re-enter the server password.
  final authExpired = false.obs;
  final isSyncing = false.obs;
  final serverUrl = ''.obs;
  final lastSyncAt = Rxn<DateTime>();
  final lastError = ''.obs;

  /// The backends the connected server hands out. They show up in the
  /// server list next to the local entries but are stored separately, so
  /// disconnecting removes them cleanly.
  final remoteServers = <SettingsServer>[].obs;

  Box get _prefs => Hive.box('AppPrefs');
  Box get _state => Hive.box(stateBoxName);
  DoudouSyncClient? _client;
  Future<void> _pullTail = Future.value();
  bool _legacyStateCleared = false;
  final _watchSubs = <String, StreamSubscription<BoxEvent>>{};
  final _dirtyBoxes = <String>{};
  final _boxRevs = <String, int>{};
  Map<String, int>? _remoteRevs;
  DateTime? _remoteRevsAt;
  Timer? _flushTimer;

  @override
  void onInit() {
    super.onInit();
    enabled.value = _prefs.get(enabledPrefsKey) == true;
    serverUrl.value = (_prefs.get(urlPrefsKey) as String?) ?? '';
    if (enabled.value && serverUrl.value.isNotEmpty) {
      final storedRemote = _prefs.get(remoteServersPrefsKey);
      if (storedRemote is List) {
        remoteServers.assignAll(storedRemote
            .whereType<Map>()
            .map((e) => SettingsServer.fromMap(e.cast<String, dynamic>()))
            .where((s) => s.isRemote));
      }
      _client = DoudouSyncClient(
        baseUrl: DoudouSyncClient.normalizeUrl(serverUrl.value),
        token: _prefs.get(tokenPrefsKey) as String?,
      );
      unawaited(syncNow());
    }
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    for (final sub in _watchSubs.values) {
      unawaited(sub.cancel());
    }
    _watchSubs.clear();
    _client?.close();
    _client = null;
    enabled.value = false;
    super.onClose();
  }

  /// Logs in against [url] with [password]. On success the config is
  /// persisted and the first pull starts. Returns an error message, or null
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
    authExpired.value = false;
    lastError.value = '';
    await _prefs.put(urlPrefsKey, normalized);
    // The password is deliberately not persisted: the bearer token already
    // authorizes every call, and a plaintext password on disk is only a gift
    // for anyone who copies the profile or the synced AppPrefs box.
    await _prefs.delete(passwordPrefsKey);
    await _prefs.put(tokenPrefsKey, client.token);
    await _prefs.put(enabledPrefsKey, true);
    unawaited(syncNow());
    return null;
  }

  Future<void> disconnect() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    for (final sub in _watchSubs.values) {
      await sub.cancel();
    }
    _watchSubs.clear();
    _remoteRevs = null;
    _client?.close();
    _client = null;
    enabled.value = false;
    connected.value = false;
    serverUrl.value = '';
    await _prefs.delete(urlPrefsKey);
    await _prefs.delete(passwordPrefsKey);
    await _prefs.delete(tokenPrefsKey);
    await _prefs.delete(remoteServersPrefsKey);
    await _prefs.delete(backendsRevPrefsKey);
    await _prefs.put(enabledPrefsKey, false);
    await _applyRemoteServers(const []);
  }

  void onAppResumed() {
    if (enabled.value) unawaited(syncNow());
  }

  /// Pulls the freshest state of every library box for the active server
  /// plus the hosted backend list.
  Future<void> syncNow() => _guarded(_pullAll);

  /// Fetches [names] from the server when their revision moved since the
  /// last pull. Called by screens before they read a library box so reads
  /// always come back with the server's data. Anything outside
  /// [syncedBoxNames] is ignored so a caller can never leak a local-only box.
  Future<void> pullForRead(Set<String> names) => _guarded(() async {
        await _pullBoxes(names.intersection({libraryPlaylistsBox}));
        final allowed = await _targetBoxNames(currentServerId());
        var wanted = names.intersection(allowed)
          ..remove(libraryPlaylistsBox);
        // Asking for the playlist index also refreshes the song boxes it
        // lists, so screens that read both see a consistent view.
        if (names.contains(libraryPlaylistsBox)) wanted = allowed;
        await _pullBoxes(wanted);
      });

  /// Serializes pull tasks so a [pullForRead] issued while a sync is still
  /// running waits for it instead of silently reading stale data.
  Future<void> _guarded(Future<void> Function() task) {
    final run = _pullTail.then((_) => _runPull(task));
    _pullTail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _runPull(Future<void> Function() task) async {
    final client = _client;
    if (!enabled.value || client == null) return;
    isSyncing.value = true;
    try {
      await task();
      connected.value = true;
      lastSyncAt.value = DateTime.now();
      lastError.value = '';
    } on SyncServerException catch (e) {
      if (e.isAuthError) {
        // The server token may have been rotated: try one fresh login with
        // the stored password, then run the task again. Installs that
        // predate password-free storage may still hold it; the key is
        // removed after this one use.
        final password = _prefs.get(passwordPrefsKey) as String?;
        if (password != null && await _relogin(client, password)) {
          try {
            await task();
            connected.value = true;
            lastSyncAt.value = DateTime.now();
            lastError.value = '';
            return;
          } catch (e2) {
            lastError.value = '$e2';
          }
        } else {
          // No usable credential left: surface a re-login form so the user
          // can re-enter the server password instead of silently failing.
          authExpired.value = true;
          lastError.value = 'Login failed';
        }
      } else {
        lastError.value = e.message;
      }
      connected.value = false;
    } catch (e, st) {
      printWarning('[RECOVERABLE][opId=serverSync.pull] $e\n$st');
      lastError.value = '$e';
      connected.value = false;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<bool> _relogin(DoudouSyncClient client, String password) async {
    try {
      await client.login(password);
      await _prefs.put(tokenPrefsKey, client.token);
      await _prefs.delete(passwordPrefsKey);
      authExpired.value = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pullAll() async {
    await _openState();
    // LibraryPlaylists first: its keys decide which song boxes exist.
    await _pullBoxes({libraryPlaylistsBox});
    final names = await _targetBoxNames(currentServerId());
    await _pullBoxes(names);
    for (final name in names) {
      await _ensureWatch(name);
    }
    _refreshLibraryControllers();

    try {
      final hosted = await _client!.listBackends();
      if (hosted.revision != _prefs.get(backendsRevPrefsKey)) {
        await _applyRemoteServers(hosted.backends
            .map(hostedBackendToSettingsServer)
            .whereType<SettingsServer>()
            .toList());
        await _prefs.put(backendsRevPrefsKey, hosted.revision);
      }
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=serverSync.backends] failed to fetch hosted backends: $e\n$st');
    }
  }

  /// Pulls each box whose server revision moved, that carries unpushed
  /// local writes, or that this session has never pulled at all. The last
  /// case matters for a fresh or wiped server: without a pull the heal
  /// check never runs and pre-existing local data stays device only.
  Future<void> _pullBoxes(Set<String> names) async {
    await _openState();
    if (names.isEmpty) return;
    final revs = await _fetchRemoteRevs();
    for (final name in names) {
      if (_dirtyBoxes.contains(name) ||
          _boxRevs[name] == null ||
          revs[name] != _boxRevs[name]) {
        await _pullBox(name);
      }
    }
  }

  Future<Map<String, int>> _fetchRemoteRevs() async {
    final now = DateTime.now();
    if (_remoteRevs != null &&
        _remoteRevsAt != null &&
        now.difference(_remoteRevsAt!) < _remoteRevsTtl) {
      return _remoteRevs!;
    }
    final boxes = await _client!.listBoxes();
    _remoteRevs = {for (final b in boxes) b.name: b.revision};
    _remoteRevsAt = now;
    return _remoteRevs!;
  }

  /// Replaces the local contents of [name] with the server snapshot.
  /// Pending local writes are pushed first, and keys the server does not
  /// know and never tombstoned (fresh server, wiped volume) are pushed back
  /// so a blank server gets repopulated instead of eating the library.
  Future<void> _pullBox(String name) async {
    final client = _client!;
    final box = await Hive.openBox(name);
    await _flushBox(name);
    final snap = await client.getBox(name);
    var rev = snap.revision;

    final healOps = <SyncOp>[];
    for (final key in box.keys) {
      final k = key.toString();
      if (!snap.entries.containsKey(k) && !snap.deleted.containsKey(k)) {
        healOps.add(SyncOp.put(k, box.get(key), _now()));
      }
    }
    if (healOps.isNotEmpty) {
      rev = await client.pushOps(name, healOps);
    }

    for (final k in snap.deleted.keys) {
      if (box.containsKey(k)) await box.delete(k);
    }
    for (final entry in snap.entries.entries) {
      if (!box.containsKey(entry.key) ||
          valueHash(box.get(entry.key)) != valueHash(entry.value.value)) {
        await box.put(entry.key, entry.value.value);
      }
    }
    final pushed = <String, String>{
      for (final e in snap.entries.entries) e.key: valueHash(e.value.value),
    };
    for (final op in healOps) {
      pushed[op.key] = valueHash(op.value);
    }
    _writePushed(name, pushed);
    _boxRevs[name] = rev;
    _remoteRevs?[name] = rev;
    _dirtyBoxes.remove(name);
  }

  /// Pushes every local key the server has not seen in its current form.
  /// Diffed against the hash map recorded by the last pull, so pulled data
  /// never echoes back and a failed push simply retries next time.
  Future<void> _flushBox(String name) async {
    final client = _client;
    if (client == null || !isSyncableBoxName(name)) return;
    final box = await Hive.openBox(name);
    final pushed = _readPushed(name);
    final ops = <SyncOp>[];
    final next = Map<String, String>.of(pushed);
    for (final key in box.keys) {
      final k = key.toString();
      final h = valueHash(box.get(key));
      if (pushed[k] != h) {
        ops.add(SyncOp.put(k, box.get(key), _now()));
        next[k] = h;
      }
    }
    for (final k in pushed.keys) {
      if (!box.containsKey(k)) {
        ops.add(SyncOp.delete(k, _now()));
        next.remove(k);
      }
    }
    if (ops.isEmpty) {
      _dirtyBoxes.remove(name);
      return;
    }
    final rev = await client.pushOps(name, ops);
    _boxRevs[name] = rev;
    _remoteRevs?[name] = rev;
    _writePushed(name, next);
    _dirtyBoxes.remove(name);
  }

  // -- local write detection ----------------------------------------------

  Future<void> _ensureWatch(String name) async {
    if (_watchSubs.containsKey(name) || !isSyncableBoxName(name)) return;
    final box = await Hive.openBox(name);
    _watchSubs[name] = box.watch().listen((_) => _onBoxEvent(name));
  }

  void _onBoxEvent(String name) {
    _dirtyBoxes.add(name);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushDelay, () {
      _flushTimer = null;
      unawaited(_flushDirty());
    });
  }

  Future<void> _flushDirty() async {
    if (_client == null || !enabled.value) return;
    for (final name in _dirtyBoxes.toList()) {
      try {
        await _flushBox(name);
      } catch (_) {
        // stays dirty: retried on the next write or pull
      }
    }
  }

  // -- pushed state --------------------------------------------------------

  Map<String, String> _readPushed(String name) {
    final raw = _state.get('pushed:$name');
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> _writePushed(String name, Map<String, String> pushed) =>
      _state.put('pushed:$name', pushed);

  Future<void> _openState() async {
    await Hive.openBox(stateBoxName);
    if (_legacyStateCleared) return;
    _legacyStateCleared = true;
    final stale = _state.keys
        .map((k) => k.toString())
        .where((k) =>
            k.startsWith('base:') ||
            k.startsWith('dirty:') ||
            k.startsWith('rev:'))
        .toList();
    for (final k in stale) {
      await _state.delete(k);
    }
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<Set<String>> _targetBoxNames(int serverId) async {
    final playlistsBox = await Hive.openBox(libraryPlaylistsBox);
    final playlistIds = playlistSongBoxNames(serverId, playlistsBox.toMap());
    return syncedBoxNames(serverId, playlistIds);
  }

  Future<void> _applyRemoteServers(List<SettingsServer> servers) async {
    final serialized = servers.map((s) => s.toMap()).toList();
    final current = remoteServers.map((s) => s.toMap()).toList();
    if (serialized.toString() == current.toString()) return;
    remoteServers.assignAll(servers);
    if (servers.isEmpty) {
      await _prefs.delete(remoteServersPrefsKey);
    } else {
      await _prefs.put(remoteServersPrefsKey, serialized);
    }
    if (Get.isRegistered<SettingsScreenController>()) {
      Get.find<SettingsScreenController>().onRemoteServersChanged();
    }
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

/// Fetches [names] from the connected doudou server so a read that follows
/// sees the server's data. No-op when nothing is connected.
Future<void> pullLibraryBoxes(Set<String> names) async {
  if (!Get.isRegistered<ServerSyncService>()) return;
  final sync = Get.find<ServerSyncService>();
  if (!sync.enabled.value) return;
  await sync.pullForRead(names);
}
