import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/utils/helper.dart';

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

  int get eventCount {
    try {
      return Hive.box(boxName).length;
    } catch (_) {
      return 0;
    }
  }

  List<Map<String, dynamic>> getEvents({int? limit}) {
    try {
      final box = Hive.box(boxName);
      final events = box.values
          .whereType<Map>()
          .map((e) => sanitizeLogMap(e.cast<dynamic, dynamic>()))
          .toList();
      if (limit == null || limit <= 0 || events.length <= limit) {
        return events;
      }
      return events.sublist(events.length - limit);
    } catch (_) {
      return const [];
    }
  }

  String getEventsAsJsonl({int? limit}) {
    final events = getEvents(limit: limit);
    if (events.isEmpty) return '';
    return '${events.map(jsonEncode).join('\n')}\n';
  }

  String getEventsAsPrettyText({int? limit}) {
    final events = getEvents(limit: limit);
    if (events.isEmpty) return '';
    final lines = <String>[];
    for (final event in events) {
      final ts = event['ts']?.toString() ?? '';
      final category = event['category']?.toString() ?? 'event';
      final message = event['message']?.toString() ?? '';
      lines.add('[$ts] $category: $message');
      final songId = event['songId']?.toString();
      final backend = event['backendType']?.toString();
      final serverType = event['activeServerType']?.toString();
      if ((songId ?? '').isNotEmpty ||
          (backend ?? '').isNotEmpty ||
          (serverType ?? '').isNotEmpty) {
        lines.add(
            '  songId=${songId ?? "-"} backend=${backend ?? "-"} server=${serverType ?? "-"}');
      }
      if (event['data'] is Map) {
        final dataText = jsonEncode(event['data']);
        lines.add('  data=$dataText');
      }
      lines.add('');
    }
    return lines.join('\n');
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
        'category': sanitizeLogString(category),
        'message': sanitizeLogString(message),
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
        event['data'] = sanitizeLogMap(data);
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
        lines.add(jsonEncode(sanitizeLogMap(item.cast<dynamic, dynamic>())));
      }
    }

    await File(outputPath).writeAsString('${lines.join('\n')}\n');
    return outputPath;
  }

  static String sanitizeUrl(String? input) {
    if (input == null || input.isEmpty) return '';
    return sanitizeLogString(input);
  }
}
