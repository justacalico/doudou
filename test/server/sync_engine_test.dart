import 'dart:io';

import 'package:doudou/server/doudou_server.dart';
import 'package:doudou/server/sync_client.dart';
import 'package:doudou/server/sync_engine.dart';
import 'package:doudou/server/sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// In-memory device: a local box map plus the sync bookkeeping a real client
/// would keep in _doudouSyncState.
class FakeDevice {
  FakeDevice(String baseUrl, {int Function()? now})
      : client = DoudouSyncClient(baseUrl: baseUrl),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final DoudouSyncClient client;
  final int Function() _now;
  final boxes = <String, Map<String, Object?>>{};
  final _base = <String, Map<String, KeyBase>>{};
  final _dirty = <String, Map<String, int>>{};
  final _revs = <String, int>{};

  late final engine = BoxSyncEngine(
    client: client,
    state: _MemState(this),
    local: _MemLocal(this),
    now: _now,
  );

  Future<bool> sync(String box, {int? remoteRevision}) =>
      engine.syncBox(box, remoteRevision: remoteRevision);
}

class _MemState implements SyncStateStore {
  _MemState(this.device);
  final FakeDevice device;

  @override
  Map<String, KeyBase> readBase(String boxName) =>
      Map.of(device._base[boxName] ?? {});

  @override
  Map<String, int> readDirtyTs(String boxName) =>
      Map.of(device._dirty[boxName] ?? {});

  @override
  int readRevision(String boxName) => device._revs[boxName] ?? -1;

  @override
  Future<void> write(
    String boxName, {
    required int revision,
    required Map<String, KeyBase> base,
    required Map<String, int> dirtyTs,
  }) async {
    device._revs[boxName] = revision;
    device._base[boxName] = Map.of(base);
    device._dirty[boxName] = Map.of(dirtyTs);
  }
}

class _MemLocal implements LocalBoxStore {
  _MemLocal(this.device);
  final FakeDevice device;

  @override
  Future<Map<String, Object?>> readAll(String boxName) async =>
      Map.of(device.boxes[boxName] ?? {});

  @override
  Future<void> applyRemote(
    String boxName, {
    required Map<String, Object?> puts,
    required Set<String> deletes,
  }) async {
    final box = device.boxes.putIfAbsent(boxName, () => {});
    for (final key in deletes) {
      box.remove(key);
    }
    box.addAll(puts);
  }
}

void main() {
  late Directory dataDir;
  DoudouSyncServer? server;
  late String baseUrl;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('doudou_engine_test_');
    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0, password: 'pw');
    baseUrl = 'http://127.0.0.1:${server!.port}';
  });

  tearDown(() async {
    await server?.stop();
    server = null;
    await Hive.close();
    if (dataDir.existsSync()) await dataDir.delete(recursive: true);
  });

  test('two devices converge on the same box contents', () async {
    final a = FakeDevice(baseUrl);
    final b = FakeDevice(baseUrl);
    await a.client.login('pw');
    await b.client.login('pw');

    a.boxes['LIBFAV'] = {
      's1': {'title': 'From A'},
    };
    await a.sync('LIBFAV');
    final applied = await b.sync('LIBFAV');

    expect(applied, isTrue);
    expect(b.boxes['LIBFAV'], a.boxes['LIBFAV']);

    // second sync on B: nothing left to do
    expect(await b.sync('LIBFAV'), isFalse);
  });

  test('deletes propagate to other devices', () async {
    final a = FakeDevice(baseUrl);
    final b = FakeDevice(baseUrl);
    await a.client.login('pw');
    await b.client.login('pw');

    a.boxes['LIBFAV'] = {'s1': 'x'};
    await a.sync('LIBFAV');
    await b.sync('LIBFAV');
    expect(b.boxes['LIBFAV']!.containsKey('s1'), isTrue);

    a.boxes['LIBFAV']!.remove('s1');
    await a.sync('LIBFAV');
    await b.sync('LIBFAV');
    expect(b.boxes['LIBFAV']!.containsKey('s1'), isFalse);
  });

  test('concurrent edits to different keys merge into a union', () async {
    final a = FakeDevice(baseUrl);
    final b = FakeDevice(baseUrl);
    await a.client.login('pw');
    await b.client.login('pw');

    await a.sync('LIBFAV');
    await b.sync('LIBFAV');
    a.boxes['LIBFAV'] = {'fromA': 1};
    b.boxes['LIBFAV'] = {'fromB': 2};

    await a.sync('LIBFAV');
    await b.sync('LIBFAV');
    // B pulled A's key and pushed its own; A picks up B's on next cycle
    await a.sync('LIBFAV');

    expect(a.boxes['LIBFAV'], {'fromA': 1, 'fromB': 2});
    expect(b.boxes['LIBFAV'], {'fromA': 1, 'fromB': 2});
  });

  test('conflict on the same key resolves last write wins', () async {
    var clock = 5000;
    final a = FakeDevice(baseUrl, now: () => clock);
    final b = FakeDevice(baseUrl, now: () => clock);
    await a.client.login('pw');
    await b.client.login('pw');

    await a.sync('B');
    await b.sync('B');

    // A wrote earlier, B wrote later: B must win on both devices
    clock = 6000;
    a.boxes['B'] = {'k': 'a'};
    await a.sync('B');
    clock = 7000;
    b.boxes['B'] = {'k': 'b'};
    await b.sync('B');
    await a.sync('B');

    expect(a.boxes['B'], {'k': 'b'});
    expect(b.boxes['B'], {'k': 'b'});
  });

  test('a fresh device pulls the whole server state', () async {
    final a = FakeDevice(baseUrl);
    await a.client.login('pw');
    a.boxes['LibraryPlaylists'] = {
      's_0_X': {'playlistId': 'X', 'title': 'Mix'},
    };
    await a.sync('LibraryPlaylists');

    final fresh = FakeDevice(baseUrl);
    await fresh.client.login('pw');
    await fresh.sync('LibraryPlaylists');
    expect(fresh.boxes['LibraryPlaylists'], a.boxes['LibraryPlaylists']);
  });

  test('client heals server data lost without tombstones', () async {
    final a = FakeDevice(baseUrl);
    await a.client.login('pw');
    a.boxes['LIBRP'] = {'s1': 'track'};
    await a.sync('LIBRP');

    // wipe the server database like a fresh install would
    final port = server!.port;
    await server!.stop();
    await Hive.close();
    for (final f in Directory('${dataDir.path}/db')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.hive'))) {
      f.deleteSync();
    }
    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: port, password: 'pw');
    final wipedClient = DoudouSyncClient(baseUrl: baseUrl);
    await wipedClient.login('pw');
    var snap = await wipedClient.getBox('LIBRP');
    expect(snap.entries, isEmpty);

    // next cycle re-pushes the data instead of deleting it locally
    await a.sync('LIBRP');
    snap = await wipedClient.getBox('LIBRP');
    expect(snap.entries.keys, contains('s1'));
    expect(a.boxes['LIBRP']!.containsKey('s1'), isTrue);
    wipedClient.close();
  });
}
