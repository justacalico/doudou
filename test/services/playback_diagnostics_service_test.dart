import 'dart:convert';
import 'dart:io';

import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box appPrefs;
  late Box diagBox;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_diag_test_');
    Hive.init(dir.path);
    appPrefs = await Hive.openBox(PlaybackDiagnosticsService.appPrefsBoxName);
    diagBox = await Hive.openBox(PlaybackDiagnosticsService.boxName);
  });

  tearDownAll(() async {
    await appPrefs.close();
    await diagBox.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
    await diagBox.clear();
  });

  group('PlaybackDiagnosticsService.sanitizeUrl', () {
    test('returns empty string for null input', () {
      expect(PlaybackDiagnosticsService.sanitizeUrl(null), '');
    });

    test('returns empty string for empty input', () {
      expect(PlaybackDiagnosticsService.sanitizeUrl(''), '');
    });

    test('redacts token query parameters in a stream URL', () {
      final sanitized = PlaybackDiagnosticsService.sanitizeUrl(
        'https://example.com/stream?id=1&token=secret&api_key=k',
      );

      expect(sanitized, isNot(contains('secret')));
      expect(sanitized, isNot(contains('api_key=k')));
    });

    test('preserves non-secret query parameters', () {
      final sanitized = PlaybackDiagnosticsService.sanitizeUrl(
        'https://example.com/stream?id=1&name=ok',
      );

      expect(sanitized, contains('id=1'));
      expect(sanitized, contains('name=ok'));
    });

    test('delegates to sanitizeLogString for non-URL strings', () {
      const input = 'Authorization: Bearer abc.def';
      final sanitized = PlaybackDiagnosticsService.sanitizeUrl(input);

      expect(sanitized, isNot(contains('abc.def')));
    });
  });

  group('PlaybackDiagnosticsService.enabled', () {
    test('returns false when key is missing', () {
      final service = PlaybackDiagnosticsService();
      expect(service.enabled, isFalse);
    });

    test('returns true when enabled in AppPrefs', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, true);
      final service = PlaybackDiagnosticsService();
      expect(service.enabled, isTrue);
    });

    test('returns false when explicitly disabled', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, false);
      final service = PlaybackDiagnosticsService();
      expect(service.enabled, isFalse);
    });
  });

  group('PlaybackDiagnosticsService.logEvent', () {
    test('does nothing when disabled', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, false);
      final service = PlaybackDiagnosticsService();
      service.logEvent(category: 'test', message: 'ignored');
      expect(service.eventCount, 0);
    });

    test('stores and returns an event when enabled', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, true);
      final service = PlaybackDiagnosticsService();

      service.logEvent(
        category: 'playback',
        message: 'started',
        songId: 'song-1',
        backendType: 'ytm',
        activeServerType: 'youtube',
        data: {'quality': 'high'},
      );

      expect(service.eventCount, 1);

      final events = service.getEvents();
      expect(events.length, 1);
      expect(events.first['category'], 'playback');
      expect(events.first['message'], 'started');
      expect(events.first['songId'], 'song-1');
      expect(events.first['backendType'], 'ytm');
      expect(events.first['activeServerType'], 'youtube');
      expect(events.first['data'], isA<Map>());
    });

    test('trims old events once max is exceeded', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, true);
      final service = PlaybackDiagnosticsService();

      for (var i = 0; i < 405; i++) {
        service.logEvent(category: 'test', message: 'event-$i');
      }

      expect(service.eventCount, lessThanOrEqualTo(400));
      final events = service.getEvents();
      final messages =
          events.map((e) => e['message'] as String? ?? '').toList();
      expect(messages, contains('event-404'));
      expect(messages, isNot(contains('event-0')));
    });
  });

  group('PlaybackDiagnosticsService.getEvents', () {
    test('returns empty list when box is empty', () {
      final service = PlaybackDiagnosticsService();
      expect(service.getEvents(), isEmpty);
    });

    test('limits events to the requested count', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, true);
      final service = PlaybackDiagnosticsService();

      for (var i = 0; i < 5; i++) {
        service.logEvent(category: 'test', message: 'event-$i');
      }

      final lastTwo = service.getEvents(limit: 2);
      expect(lastTwo.length, 2);
      expect(lastTwo.first['message'], 'event-3');
      expect(lastTwo.last['message'], 'event-4');
    });
  });

  group('PlaybackDiagnosticsService.getEventsAsJsonl', () {
    test('returns empty string when no events', () {
      final service = PlaybackDiagnosticsService();
      expect(service.getEventsAsJsonl(), '');
    });

    test('encodes events as newline-delimited JSON', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, true);
      final service = PlaybackDiagnosticsService();
      service.logEvent(category: 'playback', message: 'started');

      final jsonl = service.getEventsAsJsonl();
      final lines = jsonl.trim().split('\n');
      expect(lines.length, 1);
      final decoded = jsonDecode(lines.first);
      expect(decoded['category'], 'playback');
      expect(decoded['message'], 'started');
    });
  });

  group('PlaybackDiagnosticsService.getEventsAsPrettyText', () {
    test('returns empty string when no events', () {
      final service = PlaybackDiagnosticsService();
      expect(service.getEventsAsPrettyText(), '');
    });

    test('renders a human-readable event', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, true);
      final service = PlaybackDiagnosticsService();
      service.logEvent(
        category: 'playback',
        message: 'started',
        songId: 'song-1',
      );

      final text = service.getEventsAsPrettyText();
      expect(text, contains('playback: started'));
      expect(text, contains('songId=song-1'));
    });
  });

  group('PlaybackDiagnosticsService.clear', () {
    test('removes all events', () async {
      await appPrefs.put(PlaybackDiagnosticsService.enabledKey, true);
      final service = PlaybackDiagnosticsService();
      service.logEvent(category: 'test', message: 'one');
      expect(service.eventCount, 1);

      await service.clear();
      expect(service.eventCount, 0);
      expect(service.getEvents(), isEmpty);
    });
  });
}
