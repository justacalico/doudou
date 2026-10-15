import 'dart:convert';
import 'dart:io';

import 'package:doudou/models/server.dart';
import 'package:doudou/server/doudou_server.dart';
import 'package:doudou/services/server_sync_service.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';
import 'package:doudou/server/sync_client.dart';
import 'package:doudou/server/sync_model.dart';

void main() {
  late Directory serverDir;
  late Directory clientDir;
  DoudouSyncServer? server;
  ServerSyncService? service;

  const password = 'test-password';

  setUp(() async {
    serverDir = await Directory.systemTemp.createTemp('sync_srv_');
    clientDir = await Directory.systemTemp.createTemp('sync_client_');
  });

  tearDown(() async {
    await Get.delete<ServerSyncService>(force: true);
    await Get.delete<SettingsScreenController>(force: true);
    service = null;
    await server?.stop();
    server = null;
    await Hive.close();
    if (serverDir.existsSync()) await serverDir.delete(recursive: true);
    if (clientDir.existsSync()) await clientDir.delete(recursive: true);
  });

  Future<String> webuiSession() async {
    final http = HttpClient();
    final request = await http
        .postUrl(Uri.parse('http://127.0.0.1:${server!.port}/app/api/login'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'password': password}));
    final response = await request.close();
    final body = jsonDecode(await utf8.decodeStream(response)) as Map;
    http.close();
    return body['token'] as String;
  }

  Future<void> addBackend(Map<String, Object?> backend) async {
    final token = await webuiSession();
    final http = HttpClient();
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${server!.port}/app/api/backends'));
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode(backend));
    final response = await request.close();
    await utf8.decodeStream(response);
    http.close();
    expect(response.statusCode, 200);
  }

  Future<void> waitForSync() async {
    for (var i = 0; i < 300; i++) {
      if (service != null &&
          !service!.isSyncing.value &&
          service!.lastSyncAt.value != null) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
    fail('sync cycle never finished');
  }

  test('hosted backends reach the client as remote servers', () async {
    // the server must boot before the client hive home is chosen: Hive has
    // one global home and the server's boxes have to live in serverDir.
    server = DoudouSyncServer(dataDir: serverDir.path);
    await server!.start(port: 0, password: password);
    await addBackend({
      'name': 'Home Jellyfin',
      'type': 'jellyfin',
      'serverUrl': 'http://jf.local:8096',
      'username': 'cal',
      'password': 'pw',
    });
    await addBackend({'name': 'YTM host', 'type': 'youtubeMusic'});

    Hive.init(clientDir.path);
    final prefs = await Hive.openBox('AppPrefs');
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    service = ServerSyncService()..onInit();
    Get.put<ServerSyncService>(service!, permanent: true);

    final error = await service!
        .connect(url: 'http://127.0.0.1:${server!.port}', password: password);
    expect(error, isNull);
    await waitForSync();

    expect(service!.remoteServers, hasLength(2));
    final jellyfin =
        service!.remoteServers.firstWhere((s) => s.name == 'Home Jellyfin');
    expect(jellyfin.isRemote, isTrue);
    expect(jellyfin.id, -1);
    expect(jellyfin.serverUrl, 'http://jf.local:8096');
    expect(jellyfin.type, ServerType.jellyfin);
    expect(jellyfin.password, 'pw');
    final ytm = service!.remoteServers
        .firstWhere((s) => s.type == ServerType.youtubeMusic);
    expect(ytm.id, -2);

    // persisted so the next launch shows them before the first sync
    final stored = prefs.get('syncedServers') as List;
    expect(stored, hasLength(2));

    await service!.disconnect();
    expect(service!.remoteServers, isEmpty);
    expect(prefs.get('syncedServers'), isNull);
    expect(prefs.get('syncedBackendsRev'), isNull);
  });

  Future<DoudouSyncClient> loggedInClient() async {
    final c = DoudouSyncClient(baseUrl: 'http://127.0.0.1:${server!.port}');
    await c.login(password);
    return c;
  }

  Future<void> boot() async {
    // Drop boxes left open by earlier test files: Hive.openBox ignores the
    // new home when a box with the same name is already open.
    await Hive.close();
    server = DoudouSyncServer(dataDir: serverDir.path);
    await server!.start(port: 0, password: password);
    Hive.init(clientDir.path);
    await Hive.openBox('AppPrefs');
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    service = ServerSyncService()..onInit();
    Get.put<ServerSyncService>(service!, permanent: true);
    await service!
        .connect(url: 'http://127.0.0.1:${server!.port}', password: password);
    await waitForSync();
  }

  test('local writes push straight to the server', () async {
    await boot();
    final fav = await Hive.openBox('LIBFAV');
    await fav.put('song1', {'title': 'Pushed'});

    final remote = await loggedInClient();
    var revision = 0;
    for (var i = 0; i < 100; i++) {
      final snap = await remote.getBox('LIBFAV');
      revision = snap.revision;
      if (revision > 0) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    expect(revision, greaterThan(0),
        reason: 'the write never reached the server');
    remote.close();
  });

  test('remote deletes reach the client on the next pull', () async {
    await boot();
    final remote = await loggedInClient();
    await remote.pushOps('LIBFAV', [SyncOp.put('doomed', {'t': 1}, 1000)]);

    await service!.pullForRead({'LIBFAV'});
    final fav = await Hive.openBox('LIBFAV');
    expect(fav.containsKey('doomed'), isTrue);

    // The delete has to beat real clock timestamps: the service's own
    // write-through may have repushed the key with the current time.
    await remote.pushOps('LIBFAV', [
      SyncOp.delete(
          'doomed', DateTime.now().millisecondsSinceEpoch + 60000),
    ]);
    await service!.pullForRead({'LIBFAV'});
    expect(fav.containsKey('doomed'), isFalse);
    remote.close();
  });

  test('a fresh server gets repopulated from the client on connect', () async {
    await Hive.close();
    server = DoudouSyncServer(dataDir: serverDir.path);
    await server!.start(port: 0, password: password);
    Hive.init(clientDir.path);
    await Hive.openBox('AppPrefs');
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    final fav = await Hive.openBox('LIBFAV');
    await fav.put('seed', {'title': 'Kept'});

    service = ServerSyncService()..onInit();
    Get.put<ServerSyncService>(service!, permanent: true);
    await service!
        .connect(url: 'http://127.0.0.1:${server!.port}', password: password);
    await waitForSync();

    final remote = await loggedInClient();
    final snap = await remote.getBox('LIBFAV');
    expect(snap.revision, greaterThan(0));
    remote.close();
  });

  test('pullForRead ignores boxes that are not part of the library', () async {
    await boot();
    final cache = await Hive.openBox('SongsCache');
    await cache.put('local', {'title': 'Never pushed'});

    await service!.pullForRead({'SongsCache'});

    final remote = await loggedInClient();
    final names = (await remote.listBoxes()).map((b) => b.name).toList();
    expect(names.map((n) => n.toLowerCase()),
        isNot(contains('songscache')));
    remote.close();
  });

  test('pullForRead fetches boxes for a remote hosted server', () async {
    await boot();
    Get.find<SettingsScreenController>().activeServerId.value = -1;
    final remote = await loggedInClient();
    await remote.pushOps('LIBFAV_s_-1', [SyncOp.put('fav1', {'t': 'x'}, 1)]);

    await service!.pullForRead({'LIBFAV_s_-1'});

    expect(service!.lastError.value, isEmpty,
        reason: 'pull failed: ${service!.lastError.value}');
    final fav = await Hive.openBox('LIBFAV_s_-1');
    expect(fav.containsKey('fav1'), isTrue);
    remote.close();
  });

  test('removing a hosted backend removes the remote server', () async {
    server = DoudouSyncServer(dataDir: serverDir.path);
    await server!.start(port: 0, password: password);
    await addBackend({'name': 'YTM host', 'type': 'youtubeMusic'});

    Hive.init(clientDir.path);
    await Hive.openBox('AppPrefs');
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    service = ServerSyncService()..onInit();
    Get.put<ServerSyncService>(service!, permanent: true);

    await service!
        .connect(url: 'http://127.0.0.1:${server!.port}', password: password);
    await waitForSync();
    expect(service!.remoteServers, hasLength(1));

    final token = await webuiSession();
    final http = HttpClient();
    final request = await http.deleteUrl(
        Uri.parse('http://127.0.0.1:${server!.port}/app/api/backends/1'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    await utf8.decodeStream(response);
    http.close();
    expect(response.statusCode, 200);

    service!.lastSyncAt.value = null;
    await service!.syncNow();
    expect(service!.remoteServers, isEmpty);
  });
}
