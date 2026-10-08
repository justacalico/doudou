import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:doudou/models/media_item_builder.dart';
import 'package:doudou/models/playlist.dart';
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

class _FakeMusicServices extends FakeMusicServices {
  List<dynamic> homeSections = [];
  Map<String, List<MediaItem>> playlistTracks = {};
  Map<String, List<MediaItem>> radioTracks = {};

  @override
  Future<dynamic> getHome({int limit = 4}) async => homeSections;

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0}) async {
    return {'tracks': playlistTracks[playlistId] ?? <MediaItem>[]};
  }

  @override
  Future<Map<String, dynamic>> getWatchPlaylist(
      {String videoId = "",
      String? playlistId,
      int limit = 25,
      bool radio = false,
      bool shuffle = false,
      String? additionalParamsNext,
      bool onlyRelated = false}) async {
    return {'tracks': radioTracks[videoId] ?? <MediaItem>[]};
  }
}

MediaItem _song(String id) =>
    MediaItem(id: id, title: 'Song $id', extras: {'url': 'https://x/$id'});

Playlist _playlist(String id, String title) =>
    Playlist(title: title, playlistId: id, thumbnailUrl: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late FakeAudioHandler fakeAudio;
  late _FakeMusicServices fakeMusic;
  late PlayerController player;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_supermix_');
    Hive.init(tempDir.path);
    appPrefs = await Hive.openBox('AppPrefs');
    await Hive.openBox('LIBFAV');
    await Hive.openBox('LIBRP');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
    await Hive.box('LIBFAV').clear();
    await Hive.box('LIBRP').clear();
    fakeAudio = FakeAudioHandler();
    fakeMusic = _FakeMusicServices();

    Get.put<AudioHandler>(fakeAudio);
    Get.put<MusicServices>(fakeMusic);
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());

    player = Get.put<PlayerController>(_TestPlayerController());
    player.initFlagForPlayer = false;
  });

  tearDown(() {
    Get.reset();
  });

  group('startSupermix', () {
    test('plays the native Supermix playlist and enables supermix mode',
        () async {
      final mixTracks = List.generate(4, (i) => _song('m$i'));
      fakeMusic.homeSections = [
        {
          'contents': [_playlist('VLRDTMAK5uy_abc', 'My Supermix')]
        }
      ];
      fakeMusic.playlistTracks['VLRDTMAK5uy_abc'] = mixTracks;
      player.isRadioModeOn = true;
      player.radioInitiatorItem = _song('old');

      await player.startSupermix();

      expect(player.isSupermixModeOn, isTrue);
      expect(player.isRadioModeOn, isFalse);
      expect(player.radioInitiatorItem, isNull);
      expect(player.playinfrom.value.name, 'Supermix');

      final update = fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      final queue = update.extra<List<MediaItem>>('queue')!;
      expect(queue.map((t) => t.id), containsAll(mixTracks.map((t) => t.id)));
      expect(
          fakeAudio.calls.any(
              (c) => c.name == 'playByIndex' && c.extra<int>('index') == 0),
          isTrue);
    });

    test('builds a mix from favourites when there is no native playlist',
        () async {
      final favBox = Hive.box('LIBFAV');
      for (final id in ['fav0', 'fav1']) {
        await favBox.put(id, MediaItemBuilder.toJson(_song(id)));
      }
      fakeMusic.radioTracks['fav0'] = [_song('d1')];
      fakeMusic.radioTracks['fav1'] = [_song('d2')];

      await player.startSupermix();

      expect(player.isSupermixModeOn, isTrue);
      final update = fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      final ids =
          update.extra<List<MediaItem>>('queue')!.map((t) => t.id).toSet();
      expect(ids, containsAll({'fav0', 'fav1'}));
      expect(ids.any((id) => id.startsWith('d')), isTrue);
    });

    testWidgets('stays off when nothing can be mixed', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));

      await player.startSupermix();

      expect(player.isSupermixModeOn, isFalse);
      expect(fakeAudio.calls.where((c) => c.name == 'updateQueue'), isEmpty);
      // let the snackbar animation and timer run out
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    test('supermix mode turns off when normal playback starts', () async {
      fakeMusic.radioTracks['fav0'] = [_song('d1')];
      final favBox = Hive.box('LIBFAV');
      await favBox.put('fav0', MediaItemBuilder.toJson(_song('fav0')));

      await player.startSupermix();
      expect(player.isSupermixModeOn, isTrue);

      await player.playPlayListSong([_song('x'), _song('y')], 0);
      expect(player.isSupermixModeOn, isFalse);
    });
  });
}
