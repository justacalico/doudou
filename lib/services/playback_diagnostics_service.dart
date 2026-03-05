import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class PlaybackDiagnosticsService extends GetxService {
  static const String boxName = 'PlaybackDiagnostics';
  static const String appPrefsBoxName = 'AppPrefs';
  static const String enabledKey = 'playbackDiagnosticsEnabled';
  static const int _maxEvents = 400;

  String? _sessionId;

  String get _activeSessionId {
    _sessionId ??=
        '${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch.remainder(1000000)}';
    return _sessionId!;
  }

  bool get enabled {
    try {
      return Hive.box(appPrefsBoxName).get(enabledKey, defaultValue: false) ==
          true;
    } catch (_) {
      return false;
    }
  }

  void logEvent({
    required String category,
    required String message,
    String? songId,
    String? backendType,
    String? activeServerType,
    Map<String, dynamic>? data,
  }) {
    if (!enabled) return;
    try {
      final box = Hive.box(boxName);
      final event = <String, dynamic>{
        'ts': DateTime.now().toUtc().toIso8601String(),
        'sessionId': _activeSessionId,
        'category': category,
        'message': message,
      };
      if (songId != null && songId.isNotEmpty) {
        event['songId'] = songId;
      }
      if (backendType != null && backendType.isNotEmpty) {
        event['backendType'] = backendType;
      }
      if (activeServerType != null && activeServerType.isNotEmpty) {
        event['activeServerType'] = activeServerType;
      }
      if (data != null && data.isNotEmpty) {
        event['data'] = _sanitizeMap(data);
      }
      box.add(event);
      while (box.length > _maxEvents) {
        box.deleteAt(0);
      }
    } catch (_) {
      // Never block playback due to diagnostics failure.
    }
  }

  Future<void> clear() async {
    try {
      await Hive.box(boxName).clear();
    } catch (_) {}
  }

  Future<String?> exportToPickedLocation() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'doudou_playback_diag_$timestamp.jsonl';

    String? outputPath;

    try {
      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save playback diagnostics',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['jsonl', 'txt'],
      );
    } catch (_) {
      outputPath = null;
    }

    if (outputPath == null || outputPath.isEmpty) {
      final dir = await FilePicker.platform
          .getDirectoryPath(dialogTitle: 'Select export folder');
      if (dir == null || dir.isEmpty) return null;
      outputPath = '$dir/$filename';
    }

    final lines = <String>[];
    final box = Hive.box(boxName);
    for (final item in box.values) {
      if (item is Map) {
        lines.add(jsonEncode(_sanitizeMap(item.cast<dynamic, dynamic>())));
      }
    }

    await File(outputPath).writeAsString('${lines.join('\n')}\n');
    return outputPath;
  }

  static String sanitizeUrl(String? input) {
    if (input == null || input.isEmpty) return '';
    try {
      final uri = Uri.parse(input);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return _truncate(input);
      }
      final sanitized = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      );
      return _truncate(sanitized.toString());
    } catch (_) {
      return _truncate(input.split('?').first);
    }
  }

  static Map<String, dynamic> _sanitizeMap(Map<dynamic, dynamic> data) {
    final output = <String, dynamic>{};
    data.forEach((key, value) {
      final k = key.toString();
      final keyLower = k.toLowerCase();
      if (keyLower.contains('token') ||
          keyLower.contains('auth') ||
          keyLower.contains('password') ||
          keyLower.contains('cookie')) {
        output[k] = '***';
        return;
      }
      output[k] = _sanitizeValue(k, value);
    });
    return output;
  }

  static dynamic _sanitizeValue(String key, dynamic value) {
    if (value == null) return null;
    if (value is Map) return _sanitizeMap(value);
    if (value is List) {
      return value.map((v) => _sanitizeValue(key, v)).toList();
    }
    if (value is String) {
      final keyLower = key.toLowerCase();
      if (keyLower.contains('url') || value.startsWith('http')) {
        return sanitizeUrl(value);
      }
      return _truncate(value);
    }
    return value;
  }

  static String _truncate(String s, {int max = 220}) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }
}
