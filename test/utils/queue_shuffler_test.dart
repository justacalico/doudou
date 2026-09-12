import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/utils/queue_shuffler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MediaItem song(int id, {String? artist, String? album}) => MediaItem(
        id: 'song$id',
        title: 'Song $id',
        artist: artist,
        album: album,
      );

  List<MediaItem> library({int artists = 20, int perArtist = 10}) {
    final songs = <MediaItem>[];
    var id = 0;
    for (var a = 0; a < artists; a++) {
      for (var t = 0; t < perArtist; t++) {
        songs.add(song(id++, artist: 'Artist$a', album: 'Album$a'));
      }
    }
    return songs;
  }

  int adjacentSameArtist(List<MediaItem> order) {
    var count = 0;
    for (var i = 1; i < order.length; i++) {
      if (order[i].artist == order[i - 1].artist) count++;
    }
    return count;
  }

  group('shuffledSongs', () {
    test('returns a permutation of the input', () {
      final songs = library();
      final result = shuffledSongs(songs, random: Random(1));

      expect(result.length, songs.length);
      expect(result.toSet(), songs.toSet());
    });

    test('does not mutate the input list', () {
      final songs = library();
      final originalOrder = songs.map((s) => s.id).toList();
      shuffledSongs(songs, random: Random(1));

      expect(songs.map((s) => s.id).toList(), originalOrder);
    });

    test('handles empty and tiny lists', () {
      expect(shuffledSongs([], random: Random(1)), isEmpty);
      expect(shuffledSongs([song(0)], random: Random(1)).length, 1);
      expect(
        shuffledSongs([song(0), song(1)], random: Random(1)).length,
        2,
      );
    });

    test('is deterministic for the same seed', () {
      final songs = library();
      final a = shuffledSongs(songs, random: Random(7));
      final b = shuffledSongs(songs, random: Random(7));

      expect(a.map((s) => s.id).toList(), b.map((s) => s.id).toList());
    });

    test('produces different orders for different seeds', () {
      final songs = library();
      final a = shuffledSongs(songs, random: Random(1));
      final b = shuffledSongs(songs, random: Random(2));

      expect(a.map((s) => s.id).toList(),
          isNot(b.map((s) => s.id).toList()));
    });

    test('never places same artist adjacent when spreadable', () {
      final songs = library(artists: 25, perArtist: 8);
      for (var seed = 0; seed < 50; seed++) {
        final result = shuffledSongs(songs, random: Random(seed));
        expect(adjacentSameArtist(result), 0,
            reason: 'seed $seed had adjacent same-artist tracks');
      }
    });

    test('spreads artists better than a plain shuffle', () {
      final songs = library(artists: 20, perArtist: 10);
      var spreadAdjacencies = 0;
      var naiveAdjacencies = 0;
      for (var seed = 0; seed < 50; seed++) {
        spreadAdjacencies +=
            adjacentSameArtist(shuffledSongs(songs, random: Random(seed)));
        naiveAdjacencies +=
            adjacentSameArtist(songs.toList()..shuffle(Random(seed)));
      }
      expect(spreadAdjacencies, lessThan(naiveAdjacencies ~/ 4));
    });

    test('does not front-load one artist', () {
      final songs = library(artists: 10, perArtist: 10);
      for (var seed = 0; seed < 50; seed++) {
        final result = shuffledSongs(songs, random: Random(seed));
        final counts = <String?, int>{};
        for (final s in result.take(10)) {
          counts[s.artist] = (counts[s.artist] ?? 0) + 1;
        }
        expect(counts.values.every((c) => c < 3), isTrue,
            reason: 'seed $seed front-loaded an artist');
      }
    });

    test('keeps every song reachable at any position over many runs', () {
      final songs = library(artists: 10, perArtist: 5);
      final n = songs.length;
      final positionTotals = <String, int>{};
      const runs = 200;
      for (var seed = 0; seed < runs; seed++) {
        final result = shuffledSongs(songs, random: Random(seed));
        for (var i = 0; i < n; i++) {
          positionTotals[result[i].id] =
              (positionTotals[result[i].id] ?? 0) + i;
        }
      }
      for (final entry in positionTotals.entries) {
        final mean = entry.value / runs;
        expect(mean, greaterThan(n * 0.25),
            reason: '${entry.key} biased toward front');
        expect(mean, lessThan(n * 0.75),
            reason: '${entry.key} biased toward back');
      }
    });

    test('handles a library dominated by one artist', () {
      final songs = <MediaItem>[
        for (var i = 0; i < 60; i++) song(i, artist: 'Big'),
        for (var i = 60; i < 100; i++) song(i, artist: 'Solo$i'),
      ];
      final result = shuffledSongs(songs, random: Random(3));
      expect(result.toSet(), songs.toSet());
      expect(result.length, songs.length);
    });

    test('falls back to album when artist is missing', () {
      final songs = <MediaItem>[
        for (var i = 0; i < 20; i++) song(i, album: 'AlbumA'),
        for (var i = 20; i < 40; i++) song(i, album: 'AlbumB'),
        for (var i = 40; i < 60; i++) song(i, album: 'AlbumC'),
      ];
      final result = shuffledSongs(songs, random: Random(4));
      expect(result.toSet(), songs.toSet());
      var adjacencies = 0;
      for (var i = 1; i < result.length; i++) {
        if (result[i].album == result[i - 1].album) adjacencies++;
      }
      expect(adjacencies, 0);
    });

    test('treats songs with no artist or album as unique', () {
      final songs = [for (var i = 0; i < 30; i++) song(i)];
      final result = shuffledSongs(songs, random: Random(5));
      expect(result.toSet(), songs.toSet());
    });

    test('handles duplicate songs without dropping them', () {
      final s = song(0, artist: 'A');
      final songs = [
        s,
        s,
        for (var i = 1; i < 20; i++) song(i, artist: 'B$i'),
      ];
      final result = shuffledSongs(songs, random: Random(6));
      expect(result.length, songs.length);
      expect(result.where((e) => identical(e, s)).length, 2);
    });
  });

  group('spreadShuffle', () {
    test('works with arbitrary types and keys', () {
      final items = List.generate(100, (i) => 'item$i');
      final result = spreadShuffle(
        items,
        (s) => 'g${int.parse(s.substring(4)) % 10}',
        random: Random(1),
      );
      expect(result.toSet(), items.toSet());
      // items are numbered so groups share the same last digit
      var sameGroup = 0;
      for (var i = 1; i < result.length; i++) {
        if (int.parse(result[i].substring(4)) % 10 ==
            int.parse(result[i - 1].substring(4)) % 10) {
          sameGroup++;
        }
      }
      expect(sameGroup, 0);
    });
  });
}
