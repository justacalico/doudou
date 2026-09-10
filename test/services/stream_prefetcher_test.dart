import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/hm_streaming_data.dart';
import 'package:doudou/services/stream_prefetcher.dart';
import 'package:flutter_test/flutter_test.dart';

HMStreamingData _fakeData(String songId) => HMStreamingData(
      playable: true,
      statusMSG: 'OK',
      highQualityAudio: null,
      lowQualityAudio: null,
    );

void main() {
  group('StreamPrefetcher.resolve', () {
    test('coalesces concurrent calls for the same song', () async {
      var calls = 0;
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        calls++;
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeData(songId);
      });

      final results = await Future.wait([
        prefetcher.resolve('s1'),
        prefetcher.resolve('s1'),
        prefetcher.resolve('s1'),
      ]);

      expect(calls, 1);
      expect(results.every((r) => r.playable), isTrue);
    });

    test('does not coalesce different songs', () async {
      var calls = 0;
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        calls++;
        return _fakeData(songId);
      });

      await Future.wait([
        prefetcher.resolve('s1'),
        prefetcher.resolve('s2'),
      ]);

      expect(calls, 2);
    });

    test('does not coalesce generateNewUrl with normal resolve', () async {
      var calls = 0;
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        calls++;
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeData(songId);
      });

      await Future.wait([
        prefetcher.resolve('s1'),
        prefetcher.resolve('s1', generateNewUrl: true),
      ]);

      expect(calls, 2);
    });

    test('allows re-resolve after the in-flight request completes', () async {
      var calls = 0;
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        calls++;
        return _fakeData(songId);
      });

      await prefetcher.resolve('s1');
      await prefetcher.resolve('s1');

      expect(calls, 2);
    });

    test('passes extras through to the fetch function', () async {
      Map<String, dynamic>? captured;
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        captured = extras;
        return _fakeData(songId);
      });

      await prefetcher.resolve('s1', extras: {'backendType': 'subsonic'});

      expect(captured, {'backendType': 'subsonic'});
    });
  });

  group('StreamPrefetcher.prefetch', () {
    test('resolves in the background without awaiting', () async {
      var calls = 0;
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        calls++;
        return _fakeData(songId);
      });

      prefetcher.prefetch('s1');
      expect(calls, 1);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(calls, 1);
    });

    test('coalesces with a subsequent resolve for the same song', () async {
      var calls = 0;
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        calls++;
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeData(songId);
      });

      prefetcher.prefetch('s1');
      final result = await prefetcher.resolve('s1');

      expect(calls, 1);
      expect(result.playable, isTrue);
    });
  });

  group('StreamPrefetcher.prefetchNext', () {
    test('prefetches the next song after the current index', () async {
      final fetched = <String>[];
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        fetched.add(songId);
        return _fakeData(songId);
      });

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(id: 'b', title: 'B'),
        const MediaItem(id: 'c', title: 'C'),
      ];
      prefetcher.prefetchNext(queue, 0);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetched, contains('b'));
      expect(fetched, isNot(contains('a')));
      expect(fetched, isNot(contains('c')));
    });

    test('does nothing when at the end of the queue', () async {
      final fetched = <String>[];
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        fetched.add(songId);
        return _fakeData(songId);
      });

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(id: 'b', title: 'B'),
      ];
      prefetcher.prefetchNext(queue, 1);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetched, isEmpty);
    });

    test('skips non-YouTube items', () async {
      final fetched = <String>[];
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        fetched.add(songId);
        return _fakeData(songId);
      });

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(
            id: 'b', title: 'B', extras: {'backendType': 'subsonic'}),
      ];
      prefetcher.prefetchNext(queue, 0);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetched, isEmpty);
    });

    test('handles null currentIndex as 0', () async {
      final fetched = <String>[];
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        fetched.add(songId);
        return _fakeData(songId);
      });

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(id: 'b', title: 'B'),
      ];
      prefetcher.prefetchNext(queue, null);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetched, contains('b'));
    });
  });

  group('StreamPrefetcher.prefetchCurrentAndNext', () {
    test('prefetches both the current and next song', () async {
      final fetched = <String>[];
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        fetched.add(songId);
        return _fakeData(songId);
      });

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(id: 'b', title: 'B'),
        const MediaItem(id: 'c', title: 'C'),
      ];
      prefetcher.prefetchCurrentAndNext(queue, 0);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetched, containsAll(['a', 'b']));
      expect(fetched, isNot(contains('c')));
    });

    test('prefetches only the current song when at the end', () async {
      final fetched = <String>[];
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        fetched.add(songId);
        return _fakeData(songId);
      });

      final queue = [
        const MediaItem(id: 'a', title: 'A'),
        const MediaItem(id: 'b', title: 'B'),
      ];
      prefetcher.prefetchCurrentAndNext(queue, 1);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetched, contains('b'));
    });

    test('skips non-YouTube current item but still prefetches next YouTube item',
        () async {
      final fetched = <String>[];
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        fetched.add(songId);
        return _fakeData(songId);
      });

      final queue = [
        const MediaItem(
            id: 'a', title: 'A', extras: {'backendType': 'subsonic'}),
        const MediaItem(id: 'b', title: 'B'),
      ];
      prefetcher.prefetchCurrentAndNext(queue, 0);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetched, isNot(contains('a')));
      expect(fetched, contains('b'));
    });
  });

  group('StreamPrefetcher.clear', () {
    test('removes in-flight requests', () {
      final prefetcher = StreamPrefetcher((songId,
          {bool generateNewUrl = false, Map<String, dynamic>? extras}) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return _fakeData(songId);
      });

      prefetcher.prefetch('s1');
      expect(prefetcher.hasInFlightRequests, isTrue);

      prefetcher.clear();
      expect(prefetcher.hasInFlightRequests, isFalse);
    });
  });
}
