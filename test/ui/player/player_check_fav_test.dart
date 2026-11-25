import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/media_item_builder.dart';
import 'package:doudou/models/server.dart';
import 'package:doudou/services/backend/noop_backend.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

class _TestPlayerController extends PlayerController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onReady() {}
}

class _ControlledFavoriteBackend extends NoOpBackend {
  final calls = <Completer<List<Map<String, dynamic>>>>[];

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSongs() {
    final completer = Completer<List<Map<String, dynamic>>>();
    calls.add(completer);
    return completer.future;
  }
}

MediaItem _song(String id) => MediaItem(
      id: id,
      title: 'song-$id',
      extras: {'url': 'https://example.com/$id.mp3'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box favBox;
  late FakeAudioHandler fakeAudio;
  late FakeSettingsScreenController fakeSettings;
  late PlayerController player;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_checkfav_');
    Hive.init(tempDir.path);
    await Hive.openBox('AppPrefs');
    favBox = await Hive.openBox('LIBFAV');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('AppPrefs').clear();
    await favBox.clear();
    fakeAudio = FakeAudioHandler();
    fakeSettings = FakeSettingsScreenController();

    Get.put<AudioHandler>(fakeAudio);
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(fakeSettings);

    player = Get.put<PlayerController>(_TestPlayerController());
    player.initFlagForPlayer = false;
  });

  tearDown(() {
    Get.reset();
  });

  group('checkFav', () {
    test('marks a song that is in the favorites box', () async {
      final song = _song('frost');
      await favBox.put(song.id, MediaItemBuilder.toJson(song));
      player.currentSong.value = song;

      await player.checkFav();

      expect(player.isCurrentSongFav.value, isTrue);
    });

    test('clears the flag for a song that is not favorited', () async {
      await favBox.put('other', MediaItemBuilder.toJson(_song('other')));
      player.isCurrentSongFav.value = true;
      player.currentSong.value = _song('plain');

      await player.checkFav();

      expect(player.isCurrentSongFav.value, isFalse);
    });

    test('clears the flag when nothing is playing', () async {
      player.isCurrentSongFav.value = true;
      player.currentSong.value = null;

      await player.checkFav();

      expect(player.isCurrentSongFav.value, isFalse);
    });

    test('drops a stale backend result that lands after the song changed',
        () async {
      fakeSettings.serverType = ServerType.jellyfin;
      final backend = _ControlledFavoriteBackend();
      fakeSettings.backend = backend;

      player.currentSong.value = _song('old');
      final oldCheck = player.checkFav();
      expect(backend.calls, hasLength(1));

      player.currentSong.value = _song('next');
      final nextCheck = player.checkFav();
      expect(backend.calls, hasLength(2));

      backend.calls[1].complete([
        {'videoId': 'next'}
      ]);
      await nextCheck;
      expect(player.isCurrentSongFav.value, isTrue);

      backend.calls[0].complete(const []);
      await oldCheck;
      expect(player.isCurrentSongFav.value, isTrue);
    });
  });
}
