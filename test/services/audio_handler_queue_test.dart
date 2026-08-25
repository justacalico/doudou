import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes.dart';

// Re-exported for type-only registrations in setUp.
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart'
    show SettingsScreenController;

class _TestMyAudioHandler extends MyAudioHandler {
  _TestMyAudioHandler({required AudioPlayer player})
      : super(
          player: player,
          diagnostics: FakePlaybackDiagnosticsService(),
        );

  final playByIndexCalls = <int>[];

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == 'playByIndex') {
      final index = extras?['index'] as int;
      currentIndex = index;
      playByIndexCalls.add(index);
      return;
    }
    return super.customAction(name, extras);
  }
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
  late MockAudioPlayer player;
  late _TestMyAudioHandler handler;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_audio_handler_');
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
    when(() => player.seek(Duration.zero)).thenAnswer((_) => Future.value());
    when(() => player.pause()).thenAnswer((_) => Future.value());
    when(() => player.play()).thenAnswer((_) => Future.value());
    when(() => player.setSkipSilenceEnabled(false))
        .thenAnswer((_) => Future.value());
    handler = _TestMyAudioHandler(player: player);
  });

  group('queue operations', () {
    test('updateQueue replaces the queue and originalQueue', () async {
      final songs = [_song('a', 'A'), _song('b', 'B')];

      await handler.updateQueue(songs);

      expect(handler.queue.value, songs);
      expect(handler.originalQueue, songs);
    });

    test('addQueueItems appends to the queue when shuffle is off', () async {
      final songs = [_song('a', 'A'), _song('b', 'B')];
      await handler.updateQueue(songs);
      handler.currentIndex = 0;

      final more = [_song('c', 'C'), _song('d', 'D')];
      await handler.addQueueItems(more);

      expect(handler.queue.value.length, 4);
      expect(handler.queue.value, [...songs, ...more]);
      expect(handler.originalQueue, [...songs, ...more]);
    });

    test('addQueueItems shuffles new items after the current song', () async {
      final songs = [_song('a', 'A'), _song('b', 'B')];
      await handler.updateQueue(songs);
      handler.currentIndex = 0;
      handler.shuffleModeEnabled = true;

      final more = [_song('c', 'C'), _song('d', 'D')];
      await handler.addQueueItems(more);

      expect(handler.queue.value.length, 4);
      expect(handler.queue.value.first.id, 'a');
      expect(handler.queue.value.map((s) => s.id).toSet(),
          {'a', 'b', 'c', 'd'});
      expect(handler.originalQueue, [...songs, ...more]);
    });

    test('addQueueItem appends when shuffle is off', () async {
      final songs = [_song('a', 'A')];
      await handler.updateQueue(songs);
      handler.currentIndex = 0;

      final extra = _song('b', 'B');
      await handler.addQueueItem(extra);

      expect(handler.queue.value, [songs.first, extra]);
      expect(handler.originalQueue, [songs.first, extra]);
    });

    test('addQueueItem inserts after the current song when shuffle is on',
        () async {
      final songs = [_song('a', 'A'), _song('b', 'B')];
      await handler.updateQueue(songs);
      handler.currentIndex = 0;
      handler.shuffleModeEnabled = true;

      final extra = _song('c', 'C');
      await handler.addQueueItem(extra);

      expect(handler.queue.value.length, 3);
      expect(handler.queue.value.first.id, 'a');
      expect(handler.queue.value.contains(extra), isTrue);
      expect(handler.originalQueue, [...songs, extra]);
    });

    test('removeQueueItem removes from both queues and adjusts currentIndex',
        () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 1;

      await handler.removeQueueItem(songs.first);

      expect(handler.queue.value.map((s) => s.id), ['b', 'c']);
      expect(handler.currentIndex, 0);
    });

    test('removeQueueItem before current song decrements currentIndex',
        () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 2;

      await handler.removeQueueItem(songs.first);

      expect(handler.queue.value.map((s) => s.id), ['b', 'c']);
      expect(handler.currentIndex, 1);
    });
  });

  group('shuffle and loop modes', () {
    test('setShuffleMode shuffles with current song first', () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 1;

      await handler.setShuffleMode(AudioServiceShuffleMode.all);

      expect(handler.shuffleModeEnabled, isTrue);
      expect(handler.currentIndex, 0);
      expect(handler.queue.value.first.id, 'b');
      expect(handler.queue.value.map((s) => s.id).toSet(), {'a', 'b', 'c'});
      expect(handler.shuffledQueue, handler.queue.value.map((s) => s.id));
    });

    test('setShuffleMode none restores the original queue order', () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 1;

      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      await handler.setShuffleMode(AudioServiceShuffleMode.none);

      expect(handler.shuffleModeEnabled, isFalse);
      expect(handler.queue.value.map((s) => s.id), ['a', 'b', 'c']);
      expect(handler.currentIndex, 1);
    });

    test('customAction shuffleQueue keeps the current song first', () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 2;

      await handler.customAction('shuffleQueue');

      expect(handler.currentIndex, 0);
      expect(handler.queue.value.first.id, 'c');
      expect(handler.queue.value.map((s) => s.id).toSet(), {'a', 'b', 'c'});
    });

    test('customAction reorderQueue reorders and updates currentIndex',
        () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 1;

      await handler.customAction('reorderQueue', {
        'oldIndex': 2,
        'newIndex': 0,
      });

      expect(handler.queue.value.map((s) => s.id), ['c', 'a', 'b']);
      expect(handler.currentIndex, 2);
    });

    test('customAction addPlayNextItem inserts after current song', () async {
      final songs = [_song('a', 'A'), _song('b', 'B')];
      await handler.updateQueue(songs);
      handler.currentIndex = 0;

      final extra = _song('c', 'C');
      await handler.customAction('addPlayNextItem', {'mediaItem': extra});

      expect(handler.queue.value.map((s) => s.id), ['a', 'c', 'b']);
      expect(handler.originalQueue.map((s) => s.id), ['a', 'c', 'b']);
    });

    test('customAction clearQueue keeps only the current song', () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 2;

      await handler.customAction('clearQueue');

      expect(handler.queue.value, [songs[2]]);
      expect(handler.currentIndex, 0);
      expect(handler.originalQueue, [songs[2]]);
    });

    test('setRepeatMode toggles loopModeEnabled', () async {
      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      expect(handler.loopModeEnabled, isTrue);

      await handler.setRepeatMode(AudioServiceRepeatMode.none);
      expect(handler.loopModeEnabled, isFalse);
    });

    test('customAction toggleQueueLoopMode sets queueLoopModeEnabled', () async {
      await handler.customAction('toggleQueueLoopMode', {'enable': true});
      expect(handler.queueLoopModeEnabled, isTrue);

      await handler.customAction('toggleQueueLoopMode', {'enable': false});
      expect(handler.queueLoopModeEnabled, isFalse);
    });
  });

  group('skip navigation', () {
    test('skipToNext advances to the next song', () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 0;

      await handler.skipToNext();

      expect(handler.currentIndex, 1);
      expect(handler.playByIndexCalls, [1]);
    });

    test('skipToNext at end of queue pauses the player', () async {
      final songs = [_song('a', 'A'), _song('b', 'B')];
      await handler.updateQueue(songs);
      handler.currentIndex = 1;

      await handler.skipToNext();

      verify(() => player.pause()).called(1);
      expect(handler.currentIndex, 1);
      expect(handler.playByIndexCalls, isEmpty);
    });

    test('skipToNext with queue loop jumps to the start', () async {
      final songs = [_song('a', 'A'), _song('b', 'B')];
      await handler.updateQueue(songs);
      handler.currentIndex = 1;
      handler.queueLoopModeEnabled = true;

      await handler.skipToNext();

      expect(handler.currentIndex, 0);
      expect(handler.playByIndexCalls, [0]);
    });

    test('skipToPrevious with far progress seeks to the start', () async {
      when(() => player.position).thenReturn(const Duration(seconds: 6));
      final songs = [_song('a', 'A'), _song('b', 'B')];
      await handler.updateQueue(songs);
      handler.currentIndex = 0;

      await handler.skipToPrevious();

      verify(() => player.seek(Duration.zero)).called(1);
      expect(handler.currentIndex, 0);
      expect(handler.playByIndexCalls, isEmpty);
    });

    test('skipToPrevious goes to the previous song', () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 2;

      await handler.skipToPrevious();

      expect(handler.currentIndex, 1);
      expect(handler.playByIndexCalls, [1]);
    });

    test('skipToNext reshuffles the queue in shuffle+queue loop at end',
        () async {
      final songs = [_song('a', 'A'), _song('b', 'B'), _song('c', 'C')];
      await handler.updateQueue(songs);
      handler.currentIndex = 2;
      handler.shuffleModeEnabled = true;
      handler.queueLoopModeEnabled = true;

      await handler.skipToNext();

      expect(handler.currentIndex, 1);
      expect(handler.playByIndexCalls, [1]);
      expect(handler.queue.value.first.id, 'c');
      expect(handler.queue.value.map((s) => s.id).toSet(), {'a', 'b', 'c'});
    });
  });
}
