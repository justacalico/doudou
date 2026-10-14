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
    expect(() => client!.listBoxes(), throwsA(isA<SyncServerException>()));
  });

  test('login is rate limited after repeated failures', () async {
    server = DoudouSyncServer(
        dataDir: dataDir.path, rateLimiter: LoginRateLimiter(maxFailures: 2));
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
    expect(
        () => server!.importHmb(junkPath), throwsA(isA<HmbImportException>()));
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

  // -- web ui --------------------------------------------------------------

  Future<({int status, Map<String, Object?> body})> webui(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? json,
    List<int>? bytes,
  }) async {
    final http = HttpClient();
    try {
      final uri = Uri.parse('http://127.0.0.1:${server!.port}$path');
      HttpClientRequest request;
      switch (method) {
        case 'POST':
          request = await http.postUrl(uri);
        case 'PUT':
          request = await http.putUrl(uri);
        case 'DELETE':
          request = await http.deleteUrl(uri);
        default:
          request = await http.getUrl(uri);
      }
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (json != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(json));
      }
      if (bytes != null) {
        request.add(bytes);
      }
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      Object? decoded;
      if (text.isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } catch (_) {}
      }
      return (
        status: response.statusCode,
        body: decoded is Map
            ? Map<String, Object?>.from(decoded)
            : <String, Object?>{},
      );
    } finally {
      http.close();
    }
  }

  test('state reports setup required only for generated passwords', () async {
    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0);
    var res = await webui('GET', '/app/api/state');
    expect(res.status, 200);
    expect(res.body['setupRequired'], isTrue);
    await server!.stop();
    await Hive.close();

    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0, password: password);
    res = await webui('GET', '/app/api/state');
    expect(res.body['setupRequired'], isFalse);
  });

  test('web ui setup claims the server exactly once', () async {
    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0);
    final setup =
        await webui('POST', '/app/api/setup', json: {'password': 'chosen'});
    expect(setup.status, 200);
    final token = setup.body['token'] as String;
    expect(token, isNotEmpty);

    final second =
        await webui('POST', '/app/api/setup', json: {'password': 'other'});
    expect(second.status, 409);

    // the chosen password works for sync clients too
    client = DoudouSyncClient(baseUrl: 'http://127.0.0.1:${server!.port}');
    await client!.login('chosen');

    // and the new password persists across restarts
    await server!.stop();
    await Hive.close();
    server = DoudouSyncServer(dataDir: dataDir.path);
    await server!.start(port: 0);
    final res = await webui('GET', '/app/api/state');
    expect(res.body['setupRequired'], isFalse);
  });

  test('web ui login issues a session that logout revokes', () async {
    await boot();
    final bad =
        await webui('POST', '/app/api/login', json: {'password': 'nope'});
    expect(bad.status, 401);

    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    expect(login.status, 200);
    final token = login.body['token'] as String;

    final boxes = await webui('GET', '/app/api/boxes', token: token);
    expect(boxes.status, 200);

    await webui('POST', '/app/api/logout', token: token);
    final after = await webui('GET', '/app/api/boxes', token: token);
    expect(after.status, 401);
  });

  test('web ui session endpoints reject missing tokens', () async {
    await boot();
    for (final path in [
      '/app/api/boxes',
      '/app/api/logs',
      '/app/api/backends',
      '/app/api/export.hmb',
    ]) {
      final res = await webui('GET', path);
      expect(res.status, 401, reason: path);
    }
  });

  test('hosted backends round trip to sync clients', () async {
    await boot();
    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    final token = login.body['token'] as String;

    final created =
        await webui('POST', '/app/api/backends', token: token, json: {
      'name': 'Home Jellyfin',
      'type': 'jellyfin',
      'serverUrl': 'http://jf.local:8096',
      'username': 'cal',
      'password': 'pw',
    });
    expect(created.status, 200);
    expect(created.body['id'], 1);

    await webui('POST', '/app/api/backends',
        token: token, json: {'name': 'YTM', 'type': 'youtubeMusic'});

    await client!.login(password);
    final hosted = await client!.listBackends();
    expect(hosted.revision, 2);
    expect(hosted.backends, hasLength(2));
    expect(hosted.backends[0]['name'], 'Home Jellyfin');
    expect(hosted.backends[1]['type'], 'youtubeMusic');

    final updated = await webui('PUT', '/app/api/backends/1',
        token: token, json: {'name': 'Renamed'});
    expect(updated.status, 200);
    expect(updated.body['name'], 'Renamed');
    expect(updated.body['serverUrl'], 'http://jf.local:8096');

    final deleted = await webui('DELETE', '/app/api/backends/2', token: token);
    expect(deleted.status, 200);

    final after = await client!.listBackends();
    expect(after.backends, hasLength(1));
    expect(after.revision, greaterThan(hosted.revision));
  });

  test('backend validation rejects bad payloads', () async {
    await boot();
    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    final token = login.body['token'] as String;

    Future<int> attempt(Map<String, Object?> json) async =>
        (await webui('POST', '/app/api/backends', token: token, json: json))
            .status;

    expect(await attempt({'type': 'jellyfin'}), 400);
    expect(await attempt({'name': 'x', 'type': 'napster'}), 400);
    expect(await attempt({'name': 'x', 'type': 'jellyfin'}), 400);
    expect(
        await attempt({
          'name': 'x',
          'type': 'subsonic',
          'serverUrl': 'http://n.local',
        }),
        200);
  });

  test('the backends box stays out of the generic box api', () async {
    await boot();
    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    final token = login.body['token'] as String;
    await webui('POST', '/app/api/backends',
        token: token, json: {'name': 'YTM', 'type': 'youtubeMusic'});

    await client!.login(password);
    final boxes = await client!.listBoxes();
    expect(boxes.map((b) => b.name), isNot(contains('DoudouBackends')));
    expect(() => client!.getBox('DoudouBackends'),
        throwsA(isA<SyncServerException>()));
  });

  test('hosted backends survive an hmb export and import', () async {
    await boot();
    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    final token = login.body['token'] as String;
    await webui('POST', '/app/api/backends',
        token: token, json: {'name': 'YTM', 'type': 'youtubeMusic'});
    await client!.login(password);
    final bytes = await client!.exportHmb();
    expect(ZipDecoder().decodeBytes(bytes).map((f) => f.name),
        contains('doudoubackends.hive'));

    final hmbPath = '${scratchDir.path}/backup.hmb';
    await File(hmbPath).writeAsBytes(bytes);
    await server!.importHmb(hmbPath);
    final hosted = await client!.listBackends();
    expect(hosted.backends.single['name'], 'YTM');
  });

  test('password change rotates credentials but keeps the sync token',
      () async {
    await boot();
    await client!.login(password);
    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    final token = login.body['token'] as String;

    final wrong = await webui('POST', '/app/api/password',
        token: token, json: {'current': 'nope', 'next': 'next'});
    expect(wrong.status, 401);

    final changed = await webui('POST', '/app/api/password',
        token: token, json: {'current': password, 'next': 'brand-new'});
    expect(changed.status, 200);

    // old password no longer logs in, new one does
    final oldLogin =
        await webui('POST', '/app/api/login', json: {'password': password});
    expect(oldLogin.status, 401);
    final newLogin =
        await webui('POST', '/app/api/login', json: {'password': 'brand-new'});
    expect(newLogin.status, 200);

    // the shared sync token is untouched so clients keep working
    expect(await client!.listBoxes(), isA<List<SyncBoxInfo>>());
  });

  test('logs endpoint returns events with a since filter', () async {
    await boot();
    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    final token = login.body['token'] as String;

    final res = await webui('GET', '/app/api/logs', token: token);
    expect(res.status, 200);
    final entries = res.body['entries'] as List;
    expect(entries, isNotEmpty);
    final latest = res.body['latest'] as int;
    expect(latest, greaterThan(0));

    final filtered =
        await webui('GET', '/app/api/logs?after=$latest', token: token);
    expect((filtered.body['entries'] as List), isEmpty);
    expect(filtered.body['latest'], latest);
  });

  test('import over the web ui api seeds the database', () async {
    // same hmb fixture as the direct import test
    final hiveDir = '${scratchDir.path}/hivesrc';
    Directory(hiveDir).createSync();
    Hive.init(hiveDir);
    final srcBox = await Hive.openBox('RemoteSongs');
    await srcBox.put('s_0', {'title': 'Remote'});
    await srcBox.close();
    await Hive.close();

    final archive = Archive();
    final hiveBytes = await File('$hiveDir/remotesongs.hive').readAsBytes();
    archive
        .addFile(ArchiveFile('RemoteSongs.hive', hiveBytes.length, hiveBytes));
    final hmbBytes = ZipEncoder().encode(archive)!;

    await boot();
    final login =
        await webui('POST', '/app/api/login', json: {'password': password});
    final token = login.body['token'] as String;

    final res = await webui('POST', '/app/api/import.hmb',
        token: token, bytes: hmbBytes);
    expect(res.status, 200);
    expect(res.body['imported'], contains('RemoteSongs'));

    await client!.login(password);
    final snap = await client!.getBox('RemoteSongs');
    expect(snap.entries['s_0']!.value, isA<Map>());
  });

  test('web ui statics serve the bundle and root redirects', () async {
    await boot();
    final http = HttpClient();

    final root =
        await http.getUrl(Uri.parse('http://127.0.0.1:${server!.port}/'));
    root.followRedirects = false;
    final rootRes = await root.close();
    expect(rootRes.statusCode, 301);
    expect(rootRes.headers.value(HttpHeaders.locationHeader), '/app/');
    await utf8.decodeStream(rootRes);

    final index =
        await http.getUrl(Uri.parse('http://127.0.0.1:${server!.port}/app/'));
    final indexRes = await index.close();
    expect(indexRes.statusCode, 200);
    expect(indexRes.headers.contentType?.mimeType, 'text/html');
    final body = await utf8.decodeStream(indexRes);
    expect(body, contains('flutter_bootstrap'));

    http.close();
  });
}
