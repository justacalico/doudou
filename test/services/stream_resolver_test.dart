import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/stream_resolver.dart';
import 'package:doudou/services/stream_service.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';

Audio _audio({required String id, required String url, int itag = 251}) => Audio(
      itag: itag,
      audioCodec: Codec.opus,
      bitrate: 128000,
      duration: 0,
      loudnessDb: 0.0,
      url: url,
      size: 0,
    );

StreamProvider _fakeProvider({required String id, String? url, bool fail = false}) {
  if (fail) {
    return StreamProvider(playable: false, statusMSG: 'boom');
  }
  final realUrl = url ?? 'https://example.com/$id.mp3?expire=9999999999&';
  return StreamProvider(
    playable: true,
    statusMSG: 'OK',
    audioFormats: [
      _audio(id: id, url: realUrl, itag: 249),
      _audio(id: id, url: realUrl, itag: 251),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeSettingsScreenController fakeSettings;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_stream_resolver_');
    Hive.init(tempDir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox('PlaybackDiagnostics');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    fakeSettings = FakeSettingsScreenController();
    fakeSettings.activeServerId.value = 0;
    Get.reset();
    Get.put<SettingsScreenController>(fakeSettings);
  });

  tearDown(() async {
    final box = await Hive.openBox('SongsUrlCache');
    await box.clear();
  });

  group('resolve', () {
    test('fetches and caches a new URL', () async {
      var calls = 0;
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          calls++;
          return _fakeProvider(id: songId);
        },
      );

      final result = await resolver.resolve('song-1');

      expect(result.playable, isTrue);
      expect(result.audio?.url, contains('song-1'));
      expect(calls, 1);

      final second = await resolver.resolve('song-1');
      expect(second.audio?.url, result.audio?.url);
      expect(calls, 1);
    });

    test('strips the MPED prefix before fetching', () async {
      String? fetchedId;
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          fetchedId = songId;
          return _fakeProvider(id: songId);
        },
      );

      await resolver.resolve('MPEDsong-2');

      expect(fetchedId, 'song-2');
    });

    test('forceRefresh bypasses the cache', () async {
      var calls = 0;
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          calls++;
          return _fakeProvider(id: songId, url: 'https://example.com/$calls.mp3?expire=9999999999');
        },
      );

      final first = await resolver.resolve('song-3');
      expect(first.audio?.url, contains('1.mp3'));

      final forced = await resolver.resolve('song-3', forceRefresh: true);
      expect(forced.audio?.url, contains('2.mp3'));
      expect(calls, 2);
    });

    test('returns the Hive URL cache when it is still valid', () async {
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          return _fakeProvider(id: songId);
        },
      );

      final first = await resolver.resolve('song-4');
      resolver.dispose();

      final secondResolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          return _fakeProvider(id: songId, url: 'https://example.com/wrong.mp3?expire=9999999999');
        },
      );

      final second = await secondResolver.resolve('song-4');

      expect(second.audio?.url, first.audio?.url);
      secondResolver.dispose();
    });

    test('refetches when the cached URL has expired', () async {
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          return _fakeProvider(
              id: songId, url: 'https://example.com/old.mp3?expire=100');
        },
      );

      await resolver.resolve('song-5');
      resolver.dispose();

      var calls = 0;
      final secondResolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          calls++;
          return _fakeProvider(
              id: songId, url: 'https://example.com/new.mp3?expire=9999999999');
        },
      );

      final second = await secondResolver.resolve('song-5');

      expect(calls, 1);
      expect(second.audio?.url, contains('new.mp3'));
      secondResolver.dispose();
    });

    test('returns an unplayable result when the fetcher fails', () async {
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          return _fakeProvider(id: songId, fail: true);
        },
      );

      final result = await resolver.resolve('song-6');

      expect(result.playable, isFalse);
      expect(result.statusMSG, 'boom');
      resolver.dispose();
    });

    test('coalesces concurrent resolves for the same song', () async {
      var calls = 0;
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          calls++;
          await Future.delayed(const Duration(milliseconds: 50));
          return _fakeProvider(id: songId);
        },
      );

      final futures = [
        resolver.resolve('song-7'),
        resolver.resolve('song-7'),
        resolver.resolve('song-7'),
      ];
      final results = await Future.wait(futures);

      expect(calls, 1);
      expect(results.every((r) => r.audio?.url == results.first.audio?.url),
          isTrue);
      resolver.dispose();
    });
  });

  group('prefetch', () {
    test('resolves the song in the background', () async {
      var calls = 0;
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          calls++;
          return _fakeProvider(id: songId);
        },
      );

      resolver.prefetch('song-8');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(calls, 1);

      final result = await resolver.resolve('song-8');
      expect(result.playable, isTrue);
      expect(calls, 1);
      resolver.dispose();
    });

    test('prefetchQueue resolves the current and next item', () async {
      final fetched = <String>[];
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          fetched.add(songId);
          return _fakeProvider(id: songId);
        },
      );

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(id: 'b', title: 'B'),
        const MediaItem(id: 'c', title: 'C'),
      ];
      resolver.prefetchQueue(queue, 0);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(fetched, contains('a'));
      expect(fetched, contains('b'));
      expect(fetched, isNot(contains('c')));
      resolver.dispose();
    });

    test('prefetchQueue skips non-YouTube items', () async {
      final fetched = <String>[];
      final resolver = StreamResolver(
        fetcher: (songId, {requireWatchPage = true}) async {
          fetched.add(songId);
          return _fakeProvider(id: songId);
        },
      );

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(
            id: 'b',
            title: 'B',
            extras: {'backendType': 'subsonic'}),
      ];
      resolver.prefetchQueue(queue, 0);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(fetched, contains('a'));
      expect(fetched, isNot(contains('b')));
      resolver.dispose();
    });
  });
}
