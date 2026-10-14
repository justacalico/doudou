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
    service = Get.put(ServerSyncService(), permanent: true);

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

  test('removing a hosted backend removes the remote server', () async {
    server = DoudouSyncServer(dataDir: serverDir.path);
    await server!.start(port: 0, password: password);
    await addBackend({'name': 'YTM host', 'type': 'youtubeMusic'});

    Hive.init(clientDir.path);
    await Hive.openBox('AppPrefs');
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    service = Get.put(ServerSyncService(), permanent: true);

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
