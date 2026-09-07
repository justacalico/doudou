import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/audio_handler.dart';
import 'package:doudou/services/playback_recovery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes.dart';

// Re-exported for type-only registrations in setUp.
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart'
    show SettingsScreenController;

MockAudioPlayer _stubbedPlayer() {
  final player = MockAudioPlayer();
  when(() => player.position).thenReturn(Duration.zero);
  when(() => player.playing).thenReturn(false);
  when(() => player.processingState).thenReturn(ProcessingState.idle);
  when(() => player.play()).thenAnswer((_) async {});
  when(() => player.pause()).thenAnswer((_) async {});
  when(() => player.stop()).thenAnswer((_) async {});
  when(() => player.dispose()).thenAnswer((_) async {});
  when(() => player.seek(any(), index: any(named: 'index')))
      .thenAnswer((_) async {});
  when(() => player.setVolume(any())).thenAnswer((_) async {});
  when(() => player.setSkipSilenceEnabled(any())).thenAnswer((_) async {});
  return player;
}

class _RecoveryTestHandler extends MyAudioHandler {
  _RecoveryTestHandler({
    required AudioPlayer player,
    required AudioPlayer Function() playerFactory,
    required Future<bool> Function(String?) reachability,
    required List<Duration> delays,
    required FakePlaybackDiagnosticsService diagnostics,
  }) : super(
          player: player,
          playerFactory: playerFactory,
          diagnostics: diagnostics,
          reachabilityCheck: reachability,
          recoveryDelay: (d) async => delays.add(d),
        );

  final playByIndexCalls = <Map<String, dynamic>>[];
  bool simulatePlayerError = false;
  Object nextError = PlatformException(
      code: '-1004', message: 'Could not connect to the server.');

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == 'playByIndex') {
      playByIndexCalls.add(Map.of(extras ?? {}));
      if (simulatePlayerError) {
        // Mimics the native player rejecting the freshly loaded source: the
        // error lands on playbackEventStream while the play request unwinds.
        await debugHandlePlaybackStreamError(nextError);
      }
      return;
    }
    return super.customAction(name, extras);
  }

  Future<dynamic> runRealPlayByIndex(Map<String, dynamic> extras) =>
      super.customAction('playByIndex', extras);
}

MediaItem _song(String id) => MediaItem(
      id: id,
      title: id,
      extras: {'url': 'https://example.com/$id.mp3'},
    );

PlatformException _ios1004() => PlatformException(
    code: '-1004', message: 'Could not connect to the server.');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late FakePlaybackDiagnosticsService diag;
  late List<Duration> delays;
  late List<MockAudioPlayer> createdPlayers;
  late int reachabilityCalls;
  late bool reachable;
  late _RecoveryTestHandler handler;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_recovery_test_');
    Hive.init(tempDir.path);
    appPrefs = await Hive.openBox('AppPrefs');
    await Hive.openBox('PlaybackDiagnostics');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
    Get.reset();
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    diag = FakePlaybackDiagnosticsService();
    delays = [];
    createdPlayers = [];
    reachabilityCalls = 0;
    reachable = true;
    final first = _stubbedPlayer();
    createdPlayers.add(first);
    handler = _RecoveryTestHandler(
      player: first,
      playerFactory: () {
        final player = _stubbedPlayer();
        createdPlayers.add(player);
        return player;
      },
      reachability: (url) async {
        reachabilityCalls++;
        return reachable;
      },
      delays: delays,
      diagnostics: diag,
    );
    await handler.updateQueue([_song('a'), _song('b')]);
    handler.currentIndex = 0;
    handler.isSongLoading = false;
    handler.currentSongUrl = 'https://example.com/a.mp3';
  });

  test(
      'repeated -1004 errors back off exponentially, rebuild the player and stop at the retry cap',
      () async {
    handler.simulatePlayerError = true;

    await handler.debugHandlePlaybackStreamError(_ios1004());

    // attempts 1/2/3 retry with 1s/2s/4s backoff, the 4th failure exhausts
    // the budget instead of looping forever like the reported bug did.
    expect(delays.map((d) => d.inMilliseconds), [1000, 2000, 4000]);
    expect(handler.playByIndexCalls, hasLength(maxPlayerRecoveryAttempts));
    for (final call in handler.playByIndexCalls) {
      expect(call['index'], 0);
      expect(call['newUrl'], isTrue);
      expect(call['recoveryRetry'], isTrue);
    }

    // attempts 2 and 3 each rebuilt the player instance
    expect(createdPlayers, hasLength(3));
    expect(identical(handler.debugPlayer, createdPlayers.first), isFalse);
    expect(identical(handler.debugPlayer, createdPlayers.last), isTrue);
    verify(() => createdPlayers[0].dispose()).called(1);
    verify(() => createdPlayers[1].dispose()).called(1);
    verifyNever(() => createdPlayers[2].dispose());
    // settings are re-applied to every recreated player
    verify(() => createdPlayers[1].setSkipSilenceEnabled(any())).called(1);
    verify(() => createdPlayers[1].setVolume(any())).called(1);
    verify(() => createdPlayers[2].setSkipSilenceEnabled(any())).called(1);

    expect(reachabilityCalls, 3);
    expect(handler.playbackState.value.processingState,
        AudioProcessingState.error);
    expect(handler.isSongLoading, isFalse);
    expect(handler.currentSongUrl, isNull);

    expect(
        diag.calls.where((c) => c.message == 'player_recovery_exhausted'),
        hasLength(1));
    expect(
        diag.calls.where((c) => c.message == 'player_instance_recreated'),
        hasLength(2));
    expect(
        diag.calls
            .where((c) => c.message == 'player_failed_with_valid_url')
            .length,
        4);
    expect(
        diag.calls.where((c) => c.message == 'player_recovery_queued'),
        isNotEmpty);
    final backoffCalls = diag.calls
        .where((c) => c.message == 'player_recovery_backoff')
        .toList();
    expect(backoffCalls.map((c) => c.data?['delayMs']), [1000, 2000, 4000]);
  });

  test(
      'surfaces a no connection error without retrying when the stream host is unreachable',
      () async {
    reachable = false;
    handler.simulatePlayerError = true;

    await handler.debugHandlePlaybackStreamError(_ios1004());

    expect(handler.playByIndexCalls, isEmpty);
    expect(delays, isEmpty);
    expect(reachabilityCalls, 1);
    expect(createdPlayers, hasLength(1));
    verifyNever(() => createdPlayers[0].dispose());
    expect(handler.playbackState.value.processingState,
        AudioProcessingState.error);
    expect(handler.playbackState.value.errorMessage, contains('networkError'));
    expect(
        diag.calls
            .where((c) => c.message == 'player_recovery_aborted_offline'),
        hasLength(1));
  });

  test(
      'non connection errors get capped backoff retries without reachability checks or rebuilds',
      () async {
    handler.simulatePlayerError = true;
    handler.nextError = Exception('FormatException: unexpected byte');

    await handler
        .debugHandlePlaybackStreamError(Exception('FormatException: unexpected byte'));

    expect(delays.map((d) => d.inMilliseconds), [1000, 2000, 4000]);
    expect(handler.playByIndexCalls, hasLength(maxPlayerRecoveryAttempts));
    expect(reachabilityCalls, 0);
    expect(createdPlayers, hasLength(1));
    verifyNever(() => createdPlayers[0].dispose());
    expect(handler.playbackState.value.errorMessage,
        contains('unexpected byte'));
    expect(
        diag.calls.where((c) => c.message == 'player_recovery_exhausted'),
        hasLength(1));
  });

  test('a failure on a different song starts a fresh retry budget', () async {
    await handler.debugHandlePlaybackStreamError(_ios1004());
    expect(handler.playByIndexCalls, hasLength(1));
    expect(handler.debugConsecutivePlayerFailures, 1);

    // move to another song: the failure streak must not carry over
    await handler.updateQueue([_song('b'), _song('a')]);
    handler.currentIndex = 0;
    handler.currentSongUrl = 'https://example.com/b.mp3';
    await handler.debugHandlePlaybackStreamError(_ios1004());

    expect(handler.debugConsecutivePlayerFailures, 1);
    expect(delays.map((d) => d.inMilliseconds), [1000, 1000]);
    expect(handler.playByIndexCalls.last['index'], 0);
  });

  test('a user initiated playByIndex resets the retry budget', () async {
    await handler.debugHandlePlaybackStreamError(_ios1004());
    await handler.debugHandlePlaybackStreamError(_ios1004());
    expect(handler.debugConsecutivePlayerFailures, 2);

    try {
      await handler.runRealPlayByIndex({'index': 0});
    } catch (_) {
      // the real playByIndex keeps running into the backend layer which is
      // unavailable in tests; the budget reset happens before that work
    }

    expect(handler.debugConsecutivePlayerFailures, 0);
  });

  test(
      'cache source failures resume the same source first and escalate to a rebuild on repeat',
      () async {
    handler.isPlayingUsingLockCachingSource = true;
    const cacheError = 'Connection closed while receiving data';

    // attempt 1: same-source resume, no url refetch, no rebuild
    await handler.debugHandlePlaybackStreamError(Exception(cacheError));
    verify(() => createdPlayers[0].seek(Duration.zero, index: 0)).called(1);
    verify(() => createdPlayers[0].play()).called(1);
    expect(handler.playByIndexCalls, isEmpty);
    expect(createdPlayers, hasLength(1));

    // attempts 2+ escalate: rebuild the player and refetch the url
    handler.simulatePlayerError = true;
    handler.nextError = Exception(cacheError);
    await handler.debugHandlePlaybackStreamError(Exception(cacheError));

    expect(createdPlayers, hasLength(3));
    expect(handler.playByIndexCalls, hasLength(2));
    for (final call in handler.playByIndexCalls) {
      expect(call['newUrl'], isTrue);
    }
    expect(delays.map((d) => d.inMilliseconds), [1000, 2000, 4000]);
    expect(handler.playbackState.value.processingState,
        AudioProcessingState.error);
  });
}
