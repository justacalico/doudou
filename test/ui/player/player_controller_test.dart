import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/server.dart';
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

MediaItem _song(String id, String title) => MediaItem(
      id: id,
      title: title,
      extras: {'url': 'https://example.com/$id.mp3'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late FakeAudioHandler fakeAudio;
  late FakePlaybackDiagnosticsService fakeDiag;
  late FakeMusicServices fakeMusic;
  late PlayerController player;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_player_');
    Hive.init(tempDir.path);
    appPrefs = await Hive.openBox('AppPrefs');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
    fakeAudio = FakeAudioHandler();
    fakeDiag = FakePlaybackDiagnosticsService();

    Get.put<AudioHandler>(fakeAudio);
    fakeMusic = FakeMusicServices();
    Get.put<MusicServices>(fakeMusic);
    Get.put<PlaybackDiagnosticsService>(fakeDiag);
    Get.put<SettingsScreenController>(FakeSettingsScreenController());

    player = Get.put<PlayerController>(_TestPlayerController());
    player.initFlagForPlayer = false;
    player.currentQueue.assignAll([_song('a', 'A'), _song('b', 'B')]);
    player.currentSongIndex.value = 0;
  });

  tearDown(() {
    Get.reset();
  });

  group('queue operations', () {
    test('enqueueSong adds a new song when queue is not empty', () async {
      final extra = _song('c', 'C');

      await player.enqueueSong(extra);

      expect(fakeAudio.calls, hasLength(1));
      expect(fakeAudio.calls.first.name, 'addQueueItem');
      expect(fakeAudio.calls.first.extra<MediaItem>('mediaItem')?.id, 'c');
    });

    test('enqueueSong does not add a duplicate song', () async {
      final existing = _song('a', 'A');

      await player.enqueueSong(existing);

      expect(fakeAudio.calls, isEmpty);
    });

    test('enqueueSongList appends unique items', () async {
      final incoming = [_song('c', 'C'), _song('a', 'A'), _song('d', 'D')];

      await player.enqueueSongList(incoming);

      final call = fakeAudio.calls.single;
      expect(call.name, 'addQueueItems');
      expect(
        call.extra<List<MediaItem>>('mediaItems')?.map((s) => s.id),
        ['c', 'd'],
      );
    });

    test('playNext adds an unknown song right after the current one', () async {
      final extra = _song('c', 'C');

      player.playNext(extra);

      final call = fakeAudio.calls.single;
      expect(call.name, 'addPlayNextItem');
      expect(call.extra<MediaItem>('mediaItem')?.id, 'c');
    });

    test('playNext moves an existing later song after the current one',
        () async {
      player.currentQueue.assignAll([
        _song('a', 'A'),
        _song('b', 'B'),
        _song('c', 'C'),
      ]);
      player.currentSongIndex.value = 0;

      final moving = _song('c', 'C');
      player.playNext(moving);

      final call = fakeAudio.calls.single;
      expect(call.name, 'reorderQueue');
      expect(call.extras?['oldIndex'], 2);
      expect(call.extras?['newIndex'], 1);
    });

    test('playNext appends the last song when it is already at the end',
        () async {
      player.currentQueue.assignAll([_song('a', 'A')]);
      player.currentSongIndex.value = 0;

      final extra = _song('b', 'B');
      player.playNext(extra);

      final call = fakeAudio.calls.single;
      expect(call.name, 'addQueueItem');
      expect(call.extra<MediaItem>('mediaItem')?.id, 'b');
    });

    test('removeFromQueue delegates to the audio handler', () {
      final song = _song('a', 'A');

      player.removeFromQueue(song);

      expect(fakeAudio.calls.single.name, 'removeQueueItem');
      expect(
        fakeAudio.calls.single.extra<MediaItem>('mediaItem')?.id,
        'a',
      );
    });

    test('clearQueue sends the clearQueue custom action', () {
      player.clearQueue();

      expect(fakeAudio.calls.single.name, 'clearQueue');
    });

    test('shuffleQueue sends the shuffleQueue custom action', () {
      player.shuffleQueue();

      expect(fakeAudio.calls.single.name, 'shuffleQueue');
    });

    test('onReorder sends the reorderQueue custom action', () {
      player.onReorder(2, 1);

      expect(fakeAudio.calls.single.name, 'reorderQueue');
      expect(fakeAudio.calls.single.extras?['oldIndex'], 2);
      expect(fakeAudio.calls.single.extras?['newIndex'], 1);
    });
  });

  group('playback controls', () {
    test('play sends a play event to the audio handler and logs', () {
      player.play();

      expect(fakeAudio.calls.single.name, 'play');
      expect(fakeDiag.calls.single.message, 'ui_play_pressed');
    });

    test('pause sends a pause event to the audio handler and logs', () {
      player.pause();

      expect(fakeAudio.calls.single.name, 'pause');
      expect(fakeDiag.calls.single.message, 'ui_pause_pressed');
    });

    test('next sends skipToNext and logs', () {
      player.next();

      expect(fakeAudio.calls.single.name, 'skipToNext');
      expect(fakeDiag.calls.single.message, 'ui_next_pressed');
    });

    test('prev sends skipToPrevious', () {
      player.prev();

      expect(fakeAudio.calls.single.name, 'skipToPrevious');
    });

    test('seek sends the position to the audio handler', () {
      const position = Duration(seconds: 30);
      player.seek(position);

      expect(fakeAudio.calls.single.name, 'seek');
      expect(
        fakeAudio.calls.single.extra<Duration>('position'),
        position,
      );
    });

    test('seekByIndex sends a playByIndex custom action and logs', () {
      player.seekByIndex(2);

      expect(fakeAudio.calls.single.name, 'playByIndex');
      expect(fakeAudio.calls.single.extras?['index'], 2);
      expect(fakeDiag.calls.single.message, 'ui_seek_by_index');
    });

    test('playPause toggles between play and pause', () {
      fakeAudio.playbackState.add(PlaybackState(playing: true));

      player.playPause();

      expect(fakeAudio.calls.single.name, 'pause');
    });

    test('playPause plays when currently paused', () {
      fakeAudio.playbackState.add(PlaybackState(playing: false));

      player.playPause();

      expect(fakeAudio.calls.single.name, 'play');
    });
  });

  group('shuffle and loop toggles', () {
    test('toggleShuffleMode enables shuffle and updates preferences', () async {
      expect(player.isShuffleModeEnabled.value, isFalse);

      await player.toggleShuffleMode();

      expect(player.isShuffleModeEnabled.value, isTrue);
      expect(appPrefs.get('isShuffleModeEnabled'), isTrue);
      expect(fakeAudio.calls.single.name, 'setShuffleMode');
      expect(
        fakeAudio.calls.single.extra<AudioServiceShuffleMode>('shuffleMode'),
        AudioServiceShuffleMode.all,
      );
    });

    test('toggleShuffleMode disables shuffle when already on', () async {
      player.isShuffleModeEnabled.value = true;

      await player.toggleShuffleMode();

      expect(player.isShuffleModeEnabled.value, isFalse);
      expect(appPrefs.get('isShuffleModeEnabled'), isFalse);
      expect(fakeAudio.calls.single.name, 'setShuffleMode');
      expect(
        fakeAudio.calls.single.extra<AudioServiceShuffleMode>('shuffleMode'),
        AudioServiceShuffleMode.none,
      );
    });

    test('toggleLoopMode enables loop and updates preferences', () async {
      expect(player.isLoopModeEnabled.value, isFalse);

      await player.toggleLoopMode();

      expect(player.isLoopModeEnabled.value, isTrue);
      expect(appPrefs.get('isLoopModeEnabled'), isTrue);
      expect(fakeAudio.calls.single.name, 'setRepeatMode');
      expect(
        fakeAudio.calls.single.extra<AudioServiceRepeatMode>('repeatMode'),
        AudioServiceRepeatMode.one,
      );
    });

    test('toggleLoopMode disables loop when already on', () async {
      player.isLoopModeEnabled.value = true;

      await player.toggleLoopMode();

      expect(player.isLoopModeEnabled.value, isFalse);
      expect(appPrefs.get('isLoopModeEnabled'), isFalse);
      expect(fakeAudio.calls.single.name, 'setRepeatMode');
      expect(
        fakeAudio.calls.single.extra<AudioServiceRepeatMode>('repeatMode'),
        AudioServiceRepeatMode.none,
      );
    });

    test('toggleQueueLoopMode enables queue loop', () async {
      await player.toggleQueueLoopMode(showMessage: false);

      expect(player.isQueueLoopModeEnabled.value, isTrue);
      expect(appPrefs.get('queueLoopModeEnabled'), isTrue);
      expect(fakeAudio.calls.single.name, 'toggleQueueLoopMode');
      expect(fakeAudio.calls.single.extras?['enable'], isTrue);
    });

    test('toggleQueueLoopMode disables queue loop', () async {
      player.isQueueLoopModeEnabled.value = true;

      await player.toggleQueueLoopMode(showMessage: false);

      expect(player.isQueueLoopModeEnabled.value, isFalse);
      expect(appPrefs.get('queueLoopModeEnabled'), isFalse);
      expect(fakeAudio.calls.single.name, 'toggleQueueLoopMode');
      expect(fakeAudio.calls.single.extras?['enable'], isFalse);
    });
  });

  group('radio', () {
    test('startRadio replaces the queue and starts the seed song', () async {
      final seed = _song('seed', 'Seed');
      fakeMusic.watchPlaylistResult = {
        'tracks': [seed, _song('r1', 'R1'), _song('r2', 'R2')],
        'additionalParamsForNext': 'nextParam',
      };

      await player.startRadio(seed);
      await pumpEventQueue();

      expect(player.isRadioModeOn, isTrue);
      expect(player.radioContinuationParam, 'nextParam');
      expect(
        fakeMusic.lastWatchPlaylistCall?['videoId'],
        'seed',
      );
      expect(fakeMusic.lastWatchPlaylistCall?['radio'], isTrue);

      final setSource =
          fakeAudio.calls.firstWhere((c) => c.name == 'setSourceNPlay');
      expect(setSource.extra<MediaItem>('mediaItem')?.id, 'seed');

      final update =
          fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      expect(
        update.extra<List<MediaItem>>('queue')?.map((s) => s.id),
        ['seed', 'r1', 'r2'],
      );
      // Seed playback comes from setSourceNPlay, no extra playByIndex.
      expect(
        fakeAudio.calls.any((c) => c.name == 'playByIndex'),
        isFalse,
      );
      expect(
        fakeDiag.calls.any((c) => c.message == 'radio_start_requested'),
        isTrue,
      );
      expect(
        fakeDiag.calls.any((c) => c.message == 'radio_seed_tracks_fetched'),
        isTrue,
      );
    });

    test(
        'startRadio on the playing song swaps the queue without restarting it',
        () async {
      final seed = _song('a', 'A');
      player.currentSong.value = seed;
      fakeMusic.watchPlaylistResult = {
        'tracks': [seed, _song('r1', 'R1'), _song('r2', 'R2')],
        'additionalParamsForNext': null,
      };

      await player.startRadio(seed);
      await pumpEventQueue();

      expect(
        fakeAudio.calls.any((c) => c.name == 'setSourceNPlay'),
        isFalse,
      );
      final update =
          fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      expect(
        update.extra<List<MediaItem>>('queue')?.map((s) => s.id),
        ['a', 'r1', 'r2'],
      );
      final repoint = fakeAudio.calls
          .firstWhere((c) => c.name == 'upadateMediaItemInAudioService');
      expect(repoint.extras?['index'], 0);
    });

    test(
        'startRadio with a playlist id replaces the queue and plays the first track',
        () async {
      fakeMusic.watchPlaylistResult = {
        'tracks': [_song('r1', 'R1'), _song('r2', 'R2')],
        'additionalParamsForNext': 'cont',
      };

      await player.startRadio(null, playlistid: 'RDAMVMx');
      await pumpEventQueue();

      expect(fakeMusic.lastWatchPlaylistCall?['playlistId'], 'RDAMVMx');
      expect(fakeMusic.lastWatchPlaylistCall?['radio'], isTrue);
      expect(
        fakeAudio.calls.any((c) => c.name == 'setSourceNPlay'),
        isFalse,
      );
      final update =
          fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      expect(
        update.extra<List<MediaItem>>('queue')?.map((s) => s.id),
        ['r1', 'r2'],
      );
      final play =
          fakeAudio.calls.firstWhere((c) => c.name == 'playByIndex');
      expect(play.extras?['index'], 0);
      expect(player.isRadioModeOn, isTrue);
    });

    test('radio seed fetch failure resets radio state', () async {
      fakeMusic.watchPlaylistError = Exception('no network');
      final seed = _song('seed', 'Seed');

      await player.startRadio(seed);
      await pumpEventQueue();

      expect(player.isRadioModeOn, isFalse);
      expect(player.radioInitiatorItem, isNull);
      expect(player.radioContinuationParam, isNull);
      expect(
        fakeAudio.calls.any((c) => c.name == 'updateQueue'),
        isFalse,
      );
      expect(
        fakeDiag.calls.any((c) => c.message == 'radio_seed_fetch_failed'),
        isTrue,
      );
    });

    test(
        'pushSongToQueue auto-promotes a single song play to radio on YouTube Music',
        () async {
      final seed = _song('seed', 'Seed');
      fakeMusic.watchPlaylistResult = {
        'tracks': [seed, _song('r1', 'R1')],
        'additionalParamsForNext': null,
      };

      await player.pushSongToQueue(seed);
      await pumpEventQueue();

      expect(player.isRadioModeOn, isTrue);
      expect(
        fakeDiag.calls.any((c) => c.message == 'radio_auto_enabled'),
        isTrue,
      );
      final update =
          fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      expect(
        update.extra<List<MediaItem>>('queue')?.map((s) => s.id),
        ['seed', 'r1'],
      );
    });

    test(
        'playHomeSectionSong starts radio for the tapped song on YouTube Music',
        () async {
      final seed = _song('b', 'B');
      fakeMusic.watchPlaylistResult = {
        'tracks': [seed, _song('r1', 'R1')],
        'additionalParamsForNext': 'nextParam',
      };

      await player.playHomeSectionSong(
        [_song('a', 'A'), seed, _song('c', 'C')],
        1,
      );
      await pumpEventQueue();

      expect(player.isRadioModeOn, isTrue);
      expect(fakeMusic.lastWatchPlaylistCall?['videoId'], 'b');
      expect(fakeMusic.lastWatchPlaylistCall?['radio'], isTrue);

      final setSource =
          fakeAudio.calls.firstWhere((c) => c.name == 'setSourceNPlay');
      expect(setSource.extra<MediaItem>('mediaItem')?.id, 'b');

      final update =
          fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      expect(
        update.extra<List<MediaItem>>('queue')?.map((s) => s.id),
        ['b', 'r1'],
      );
      expect(
        fakeAudio.calls.any((c) => c.name == 'playByIndex'),
        isFalse,
      );
    });

    test(
        'playHomeSectionSong plays the section as a queue when auto-radio is off',
        () async {
      await appPrefs.put('autoRadioEnabled', false);
      final items = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];

      await player.playHomeSectionSong(items, 1);
      await pumpEventQueue();

      expect(player.isRadioModeOn, isFalse);
      expect(fakeMusic.lastWatchPlaylistCall, isNull);

      final update =
          fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      expect(
        update.extra<List<MediaItem>>('queue')?.map((s) => s.id),
        ['a', 'b', 'c'],
      );
      final play =
          fakeAudio.calls.firstWhere((c) => c.name == 'playByIndex');
      expect(play.extras?['index'], 1);
    });

    test(
        'playHomeSectionSong plays the section as a queue on non-YouTube servers',
        () async {
      final settings =
          Get.find<SettingsScreenController>() as FakeSettingsScreenController;
      settings.serverType = ServerType.jellyfin;
      final items = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];

      await player.playHomeSectionSong(items, 2);
      await pumpEventQueue();

      expect(player.isRadioModeOn, isFalse);
      expect(fakeMusic.lastWatchPlaylistCall, isNull);

      final update =
          fakeAudio.calls.firstWhere((c) => c.name == 'updateQueue');
      expect(
        update.extra<List<MediaItem>>('queue')?.map((s) => s.id),
        ['a', 'b', 'c'],
      );
      final play =
          fakeAudio.calls.firstWhere((c) => c.name == 'playByIndex');
      expect(play.extras?['index'], 2);
    });

    test('radio does not start when the watch playlist returns no tracks',
        () async {
      fakeMusic.watchPlaylistResult = {
        'tracks': <MediaItem>[],
        'additionalParamsForNext': null,
      };

      await player.startRadio(null, playlistid: 'RDempty');
      await pumpEventQueue();

      expect(player.isRadioModeOn, isFalse);
      expect(player.radioInitiatorItem, isNull);
      expect(
        fakeAudio.calls.any((c) => c.name == 'updateQueue'),
        isFalse,
      );
      expect(
        fakeAudio.calls.any((c) => c.name == 'playByIndex'),
        isFalse,
      );
    });
  });

  group('volume', () {
    test('setVolume sends the scaled value to the audio handler', () async {
      await player.setVolume(50);

      expect(player.volume.value, 50);
      expect(appPrefs.get('volume'), 50);
      expect(fakeAudio.calls.single.name, 'setVolume');
      expect(fakeAudio.calls.single.extras?['value'], closeTo(0.25, 0.001));
    });

    test('setVolume clamps values to 0-100', () async {
      await player.setVolume(150);
      expect(player.volume.value, 100);

      await player.setVolume(-10);
      expect(player.volume.value, 0);
    });

    test('mute toggles between zero and the previous volume', () async {
      await player.setVolume(40);
      fakeAudio.calls.clear();

      await player.mute();
      expect(player.volume.value, 0);
      expect(fakeAudio.calls.last.name, 'setVolume');
      expect(fakeAudio.calls.last.extras?['value'], 0.0);

      await player.mute();
      expect(player.volume.value, 40);
      expect(fakeAudio.calls.last.name, 'setVolume');
      expect(fakeAudio.calls.last.extras?['value'], closeTo(0.16, 0.001));
    });
  });
}
