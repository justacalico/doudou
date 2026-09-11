import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/hm_streaming_data.dart';
import 'package:doudou/services/audio_handler.dart';
import 'package:doudou/services/background_task_guard.dart';
import 'package:doudou/services/stream_service.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes.dart';

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

class _TaskTestHandler extends MyAudioHandler {
  _TaskTestHandler({
    required AudioPlayer player,
    required FakePlaybackDiagnosticsService diagnostics,
    required BackgroundTaskGuard backgroundTaskGuard,
    required Future<bool> Function(String?) reachability,
    required List<Duration> delays,
  }) : super(
          player: player,
          playerFactory: _stubbedPlayer,
          diagnostics: diagnostics,
          backgroundTaskGuard: backgroundTaskGuard,
          reachabilityCheck: reachability,
          recoveryDelay: (d) async => delays.add(d),
        );

  final playByIndexCalls = <Map<String, dynamic>>[];
  bool simulatePlayerError = false;
  Object nextError = PlatformException(
      code: '-1004', message: 'Could not connect to the server.');

  Object? streamFetchError;
  Completer<HMStreamingData>? streamFetchGate;
  HMStreamingData? streamFetchResult;

  @override
  Future<HMStreamingData> checkNGetUrl(String songId,
      {bool generateNewUrl = false,
      bool offlineReplacementUrl = false,
      Map<String, dynamic>? extras}) async {
    if (streamFetchError != null) throw streamFetchError!;
    final gate = streamFetchGate;
    if (gate != null) return gate.future;
    return streamFetchResult ??
        HMStreamingData(playable: false, statusMSG: 'test stub');
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == 'playByIndex') {
      playByIndexCalls.add(Map.of(extras ?? {}));
      if (simulatePlayerError) {
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

HMStreamingData _playableStream(String url) {
  final audio = Audio(
      itag: 140,
      audioCodec: Codec.mp4a,
      bitrate: 128000,
      duration: 0,
      loudnessDb: 0,
      url: url,
      size: 0);
  return HMStreamingData(
      playable: true,
      statusMSG: 'OK',
      highQualityAudio: audio,
      lowQualityAudio: audio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late FakePlaybackDiagnosticsService diag;
  late List<String> begins;
  late List<int> ends;
  late int nextTaskId;
  late BackgroundTaskGuard guard;
  late MockAudioPlayer player;
  late _TaskTestHandler handler;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_bgtask_test_');
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
    begins = [];
    ends = [];
    nextTaskId = 0;
    guard = BackgroundTaskGuard(
      begin: (name) async {
        begins.add(name);
        return ++nextTaskId;
      },
      end: (id) async => ends.add(id),
      enabled: () => true,
      holdLimit: const Duration(seconds: 30),
    );
    player = _stubbedPlayer();
    handler = _TaskTestHandler(
      player: player,
      diagnostics: diag,
      backgroundTaskGuard: guard,
      reachability: (url) async => true,
      delays: [],
    );
    await handler.updateQueue([_song('a'), _song('b')]);
    handler.currentIndex = 0;
    handler.isSongLoading = false;
    handler.currentSongUrl = 'https://example.com/a.mp3';
  });

  test('playByIndex holds a background task before the stream fetch resolves',
      () async {
    final gate = Completer<HMStreamingData>();
    handler.streamFetchGate = gate;

    final pending = handler.runRealPlayByIndex({'index': 0});
    await Future<void>.delayed(Duration.zero);

    // The task must be held before the fetch completes: after the playlist
    // swap starts the app has no playing audio to keep it alive.
    expect(begins, ['playback-transition']);
    expect(guard.isHeld, isTrue);

    gate.complete(_playableStream('https://example.com/b.mp3'));
    await pending;

    // Still held: nothing is playing yet, the hold covers the buffering gap.
    expect(ends, isEmpty);
    expect(handler.isSongLoading, isFalse);
  });

  test('a ready and playing state releases the transition hold', () async {
    handler.streamFetchResult = _playableStream('https://example.com/b.mp3');

    await handler.runRealPlayByIndex({'index': 0});
    expect(guard.isHeld, isTrue);

    when(() => player.playing).thenReturn(true);
    when(() => player.processingState).thenReturn(ProcessingState.ready);
    handler.debugReleaseBackgroundTasksIfPlaying();

    expect(ends, [1]);
    expect(guard.isHeld, isFalse);
  });

  test('a stale loading event does not release the hold mid-transition',
      () async {
    final gate = Completer<HMStreamingData>();
    handler.streamFetchGate = gate;

    final pending = handler.runRealPlayByIndex({'index': 0});
    await Future<void>.delayed(Duration.zero);
    expect(guard.isHeld, isTrue);

    // A queued event from the old source can still report ready+playing while
    // the swap is in flight; it must not drop the hold.
    when(() => player.playing).thenReturn(true);
    when(() => player.processingState).thenReturn(ProcessingState.ready);
    handler.debugReleaseBackgroundTasksIfPlaying();
    expect(ends, isEmpty);

    gate.complete(_playableStream('https://example.com/b.mp3'));
    await pending;

    handler.debugReleaseBackgroundTasksIfPlaying();
    expect(ends, [1]);
  });

  test('a failed fetch drops the hold through the terminal error path',
      () async {
    handler.streamFetchError = Exception('SocketException: no route to host');

    await handler.runRealPlayByIndex({'index': 0});

    expect(begins, hasLength(1));
    expect(ends, [1]);
    expect(guard.isHeld, isFalse);
    expect(handler.playbackState.value.processingState,
        AudioProcessingState.error);
  });

  test('player recovery holds a task across the backoff delays', () async {
    handler.simulatePlayerError = true;

    await handler.debugHandlePlaybackStreamError(PlatformException(
        code: '-1004', message: 'Could not connect to the server.'));

    expect(begins, contains('playback-recovery'));
    // The exhausted recovery surfaced a terminal error which released the
    // hold instead of leaking it.
    expect(ends, isNotEmpty);
    expect(guard.isHeld, isFalse);
    expect(diag.calls.where((c) => c.message == 'player_recovery_exhausted'),
        hasLength(1));
  });

  test('stop releases any outstanding hold', () async {
    final gate = Completer<HMStreamingData>();
    handler.streamFetchGate = gate;

    final pending = handler.runRealPlayByIndex({'index': 0});
    await Future<void>.delayed(Duration.zero);
    expect(guard.isHeld, isTrue);

    gate.complete(_playableStream('https://example.com/b.mp3'));
    await pending;

    await handler.stop();
    expect(ends, [1]);
    expect(guard.isHeld, isFalse);
  });
}
