import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/audio_handler.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/song_preloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes.dart';

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
  when(() => player.seek(any())).thenAnswer((_) async {});
  when(() => player.setVolume(any())).thenAnswer((_) async {});
  when(() => player.setSkipSilenceEnabled(any())).thenAnswer((_) async {});
  return player;
}

MediaItem _song(String id) => MediaItem(
      id: id,
      title: id,
      extras: {'url': 'https://example.com/$id.mp3'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory preloadDir;
  late Box appPrefs;
  late MockAudioPlayer player;
  late SongPreloader preloader;
  late FakePlaybackDiagnosticsService diag;
  late MyAudioHandler handler;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_preload_test_');
    Hive.init(tempDir.path);
    appPrefs = await Hive.openBox('AppPrefs');
    await Hive.openBox('PlaybackDiagnostics');
    await Hive.openBox('SongDownloads');
    await Hive.openBox('SongsUrlCache');
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
    Get.put<MusicServices>(FakeMusicServices());
    preloadDir =
        await Directory('${tempDir.path}/preloadedSongs').create(recursive: true);
    preloader = SongPreloader(
      directory: preloadDir,
      downloader: (uri, target, headers) => target.writeAsBytes(const [1, 2, 3]),
    );
    diag = FakePlaybackDiagnosticsService();
    player = _stubbedPlayer();
    handler = MyAudioHandler(
      player: player,
      diagnostics: diag,
      preloader: preloader,
      isApplePlatform: false,
    );
  });

  test('checkNGetUrl serves the preloaded file before any url resolution',
      () async {
    await preloader.preload('b', 'https://example.com/b.mp3');

    final data = await handler.checkNGetUrl('b', extras: const {});

    expect(data.playable, isTrue);
    expect(data.audio!.url, 'file://${preloadDir.path}/b.mp3');
    expect(
        diag.calls.where((c) => c.message == 'hit_preloaded_file'),
        hasLength(1));
  });

  test('checkNGetUrl falls back to the url cache without a preloaded file',
      () async {
    // Seed the stream url cache: with no preloaded file the normal cache
    // resolution must still apply.
    final expire = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 7200;
    final audioJson = {
      'itag': 140,
      'audioCodec': 'Codec.mp4a',
      'bitrate': 128000,
      'loudnessDb': 0.0,
      'url': 'https://example.com/stream?expire=$expire&x=1',
      'approxDurationMs': 0,
      'size': 0,
    };
    await Hive.box('SongsUrlCache').put('cached', {
      'playable': true,
      'statusMSG': 'OK',
      'lowQualityAudio': audioJson,
      'highQualityAudio': audioJson,
    });

    final data = await handler.checkNGetUrl('cached', extras: const {});

    expect(data.playable, isTrue);
    expect(data.audio!.url, audioJson['url']);
    expect(
        diag.calls.where((c) => c.message == 'hit_preloaded_file'), isEmpty);
  });

  test('playByIndex plays a preloaded song from the local file source',
      () async {
    await preloader.preload('b', 'https://example.com/b.mp3');
    await handler.updateQueue([_song('a'), _song('b')]);

    await handler.customAction('playByIndex', {'index': 1});

    expect(handler.currentSongUrl, 'file://${preloadDir.path}/b.mp3');
    expect(handler.isPlayingUsingLockCachingSource, isFalse);
    expect(handler.isSongLoading, isFalse);
    verify(() => player.seek(Duration.zero)).called(1);
    verify(() => player.play()).called(1);
    expect(
        diag.calls.where((c) => c.message == 'using_file_audio_source'),
        hasLength(1));
  });
}
