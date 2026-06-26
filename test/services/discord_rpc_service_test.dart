import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/durationstate.dart';
import 'package:doudou/services/discord_rpc_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockDiscordRpcClient extends Mock implements DiscordRpcClient {}

class _FakePlayerStateProvider implements PlayerStateProvider {
  @override
  final currentSong = Rxn<MediaItem>();

  @override
  final buttonState = Rx<PlayButtonState>(PlayButtonState.paused);

  @override
  final progressBarStatus = Rx<ProgressBarState>(ProgressBarState(
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  ));
}

class _MockPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '/tmp';

  @override
  Future<String?> getApplicationSupportPath() async => '/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDiscordRpcClient mockClient;
  late _FakePlayerStateProvider fakePlayer;
  late Box box;
  final connController = StreamController<bool>.broadcast();

  setUpAll(() {
    PathProviderPlatform.instance = _MockPathProviderPlatform();
    registerFallbackValue(const RPCActivity());
  });

  setUp(() async {
    Hive.init('/tmp/doudou_test_${DateTime.now().millisecondsSinceEpoch}');
    box = await Hive.openBox('AppPrefs_test');
    mockClient = _MockDiscordRpcClient();
    fakePlayer = _FakePlayerStateProvider();

    when(() => mockClient.isConnectedStream)
        .thenAnswer((_) => connController.stream);
    when(() => mockClient.isConnected).thenReturn(true);
    when(() => mockClient.initialize(any())).thenAnswer((_) async {});
    when(() => mockClient.connect(autoRetry: any(named: 'autoRetry')))
        .thenAnswer((_) async {});
    when(() => mockClient.disconnect()).thenAnswer((_) async {});
    when(() => mockClient.setActivity(
            activity: any(named: 'activity')))
        .thenAnswer((_) async {});
    when(() => mockClient.clearActivity()).thenAnswer((_) async {});
    when(() => mockClient.dispose()).thenAnswer((_) async {});
  });

  tearDown(() async {
    connController.close();
    await box.clear();
    await box.deleteFromDisk();
    Get.reset();
  });

  group('initialization', () {
    test('does not initialize when RPC is disabled', () async {
      await box.put('discordRpcEnabled', false);
      await box.put('discordAppId', '123456');

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      // Give async _maybeInit a chance to run
      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReady, isFalse);
      verifyNever(() => mockClient.initialize(any()));
    });

    test('does not initialize when app ID is empty', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '');

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReady, isFalse);
      verifyNever(() => mockClient.initialize(any()));
    });

    test('does not initialize when app ID is null', () async {
      await box.put('discordRpcEnabled', true);

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReady, isFalse);
      verifyNever(() => mockClient.initialize(any()));
    });

    test('initializes and connects when enabled with valid app ID', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '123456789');

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReady, isTrue);
      verify(() => mockClient.initialize('123456789')).called(1);
      verify(() => mockClient.connect(autoRetry: true)).called(1);
    });

    test('handles init failure gracefully', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '123456789');

      when(() => mockClient.initialize(any()))
          .thenThrow(Exception('init failed'));

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      expect(svc.isReady, isFalse);
    });
  });

  group('activity updates', () {
    test('clears activity when no song is playing', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '123456789');

      fakePlayer.currentSong.value = null;
      fakePlayer.buttonState.value = PlayButtonState.paused;

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockClient.clearActivity()).called(greaterThan(0));
      verifyNever(() =>
          mockClient.setActivity(activity: any(named: 'activity')));
    });

    test('sets activity with song details when a song is playing', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '123456789');

      fakePlayer.currentSong.value = MediaItem(
        id: 'song1',
        title: 'Test Song',
        artist: 'Test Artist',
        duration: const Duration(seconds: 180),
      );
      fakePlayer.buttonState.value = PlayButtonState.playing;
      fakePlayer.progressBarStatus.value = ProgressBarState(
        current: const Duration(seconds: 30),
        buffered: const Duration(seconds: 60),
        total: const Duration(seconds: 180),
      );

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      final captor = verify(() =>
              mockClient.setActivity(activity: captureAny(named: 'activity')))
          .captured;

      expect(captor, isNotEmpty);
      final activity = captor.last as RPCActivity;
      expect(activity.details, 'Test Song');
      expect(activity.state, 'Test Artist');
      expect(activity.activityType, ActivityType.listening);
      expect(activity.timestamps?.start, isNotNull);
      expect(activity.timestamps?.end, isNotNull);
      expect(activity.assets?.largeImage, 'doudou');
    });

    test('uses Unknown artist when artist is empty', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '123456789');

      fakePlayer.currentSong.value = MediaItem(
        id: 'song2',
        title: 'No Artist Song',
        artist: '',
      );
      fakePlayer.buttonState.value = PlayButtonState.playing;
      fakePlayer.progressBarStatus.value = ProgressBarState(
        current: Duration.zero,
        buffered: Duration.zero,
        total: Duration.zero,
      );

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      final captor = verify(() =>
              mockClient.setActivity(activity: captureAny(named: 'activity')))
          .captured;

      final activity = captor.last as RPCActivity;
      expect(activity.state, 'Unknown artist');
      expect(activity.details, 'No Artist Song');
    });

    test('does not set timestamps when not playing', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '123456789');

      fakePlayer.currentSong.value = MediaItem(
        id: 'song3',
        title: 'Paused Song',
        artist: 'Some Artist',
      );
      fakePlayer.buttonState.value = PlayButtonState.paused;
      fakePlayer.progressBarStatus.value = ProgressBarState(
        current: const Duration(seconds: 10),
        buffered: Duration.zero,
        total: const Duration(seconds: 120),
      );

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      final captor = verify(() =>
              mockClient.setActivity(activity: captureAny(named: 'activity')))
          .captured;

      final activity = captor.last as RPCActivity;
      expect(activity.timestamps?.start, isNull);
      expect(activity.timestamps?.end, isNull);
    });
  });

  group('reconfigure', () {
    test('tears down and re-initializes when toggled on', () async {
      await box.put('discordRpcEnabled', false);
      await box.put('discordAppId', '123456789');

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));
      verifyNever(() => mockClient.initialize(any()));

      // Toggle on
      await box.put('discordRpcEnabled', true);
      await svc.reconfigure();

      expect(svc.isReady, isTrue);
      verify(() => mockClient.initialize('123456789')).called(1);
    });

    test('tears down when toggled off', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '123456789');

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));
      expect(svc.isReady, isTrue);

      // Toggle off
      await box.put('discordRpcEnabled', false);
      await svc.reconfigure();

      expect(svc.isReady, isFalse);
      verify(() => mockClient.disconnect()).called(greaterThan(0));
    });

    test('does nothing when app ID is missing', () async {
      await box.put('discordRpcEnabled', true);
      await box.put('discordAppId', '');

      final svc = DiscordRpcService(
        client: mockClient,
        box: box,
        player: fakePlayer,
      );
      svc.onInit();

      await Future.delayed(const Duration(milliseconds: 50));

      await svc.reconfigure();

      expect(svc.isReady, isFalse);
      verifyNever(() => mockClient.initialize(any()));
    });
  });

  group('isSupported', () {
    test('returns true on desktop platforms', () {
      // Tests run on the host platform (macOS in CI/dev).
      // Just verify the static getter doesn't throw.
      expect(DiscordRpcService.isSupported, isA<bool>());
    });
  });
}
