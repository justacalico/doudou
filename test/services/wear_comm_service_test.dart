import 'dart:async';

import 'package:doudou/services/wear_comm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class _MockWatchConnectivity extends Mock implements WatchConnectivity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockWatchConnectivity mockWatch;
  late StreamController<Map<String, dynamic>> ctxController;
  late StreamController<Map<String, dynamic>> msgController;

  setUp(() {
    mockWatch = _MockWatchConnectivity();
    ctxController = StreamController<Map<String, dynamic>>.broadcast();
    msgController = StreamController<Map<String, dynamic>>.broadcast();

    when(() => mockWatch.contextStream)
        .thenAnswer((_) => ctxController.stream);
    when(() => mockWatch.messageStream)
        .thenAnswer((_) => msgController.stream);
    when(() => mockWatch.receivedApplicationContexts)
        .thenAnswer((_) async => []);
    when(() => mockWatch.isReachable).thenAnswer((_) async => false);
    when(() => mockWatch.sendMessage(any()))
        .thenAnswer((_) async {});
  });

  tearDown(() {
    ctxController.close();
    msgController.close();
  });

  group('optimistic reachability', () {
    test('sets isReachable when cached contexts exist', () async {
      final cachedCtx = <Map<String, dynamic>>[
        {
          'type': 'playbackState',
          'title': 'Test Song',
          'artist': 'Test Artist',
          'isPlaying': true,
        }
      ];
      when(() => mockWatch.receivedApplicationContexts)
          .thenAnswer((_) async => cachedCtx);

      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      // Give the async future a chance to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReachable.value, isTrue);
      expect(svc.songTitle.value, 'Test Song');
      expect(svc.songArtist.value, 'Test Artist');
      expect(svc.isPlaying.value, isTrue);
    });

    test('does not set isReachable when no cached contexts', () async {
      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReachable.value, isFalse);
    });
  });

  group('context stream', () {
    test('sets isReachable and updates state on context received', () async {
      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 10));

      ctxController.add({
        'type': 'playbackState',
        'title': 'New Song',
        'artist': 'New Artist',
        'isPlaying': false,
        'positionMs': 5000,
        'durationMs': 200000,
        'isShuffle': true,
        'isLoop': false,
        'isFav': true,
        'queueLength': 10,
        'queueIndex': 3,
        'volume': 75,
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(svc.isReachable.value, isTrue);
      expect(svc.songTitle.value, 'New Song');
      expect(svc.songArtist.value, 'New Artist');
      expect(svc.isPlaying.value, isFalse);
      expect(svc.positionMs.value, 5000);
      expect(svc.durationMs.value, 200000);
      expect(svc.isShuffle.value, isTrue);
      expect(svc.isLoop.value, isFalse);
      expect(svc.isFav.value, isTrue);
      expect(svc.queueLength.value, 10);
      expect(svc.queueIndex.value, 3);
      expect(svc.volume.value, 75);
      expect(svc.isMuted.value, isFalse);
    });

    test('parses serverInfo context', () async {
      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 10));

      ctxController.add({
        'type': 'serverInfo',
        'activeServerId': 2,
        'themeType': 'oled',
        'servers': [
          {'id': 0, 'name': 'Server A', 'type': 'piped'},
          {'id': 1, 'name': 'Server B', 'type': 'hyperpipe'},
        ],
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(svc.activeServerId.value, 2);
      expect(svc.themeType.value, 'oled');
      expect(svc.servers.length, 2);
      expect(svc.servers[0]['name'], 'Server A');
    });

    test('parses aboutInfo context', () async {
      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 10));

      ctxController.add({
        'type': 'aboutInfo',
        'appName': 'Doudou',
        'version': '12.0.1',
        'buildNumber': '42',
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(svc.appName.value, 'Doudou');
      expect(svc.appVersion.value, '12.0.1');
      expect(svc.appBuildNumber.value, '42');
    });
  });

  group('message stream', () {
    test('sets isReachable on any message from phone', () async {
      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 10));

      expect(svc.isReachable.value, isFalse);

      msgController.add({'some': 'message'});

      await Future.delayed(const Duration(milliseconds: 10));

      expect(svc.isReachable.value, isTrue);
    });
  });

  group('checkReachability', () {
    test('updates isReachable and requests state when reachable', () async {
      when(() => mockWatch.isReachable).thenAnswer((_) async => true);

      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 10));
      await svc.checkReachability();

      expect(svc.isReachable.value, isTrue);
      verify(() => mockWatch.sendMessage({'command': 'getState'})).called(greaterThan(0));
    });

    test('updates isReachable to false when not reachable', () async {
      when(() => mockWatch.isReachable).thenAnswer((_) async => false);

      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await svc.checkReachability();

      expect(svc.isReachable.value, isFalse);
    });

    test('handles errors gracefully', () async {
      when(() => mockWatch.isReachable)
          .thenThrow(Exception('platform error'));

      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await svc.checkReachability();

      expect(svc.isReachable.value, isFalse);
    });
  });

  group('retry', () {
    test('triggers a reachability check', () async {
      when(() => mockWatch.isReachable).thenAnswer((_) async => true);

      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 10));

      svc.retry();

      // Give the async check time to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReachable.value, isTrue);
    });
  });

  group('sendMessage', () {
    test('calls WatchConnectivity.sendMessage', () async {
      final svc = WearCommService(watch: mockWatch);
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 10));

      svc.sendMessage({'command': 'play'});

      verify(() => mockWatch.sendMessage({'command': 'play'})).called(1);
    });
  });
}
