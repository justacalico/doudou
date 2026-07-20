import 'dart:convert';

import 'package:dio/dio.dart';

import '/models/doudou_server.dart';

/// One music server entry as mirrored from doudou-server. Same shape the
/// server stores, minus credentials.
class RemoteMusicServer {
  RemoteMusicServer({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String type;
  final String url;
  final bool isDefault;

  factory RemoteMusicServer.fromJson(Map<String, dynamic> json) =>
      RemoteMusicServer(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        url: json['url'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

class RemoteSnapshot {
  RemoteSnapshot({
    required this.musicServerId,
    required this.kind,
    required this.version,
    required this.updatedAtMs,
    required this.payload,
  });

  final String musicServerId;
  final String kind;
  final int version;
  final int updatedAtMs;
  final String payload;

  factory RemoteSnapshot.fromJson(Map<String, dynamic> json) => RemoteSnapshot(
        musicServerId: json['musicServerId'] as String,
        kind: json['kind'] as String,
        version: json['version'] as int? ?? 0,
        updatedAtMs: json['updatedAtMs'] as int? ?? 0,
        payload: json['payload'] as String? ?? '[]',
      );
}

/// Thin HTTP client for the doudou-server REST API.
class DoudouServerClient {
  DoudouServerClient(this._config) : _dio = Dio(BaseOptions(
        baseUrl: _config.url.replaceAll(RegExp(r'/+$'), ''),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'X-Doudou-Key': _config.key},
      ));

  final DoudouServerConfig _config;
  final Dio _dio;

  DoudouServerConfig get config => _config;

  Future<bool> health() async {
    try {
      final res = await _dio.get('/api/v1/health');
      return res.statusCode == 200 &&
          (res.data as Map<String, dynamic>)['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<List<RemoteMusicServer>> listServers() async {
    final res = await _dio.get('/api/v1/servers');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => RemoteMusicServer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertServer(RemoteMusicServer server) async {
    await _dio.put('/api/v1/servers', data: {
      'id': server.id,
      'name': server.name,
      'type': server.type,
      'url': server.url,
      'isDefault': server.isDefault,
    });
  }

  Future<void> deleteServer(String id) async {
    await _dio.delete('/api/v1/servers/$id');
  }

  Future<List<RemoteSnapshot>> listSnapshots(String musicServerId) async {
    final res = await _dio.get('/api/v1/snapshots',
        queryParameters: {'musicServerId': musicServerId});
    final list = res.data as List<dynamic>;
    return list
        .map((e) => RemoteSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Pushes a library snapshot. Returns true if the server accepted it.
  Future<bool> pushSnapshot({
    required String musicServerId,
    required String kind,
    required int version,
    required String payload,
  }) async {
    final res = await _dio.put('/api/v1/snapshots', data: {
      'musicServerId': musicServerId,
      'kind': kind,
      'version': version,
      'payload': payload,
    });
    final data = res.data as Map<String, dynamic>;
    return data['accepted'] == true;
  }

  Future<void> registerClient(String clientId, String name) async {
    await _dio.post('/api/v1/clients/register', data: {
      'id': clientId,
      'name': name,
    });
  }

  void close() => _dio.close();
}

/// Encodes a list of maps into the JSON string the server expects as a
/// snapshot payload.
String encodeSnapshotPayload(List<Map<String, dynamic>> items) =>
    jsonEncode(items);

List<Map<String, dynamic>> decodeSnapshotPayload(String payload) {
  if (payload.isEmpty) return [];
  final decoded = jsonDecode(payload);
  if (decoded is List) {
    return decoded
        .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
        .toList();
  }
  return [];
}
