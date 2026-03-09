import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../ui/screens/Settings/settings_screen_controller.dart';
import '../utils/helper.dart';
import 'playback_diagnostics_service.dart';

class OpenlystSyncService extends GetxService {
  final isSyncing = false.obs;
  final lastError = ''.obs;
  final lastSyncedAt = Rxn<DateTime>();
  final syncState = 'disconnected'.obs;

  Timer? _timer;
  final Dio _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5)));

  String _serverUrl = '';
  String _appApiKey = '';
  String _groupId = '';
  bool _enabled = false;
  int _intervalMinutes = 15;

  static const _keyEnabled = 'openlystSyncEnabled';
  static const _keyServerUrl = 'openlystSyncServerUrl';
  static const _keyAppApiKey = 'openlystSyncAppApiKey';
  static const _keyGroupId = 'openlystSyncGroupId';
  static const _keyClientId = 'openlystSyncClientId';
  static const _keyClientSecret = 'openlystSyncClientSecret';
  static const _keyLastVersion = 'openlystSyncLastVersion';
  static const _keyIntervalMinutes = 'openlystSyncIntervalMinutes';
  static const _keyInstallId = 'openlystSyncInstallId';

  Future<OpenlystSyncService> init() async {
    _loadConfig();
    _restartTimer();
    return this;
  }

  void _loadConfig() {
    final box = Hive.box('AppPrefs');
    _enabled = box.get(_keyEnabled) ?? false;
    _serverUrl = _normalizeServerUrl((box.get(_keyServerUrl) ?? '').toString());
    _appApiKey = (box.get(_keyAppApiKey) ?? '').toString().trim();
    _groupId = (box.get(_keyGroupId) ?? '').toString().trim();
    _intervalMinutes = (box.get(_keyIntervalMinutes) ?? 15) as int;
    if (_intervalMinutes < 1) _intervalMinutes = 1;
    syncState.value = _enabled ? 'connected_idle' : 'disconnected';
  }

  void reloadConfig() {
    _loadConfig();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_enabled) return;
    _timer = Timer.periodic(Duration(minutes: _intervalMinutes), (_) {
      syncNow();
    });
  }

  Future<void> syncNow() async {
    if (isSyncing.value) return;
    _loadConfig();
    if (!_enabled) return;
    if (_serverUrl.isEmpty || _appApiKey.isEmpty) {
      lastError.value =
          'Openlyst sync is enabled but missing server URL or API key.';
      syncState.value = 'error';
      return;
    }

    isSyncing.value = true;
    lastError.value = '';
    try {
      await _syncCycle();
      lastSyncedAt.value = DateTime.now();
      syncState.value = 'connected_idle';
    } catch (e, st) {
      if (_canAutoHeal(e)) {
        try {
          syncState.value = 'error_recovering';
          await _recoverSession();
          await _syncCycle();
          lastSyncedAt.value = DateTime.now();
          syncState.value = 'connected_idle';
          lastError.value = '';
        } catch (healErr, healSt) {
          lastError.value = healErr.toString();
          syncState.value = 'error';
          printERROR(
              '[RECOVERABLE][opId=openlyst.syncNow.autoHeal] $healErr\n$healSt');
        }
      } else {
        lastError.value = e.toString();
        syncState.value = 'error';
        printERROR('[RECOVERABLE][opId=openlyst.syncNow] $e\n$st');
      }
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _syncCycle() async {
    syncState.value = 'connecting';
    final token = await _ensureClientToken();
    await _syncServerSession(token);
    if (_groupId.isEmpty) {
      throw Exception('Openlyst sync group is not assigned yet.');
    }

    await _heartbeat(token, phase: 'start', syncing: true);

    syncState.value = 'syncing_push';
    await _pushSnapshot(token);

    syncState.value = 'syncing_pull';
    await _pullSnapshots(token);

    final lastVersion = Hive.box('AppPrefs').get(_keyLastVersion) as int?;
    await _heartbeat(
      token,
      phase: 'complete',
      syncing: false,
      lastVersionSeen: lastVersion,
    );
  }

  Future<void> login({
    required String serverUrl,
    required String apiKey,
  }) async {
    final normalizedUrl = _normalizeServerUrl(serverUrl);
    final normalizedKey = apiKey.trim();
    if (normalizedUrl.isEmpty) {
      throw Exception('Openlyst server URL is required.');
    }
    if (normalizedKey.isEmpty) {
      throw Exception('Openlyst API key is required.');
    }

    final box = Hive.box('AppPrefs');
    final prevEnabled = box.get(_keyEnabled);
    final prevServerUrl = box.get(_keyServerUrl);
    final prevApiKey = box.get(_keyAppApiKey);
    final prevGroupId = box.get(_keyGroupId);
    final prevClientId = box.get(_keyClientId);
    final prevClientSecret = box.get(_keyClientSecret);

    try {
      await box.put(_keyServerUrl, normalizedUrl);
      await box.put(_keyAppApiKey, normalizedKey);
      await box.put(_keyGroupId, '');
      await box.put(_keyClientId, '');
      await box.put(_keyClientSecret, '');
      await box.put(_keyEnabled, true);
      _loadConfig();
      await _ensureClientToken();
      _restartTimer();
      lastError.value = '';
      syncState.value = 'connected_idle';
    } catch (e) {
      await box.put(_keyEnabled, prevEnabled);
      await box.put(_keyServerUrl, prevServerUrl);
      await box.put(_keyAppApiKey, prevApiKey);
      await box.put(_keyGroupId, prevGroupId);
      await box.put(_keyClientId, prevClientId);
      await box.put(_keyClientSecret, prevClientSecret);
      _loadConfig();
      _restartTimer();
      syncState.value = 'error';
      rethrow;
    }
  }

  Future<void> logout() async {
    final box = Hive.box('AppPrefs');
    await box.put(_keyEnabled, false);
    await box.put(_keyServerUrl, '');
    await box.put(_keyAppApiKey, '');
    await box.put(_keyGroupId, '');
    await box.put(_keyClientId, '');
    await box.put(_keyClientSecret, '');
    _loadConfig();
    _restartTimer();
    lastError.value = '';
    lastSyncedAt.value = null;
    syncState.value = 'disconnected';
  }

  Future<void> _recoverSession() async {
    final box = Hive.box('AppPrefs');
    await box.put(_keyClientId, '');
    await box.put(_keyClientSecret, '');
    await box.put(_keyGroupId, '');
    _groupId = '';
  }

  bool _canAutoHeal(Object error) {
    if (error is OpenlystSyncException) {
      final code = error.statusCode;
      if (code == 401 || code == 403 || code == 409) return true;
      final msg = error.message.toLowerCase();
      return msg.contains('invalid client credentials') ||
          msg.contains('bound to another client') ||
          msg.contains('invalid client token');
    }
    final text = error.toString().toLowerCase();
    return text.contains('invalid client credentials') ||
        text.contains('invalid client token');
  }

  Future<String> _ensureClientToken() async {
    final box = Hive.box('AppPrefs');
    var clientId = (box.get(_keyClientId) ?? '').toString();
    var clientSecret = (box.get(_keyClientSecret) ?? '').toString();
    var groupId = (box.get(_keyGroupId) ?? '').toString();

    if (clientId.isEmpty || clientSecret.isEmpty || groupId.isEmpty) {
      final r = await _postWithRetry(
        '$_serverUrl/api/v1/client/login',
        data: {
          'app_id': 'doudou',
          'api_key': _appApiKey,
          'client_name': _buildClientName(box),
          'platform': Platform.operatingSystem,
        },
        maxAttempts: 2,
      );
      clientId = (r.data['client_id'] as String?) ?? '';
      clientSecret = (r.data['client_secret'] as String?) ?? '';
      final token = (r.data['access_token'] as String?) ?? '';
      groupId = (r.data['group_id'] as String?) ?? '';
      if (clientId.isEmpty || clientSecret.isEmpty || groupId.isEmpty) {
        throw Exception('Failed to login Doudou on Openlyst Server');
      }
      await box.put(_keyClientId, clientId);
      await box.put(_keyClientSecret, clientSecret);
      await box.put(_keyGroupId, groupId);
      _groupId = groupId;
      if (token.isNotEmpty) return token;
    }

    final tokenRes = await _postWithRetry(
      '$_serverUrl/api/v1/client/auth/refresh',
      data: {
        'client_id': clientId,
        'client_secret': clientSecret,
      },
      maxAttempts: 2,
    );
    final token = (tokenRes.data['access_token'] as String?) ?? '';
    if (token.isEmpty) {
      throw Exception('Failed to refresh Doudou client token');
    }
    _groupId = (box.get(_keyGroupId) ?? '').toString().trim();
    return token;
  }

  Future<void> _syncServerSession(String token) async {
    final res = await _getWithRetry(
      '$_serverUrl/api/v1/client/session',
      options: Options(headers: {'authorization': 'Bearer $token'}),
      maxAttempts: 2,
    );
    final serverGroup = (res.data['group_id'] ?? '').toString().trim();
    if (serverGroup.isNotEmpty && serverGroup != _groupId) {
      _groupId = serverGroup;
      await Hive.box('AppPrefs').put(_keyGroupId, serverGroup);
    }
  }

  Future<void> _heartbeat(
    String token, {
    required String phase,
    required bool syncing,
    int? lastVersionSeen,
  }) async {
    if (_groupId.isEmpty) return;
    try {
      await _postWithRetry(
        '$_serverUrl/api/v1/client/heartbeat',
        options: Options(headers: {'authorization': 'Bearer $token'}),
        data: {
          'group_id': _groupId,
          'syncing': syncing,
          'phase': phase,
          if (lastVersionSeen != null) 'last_version_seen': lastVersionSeen,
        },
        maxAttempts: 1,
      );
    } catch (_) {
      // Heartbeat failure should not break main sync path.
    }
  }

  Future<void> _pushSnapshot(String token) async {
    if (_groupId.isEmpty) {
      throw Exception('Openlyst sync group is missing.');
    }
    final files = await _collectSnapshotFiles();
    final settings = Get.find<SettingsScreenController>();
    int estimatedBytes = 0;
    final chunks = <Map<String, dynamic>>[];
    for (var i = 0; i < files.length; i++) {
      final bytes = await files[i].file.readAsBytes();
      estimatedBytes += bytes.length;
      chunks.add({
        'index': i,
        'path': files[i].path,
        'data_base64': base64Encode(bytes),
      });
    }

    final payload = {
      'created_at': DateTime.now().toIso8601String(),
      'active_server_id': settings.activeServerId.value,
      'active_server_name': settings.activeServer?.name,
      'object_count': chunks.length,
      'estimated_total_bytes': estimatedBytes,
    };

    final box = Hive.box('AppPrefs');
    final lastVersion = box.get(_keyLastVersion) as int?;

    final start = await _postWithRetry(
      '$_serverUrl/api/v1/sync/upload/start',
      options: Options(headers: {'authorization': 'Bearer $token'}),
      data: {
        'group_id': _groupId,
        'parent_version': lastVersion,
        'payload': payload,
        'object_count': chunks.length,
      },
    );
    final uploadId = (start.data['upload_id'] as String?) ?? '';
    if (uploadId.isEmpty) {
      throw Exception('Openlyst upload start failed (missing upload_id)');
    }

    for (final chunk in chunks) {
      await _postWithRetry(
        '$_serverUrl/api/v1/sync/upload/$uploadId/chunk',
        options: Options(headers: {'authorization': 'Bearer $token'}),
        data: chunk,
      );
    }

    final commit = await _postWithRetry(
      '$_serverUrl/api/v1/sync/upload/$uploadId/commit',
      options: Options(headers: {'authorization': 'Bearer $token'}),
      data: {'expected_chunks': chunks.length},
    );
    final version = (commit.data['version'] as num?)?.toInt();
    if (version != null) {
      await box.put(_keyLastVersion, version);
    }
  }

  String _buildClientName(Box<dynamic> box) {
    var installId = (box.get(_keyInstallId) ?? '').toString().trim();
    if (installId.isEmpty) {
      final rand = Random.secure().nextInt(0x7fffffff).toRadixString(16);
      installId =
          '${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}$rand';
      box.put(_keyInstallId, installId);
    }
    return '${Platform.operatingSystem}-doudou-$installId';
  }

  String _normalizeServerUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String _dioErrorMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 413) {
      return 'Snapshot is too large for current server limits.';
    }
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection interrupted during sync upload.';
    }
    return e.message ?? 'Openlyst request failed';
  }

  Future<dynamic> _postWithRetry(
    String url, {
    Options? options,
    Map<String, dynamic>? data,
    int maxAttempts = 3,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await _dio.post(url, options: options, data: data);
      } on DioException catch (e) {
        final transient = _isTransientDioError(e);
        if (!transient || attempt >= maxAttempts) {
          throw _toSyncException(e);
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  Future<dynamic> _getWithRetry(
    String url, {
    Options? options,
    Map<String, dynamic>? queryParameters,
    int maxAttempts = 3,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await _dio.get(
          url,
          options: options,
          queryParameters: queryParameters,
        );
      } on DioException catch (e) {
        final transient = _isTransientDioError(e);
        if (!transient || attempt >= maxAttempts) {
          throw _toSyncException(e);
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  OpenlystSyncException _toSyncException(DioException e) {
    return OpenlystSyncException(
      _dioErrorMessage(e),
      statusCode: e.response?.statusCode,
      transient: _isTransientDioError(e),
    );
  }

  bool _isTransientDioError(DioException e) {
    if (e.response?.statusCode == 413) return false;
    if (e.response?.statusCode != null) return false;
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.error is SocketException;
  }

  Future<void> _pullSnapshots(String token) async {
    if (_groupId.isEmpty) {
      throw Exception('Openlyst sync group is missing.');
    }
    final box = Hive.box('AppPrefs');
    final since = box.get(_keyLastVersion) as int?;

    final r = await _getWithRetry(
      '$_serverUrl/api/v1/sync/pull',
      options: Options(headers: {'authorization': 'Bearer $token'}),
      queryParameters: {
        'group_id': _groupId,
        if (since != null) 'since': since,
      },
    );

    final snapshots = (r.data['snapshots'] as List?) ?? [];
    final localClientId = (box.get(_keyClientId) ?? '').toString();

    for (final dynamic row in snapshots) {
      final map = Map<String, dynamic>.from(row as Map);
      final sourceClient = (map['client_id'] ?? '').toString();
      if (sourceClient == localClientId) {
        final v = (map['version'] as num?)?.toInt();
        if (v != null) {
          await box.put(_keyLastVersion, v);
        }
        continue;
      }
      await _applySnapshot(map);
      final v = (map['version'] as num?)?.toInt();
      if (v != null) {
        await box.put(_keyLastVersion, v);
      }
    }
  }

  Future<void> _applySnapshot(Map<String, dynamic> snapshot) async {
    final objects = (snapshot['objects'] as List?) ?? const [];
    if (objects.isEmpty) return;

    final settings = Get.find<SettingsScreenController>();
    final dbDir = await settings.dbDir;
    final supportDir = settings.supportDirPath;
    final snapshotId = (snapshot['snapshot_id'] ?? 'unknown').toString();

    final stageDir = Directory('$supportDir/.openlyst_sync_stage/$snapshotId');
    if (await stageDir.exists()) {
      await stageDir.delete(recursive: true);
    }
    await stageDir.create(recursive: true);

    final stagedWrites = <_StagedWrite>[];

    try {
      var idx = 0;
      for (final dynamic row in objects) {
        final m = Map<String, dynamic>.from(row as Map);
        final relPath = (m['path'] ?? '').toString();
        final data64 = (m['data_base64'] ?? '').toString();
        if (relPath.isEmpty || data64.isEmpty) continue;

        final bytes = base64Decode(data64);
        final normalized = relPath.replaceAll('\\', '/');
        final targetPath = normalized.startsWith('db/')
            ? '$dbDir/${normalized.substring(3)}'
            : normalized.startsWith('support/')
                ? '$supportDir/${normalized.substring(8)}'
                : '$dbDir/$normalized';

        final stagedFile = File('${stageDir.path}/$idx.bin');
        idx += 1;
        await stagedFile.writeAsBytes(bytes, flush: true);
        stagedWrites.add(
            _StagedWrite(stagedPath: stagedFile.path, targetPath: targetPath));
      }

      await Hive.close();
      try {
        for (final write in stagedWrites) {
          final out = File(write.targetPath);
          await out.parent.create(recursive: true);
          final data = await File(write.stagedPath).readAsBytes();
          await out.writeAsBytes(data, flush: true);
        }
      } finally {
        await _reopenCoreBoxes();
      }
    } finally {
      if (await stageDir.exists()) {
        await stageDir.delete(recursive: true);
      }
    }
  }

  Future<void> _reopenCoreBoxes() async {
    await Hive.openBox('SongsCache');
    await Hive.openBox('SongDownloads');
    await Hive.openBox('LIBFAV');
    await Hive.openBox('SongsUrlCache');
    await Hive.openBox('AppPrefs');
    await Hive.openBox(PlaybackDiagnosticsService.boxName);
  }

  Future<List<_SnapshotFile>> _collectSnapshotFiles() async {
    final settings = Get.find<SettingsScreenController>();
    final dbDir = Directory(await settings.dbDir);
    final supportDir = Directory(settings.supportDirPath);

    final out = <_SnapshotFile>[];
    if (await dbDir.exists()) {
      await for (final entity
          in dbDir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel =
            entity.path.substring(dbDir.path.length).replaceAll('\\', '/');
        out.add(_SnapshotFile(path: 'db$rel', file: entity));
      }
    }
    if (await supportDir.exists()) {
      await for (final entity
          in supportDir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel =
            entity.path.substring(supportDir.path.length).replaceAll('\\', '/');
        if (rel.contains('/.openlyst_sync_stage/')) continue;
        out.add(_SnapshotFile(path: 'support$rel', file: entity));
      }
    }
    return out;
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}

class _SnapshotFile {
  _SnapshotFile({required this.path, required this.file});

  final String path;
  final File file;
}

class _StagedWrite {
  _StagedWrite({required this.stagedPath, required this.targetPath});

  final String stagedPath;
  final String targetPath;
}

class OpenlystSyncException implements Exception {
  OpenlystSyncException(this.message, {this.statusCode, this.transient = false});

  final String message;
  final int? statusCode;
  final bool transient;

  @override
  String toString() => message;
}
