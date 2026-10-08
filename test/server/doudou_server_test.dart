import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:doudou/server/doudou_server.dart';
import 'package:doudou/server/sync_auth.dart';
import 'package:doudou/server/hmb_archive.dart';
import 'package:doudou/server/sync_client.dart';
import 'package:doudou/server/sync_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dataDir;
  late Directory scratchDir;
  DoudouSyncServer? server;
  DoudouSyncClient? client;

  const password = 'test-password';

  Future<void> boot() async {
    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0, password: password);
    client = DoudouSyncClient(baseUrl: 'http://127.0.0.1:${server!.port}');
  }

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('doudou_server_test_');
    scratchDir = await Directory.systemTemp.createTemp('doudou_scratch_');
  });

  tearDown(() async {
    client?.close();
    client = null;
    await server?.stop();
    server = null;
    await Hive.close();
    if (dataDir.existsSync()) await dataDir.delete(recursive: true);
    if (scratchDir.existsSync()) await scratchDir.delete(recursive: true);
  });

  test('ping reports the sync protocol without auth', () async {
    await boot();
    final info = await client!.ping();
    expect(info['name'], 'doudou-sync');
    expect(info['version'], 1);
  });

  test('login rejects a wrong password', () async {
    await boot();
    expect(
      () => client!.login('wrong'),
      throwsA(isA<SyncServerException>()
          .having((e) => e.isAuthError, 'isAuthError', isTrue)),
    );
  });

  test('unauthenticated requests are rejected', () async {
    await boot();
    expect(() => client!.listBoxes(),
        throwsA(isA<SyncServerException>()));
  });

  test('login is rate limited after repeated failures', () async {
    server = DoudouSyncServer(
        dataDir: dataDir.path,
        rateLimiter: LoginRateLimiter(maxFailures: 2));
    await server!.start(port: 0, password: password);
    client = DoudouSyncClient(baseUrl: 'http://127.0.0.1:${server!.port}');

    for (var i = 0; i < 2; i++) {
      await expectLater(
        () => client!.login('wrong'),
        throwsA(isA<SyncServerException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    }

    // Locked out now: even the right password gets a 429.
    await expectLater(
      () => client!.login(password),
      throwsA(isA<SyncServerException>()
          .having((e) => e.statusCode, 'statusCode', 429)),
    );
  });

  test('a successful login still verifies against a legacy sha256 hash',
      () async {
    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0, password: 'first');
    await server!.stop();

    // Rewrite the stored hash to the pre-PBKDF2 format to emulate an
    // existing install upgrading.
    final configFile = File('${dataDir.path}/server.json');
    final config = jsonDecode(configFile.readAsStringSync());
    config['passwordHash'] = legacyHashSyncPassword('first', config['salt']);
    configFile.writeAsStringSync(jsonEncode(config));

    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0);
    client = DoudouSyncClient(baseUrl: 'http://127.0.0.1:${server!.port}');
    await client!.login('first');
    expect(client!.token, isNotEmpty);
  });

  test('login returns a token that authorizes requests', () async {
    await boot();
    await client!.login(password);
    expect(client!.token, isNotNull);
    expect(await client!.listBoxes(), isA<List<SyncBoxInfo>>());
  });

  test('pushed ops show up in the box snapshot', () async {
    await boot();
    await client!.login(password);
    await client!.pushOps('LIBFAV', [
      SyncOp.put('song1', {'title': 'One'}, 1000),
      SyncOp.put('song2', {'title': 'Two'}, 1001),
    ]);

    final snap = await client!.getBox('LIBFAV');
    expect(snap.entries.keys, containsAll(['song1', 'song2']));
    expect((snap.entries['song1']!.value as Map)['title'], 'One');
    expect(snap.revision, 1);
  });

  test('older ops lose against stored timestamps', () async {
    await boot();
    await client!.login(password);
    await client!.pushOps('B', [SyncOp.put('k', 'new', 1000)]);
    // An older write for the same key must be rejected
    await client!.pushOps('B', [SyncOp.put('k', 'old', 500)]);
    final snap = await client!.getBox('B');
    expect(snap.entries['k']!.value, 'new');
  });

  test('deletes tombstone the key and resist stale puts', () async {
    await boot();
    await client!.login(password);
    await client!.pushOps('B', [SyncOp.put('k', 'v', 1000)]);
    await client!.pushOps('B', [SyncOp.delete('k', 2000)]);

    var snap = await client!.getBox('B');
    expect(snap.entries.containsKey('k'), isFalse);
    expect(snap.deleted['k'], 2000);

    // a put older than the tombstone stays rejected
    await client!.pushOps('B', [SyncOp.put('k', 'zombie', 1500)]);
    snap = await client!.getBox('B');
    expect(snap.entries.containsKey('k'), isFalse);

    // a newer put revives the key
    await client!.pushOps('B', [SyncOp.put('k', 'revived', 3000)]);
    snap = await client!.getBox('B');
    expect(snap.entries['k']!.value, 'revived');
    expect(snap.deleted.containsKey('k'), isFalse);
  });

  test('listBoxes reports hosted boxes', () async {
    await boot();
    await client!.login(password);
    await client!.pushOps('LIBRP', [SyncOp.put('a', 1, 10)]);
    final boxes = await client!.listBoxes();
    final lirp = boxes.firstWhere((b) => b.name == 'LIBRP');
    expect(lirp.keys, 1);
    expect(lirp.revision, 1);
    // the internal meta box is never exposed
    expect(boxes.map((b) => b.name), isNot(contains('_doudouMeta')));
  });

  test('box names starting with underscore are refused', () async {
    await boot();
    await client!.login(password);
    expect(() => client!.getBox('_doudouMeta'),
        throwsA(isA<SyncServerException>()));
    expect(() => client!.pushOps('_doudouMeta', []),
        throwsA(isA<SyncServerException>()));
  });

  test('import .hmb seeds boxes that clients can read', () async {
    // build a hmb the same way the app backup does: a zip of .hive files.
    // this must happen before the server boots since Hive has one global home.
    final hiveDir = '${scratchDir.path}/hivesrc';
    Directory(hiveDir).createSync();
    Hive.init(hiveDir);
    final srcBox = await Hive.openBox('LibraryPlaylists');
    await srcBox.put('s_0_PL1', {'playlistId': 'PL1', 'title': 'Mix'});
    await srcBox.close();
    await Hive.close();

    final archive = Archive();
    // Hive lowercases its box file names
    final hiveBytes =
        await File('$hiveDir/libraryplaylists.hive').readAsBytes();
    archive.addFile(
        ArchiveFile('LibraryPlaylists.hive', hiveBytes.length, hiveBytes));
    archive.addFile(ArchiveFile('song.m4a', 3, [1, 2, 3]));
    final hmbPath = '${scratchDir.path}/backup.hmb';
    await File(hmbPath).writeAsBytes(ZipEncoder().encode(archive)!);

    await boot();
    final result = await server!.importHmb(hmbPath);
    expect(result.boxes, contains('LibraryPlaylists'));
    expect(result.skipped, contains('song.m4a'));

    await client!.login(password);
    final snap = await client!.getBox('LibraryPlaylists');
    expect(snap.entries.containsKey('s_0_PL1'), isTrue);
    expect((snap.entries['s_0_PL1']!.value as Map)['title'], 'Mix');
    // imported entries get stamped with the import time and bump the rev
    expect(snap.entries['s_0_PL1']!.ts, greaterThan(0));
    expect(snap.revision, greaterThan(0));

    // mixed case file names map to the same box as canonical client names
    final lower = await client!.getBox('LIBRARYPLAYLISTS');
    expect(lower.entries.keys, snap.entries.keys);
  });

  test('import rejects a missing file and a non-zip', () async {
    await boot();
    expect(() => server!.importHmb('${scratchDir.path}/nope.hmb'),
        throwsA(isA<HmbImportException>()));

    final junkPath = '${scratchDir.path}/junk.hmb';
    await File(junkPath).writeAsString('not a zip');
    expect(() => server!.importHmb(junkPath),
        throwsA(isA<HmbImportException>()));
  });

  test('export.hmb returns a zip the import can read back', () async {
    await boot();
    await client!.login(password);
    await client!.pushOps('X', [SyncOp.put('k', 'v', 10)]);
    final bytes = await client!.exportHmb();
    expect(bytes, isNotEmpty);

    final archive = ZipDecoder().decodeBytes(bytes);
    // Hive stores box files lowercased
    expect(archive.map((f) => f.name), contains('x.hive'));
  });
}
