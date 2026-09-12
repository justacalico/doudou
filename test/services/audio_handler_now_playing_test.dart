import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/hm_streaming_data.dart';
import 'package:doudou/services/audio_handler.dart';
import 'package:doudou/services/stream_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes.dart';

// Re-exported for type-only registrations in setUp.
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart'
    show SettingsScreenController;

class _NowPlayingTestHandler extends MyAudioHandler {
  _NowPlayingTestHandler({required AudioPlayer player})
      : super(
          player: player,
          diagnostics: FakePlaybackDiagnosticsService(),
        );

  // Stubs for checkNGetUrl so playByIndex/setSourceNPlay can run in tests
  // without touching the real backend or stream isolate.
  Object? streamFetchError;
  Completer<HMStreamingData>? streamFetchGate;
  final streamFetchGates = <String, Completer<HMStreamingData>>{};
  HMStreamingData? streamFetchResult;

  @override
  Future<HMStreamingData> checkNGetUrl(String songId,
      {bool generateNewUrl = false,
      bool offlineReplacementUrl = false,
      Map<String, dynamic>? extras}) async {
    if (streamFetchError != null) throw streamFetchError!;
    final gate = streamFetchGates[songId] ?? streamFetchGate;
    if (gate != null) return gate.future;
    return streamFetchResult ??
        HMStreamingData(playable: false, statusMSG: 'test stub');
  }
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
  late MockAudioPlayer player;
  late _NowPlayingTestHandler handler;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_now_playing_test_');
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
    player = MockAudioPlayer();
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.playing).thenReturn(false);
    when(() => player.processingState).thenReturn(ProcessingState.idle);
    when(() => player.play()).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.seek(any())).thenAnswer((_) async {});
    when(() => player.seek(any(), index: any(named: 'index')))
        .thenAnswer((_) async {});
    when(() => player.setSkipSilenceEnabled(any())).thenAnswer((_) async {});
    handler = _NowPlayingTestHandler(player: player);
    handler.isSongLoading = false;
  });

  group('instant now playing state', () {
    test(
        'playByIndex shows the new song with loading state before the stream url resolves',
        () async {
      await handler.updateQueue([_song('a'), _song('b')]);
      handler.currentIndex = 0;
      handler.mediaItem.add(_song('a'));
      final gate = Completer<HMStreamingData>();
      handler.streamFetchGate = gate;

      final pending = handler.customAction('playByIndex', {'index': 1});
      await Future<void>.delayed(Duration.zero);

      // The tapped song is already the now playing item and the player
      // reports loading while the url fetch is still in flight.
      expect(handler.mediaItem.value?.id, 'b');
      expect(handler.playbackState.value.queueIndex, 1);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.loading);
      expect(handler.isSongLoading, isTrue);

      gate.complete(_playableStream('https://example.com/b.mp3'));
      await pending;

      expect(handler.isSongLoading, isFalse);
      expect(handler.mediaItem.value?.id, 'b');
      verify(() => player.play()).called(1);
    });

    test(
        'setSourceNPlay shows the new song and queue before the stream url resolves',
        () async {
      handler.mediaItem.add(_song('old'));
      final gate = Completer<HMStreamingData>();
      handler.streamFetchGate = gate;

      final pending = handler
          .customAction('setSourceNPlay', {'mediaItem': _song('s')});
      await Future<void>.delayed(Duration.zero);

      expect(handler.queue.value.map((s) => s.id), ['s']);
      expect(handler.mediaItem.value?.id, 's');
      expect(handler.playbackState.value.queueIndex, 0);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.loading);
      expect(handler.isSongLoading, isTrue);

      gate.complete(_playableStream('https://example.com/s.mp3'));
      await pending;

      expect(handler.isSongLoading, isFalse);
      expect(handler.queue.value.map((s) => s.id), ['s']);
      verify(() => player.play()).called(1);
    });

    test(
        'playByIndex keeps the requested song shown when the fetch fails',
        () async {
      await handler.updateQueue([_song('a'), _song('b')]);
      handler.currentIndex = 0;
      handler.mediaItem.add(_song('a'));
      handler.streamFetchError =
          Exception('SocketException: no route to host');

      await handler.customAction('playByIndex', {'index': 1});

      expect(handler.mediaItem.value?.id, 'b');
      expect(handler.isSongLoading, isFalse);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.error);
    });

    test(
        'a superseded playByIndex does not overwrite the newer song once its fetch resolves',
        () async {
      await handler.updateQueue([_song('a'), _song('b')]);
      handler.streamFetchGates['a'] = Completer<HMStreamingData>();
      handler.streamFetchGates['b'] = Completer<HMStreamingData>();

      final pendingA = handler.customAction('playByIndex', {'index': 0});
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value?.id, 'a');

      final pendingB = handler.customAction('playByIndex', {'index': 1});
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value?.id, 'b');
      expect(handler.playbackState.value.queueIndex, 1);

      // The superseded request resolves late and must not clobber the
      // song the user actually picked last.
      handler.streamFetchGates['a']!
          .complete(_playableStream('https://example.com/a.mp3'));
      await pendingA;

      expect(handler.mediaItem.value?.id, 'b');
      expect(handler.playbackState.value.queueIndex, 1);

      handler.streamFetchGates['b']!
          .complete(_playableStream('https://example.com/b.mp3'));
      await pendingB;

      expect(handler.mediaItem.value?.id, 'b');
      expect(handler.isSongLoading, isFalse);
    });
  });
}
