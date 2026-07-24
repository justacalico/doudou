import 'package:audio_service/audio_service.dart';
import 'package:doudou/utils/helper.dart';
import 'package:doudou/ui/widgets/sort_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getTimeString', () {
    test('formats seconds-only duration as M:SS', () {
      expect(getTimeString(const Duration(seconds: 45)), '0:45');
    });

    test('formats minutes and seconds', () {
      expect(getTimeString(const Duration(minutes: 3, seconds: 5)), '3:05');
    });

    test('formats hours, minutes, seconds', () {
      expect(
        getTimeString(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('zero duration formats as 0:00', () {
      expect(getTimeString(Duration.zero), '0:00');
    });

    test('pads seconds to two digits', () {
      expect(getTimeString(const Duration(seconds: 5)), '0:05');
    });

    test('pads minutes to two digits when hours present', () {
      expect(
        getTimeString(const Duration(hours: 1, minutes: 5, seconds: 9)),
        '1:05:09',
      );
    });
  });

  group('sortSongsNVideos', () {
    MediaItem song(String title, {Duration? duration, String? date}) {
      return MediaItem(
        id: title,
        title: title,
        duration: duration,
        extras: {
          if (date != null) 'date': date,
        },
      );
    }

    test('sorts by name ascending (case-insensitive)', () {
      final songs = [
        song('Zebra'),
        song('apple'),
        song('Mango'),
      ];

      sortSongsNVideos(songs, SortType.Name, true);

      expect(songs.map((s) => s.title).toList(), ['apple', 'Mango', 'Zebra']);
    });

    test('sorts by name descending', () {
      final songs = [
        song('apple'),
        song('Mango'),
        song('Zebra'),
      ];

      sortSongsNVideos(songs, SortType.Name, false);

      expect(songs.map((s) => s.title).toList(), ['Zebra', 'Mango', 'apple']);
    });

    test('sorts by duration ascending', () {
      final songs = [
        song('Long', duration: const Duration(seconds: 300)),
        song('Short', duration: const Duration(seconds: 30)),
        song('Mid', duration: const Duration(seconds: 120)),
      ];

      sortSongsNVideos(songs, SortType.Duration, true);

      expect(songs.map((s) => s.title).toList(), ['Short', 'Mid', 'Long']);
    });

    test('sorts by duration descending', () {
      final songs = [
        song('Short', duration: const Duration(seconds: 30)),
        song('Long', duration: const Duration(seconds: 300)),
      ];

      sortSongsNVideos(songs, SortType.Duration, false);

      expect(songs[0].title, 'Long');
      expect(songs[1].title, 'Short');
    });

    test('handles null durations as zero', () {
      final songs = [
        song('NoDur'),
        song('HasDur', duration: const Duration(seconds: 100)),
      ];

      sortSongsNVideos(songs, SortType.Duration, true);

      expect(songs[0].title, 'NoDur');
      expect(songs[1].title, 'HasDur');
    });

    test('sorts by date ascending (string comparison)', () {
      final songs = [
        song('New', date: '2024-01-01'),
        song('Old', date: '2020-01-01'),
        song('Mid', date: '2022-01-01'),
      ];

      sortSongsNVideos(songs, SortType.Date, true);

      expect(songs.map((s) => s.title).toList(), ['Old', 'Mid', 'New']);
    });

    test('handles null dates in date sort', () {
      final songs = [
        song('HasDate', date: '2024-01-01'),
        song('NoDate'),
      ];

      sortSongsNVideos(songs, SortType.Date, true);

      // Both should be present; order with nulls is stable (treated as equal).
      expect(songs.length, 2);
    });
  });

  group('sortAlbumNSingles', () {
    test('sorts by year ascending via Name sortType (quirk: Name maps to year)', () {
      // Note: sortAlbumNSingles has a swapped implementation where
      // SortType.Name actually sorts by year and SortType.Date sorts by title.
      final albums = [
        (title: 'A', year: '2020'),
        (title: 'B', year: '2010'),
        (title: 'C', year: '2024'),
      ].map((e) => _FakeAlbum(title: e.title, year: e.year)).toList();

      sortAlbumNSingles(albums, SortType.Name, true);

      expect(albums.map((a) => a.year).toList(), ['2010', '2020', '2024']);
    });

    test('sorts by title via Date sortType', () {
      final albums = [
        _FakeAlbum(title: 'Zebra', year: '2020'),
        _FakeAlbum(title: 'Apple', year: '2020'),
      ];

      sortAlbumNSingles(albums, SortType.Date, true);

      expect(albums.map((a) => a.title).toList(), ['Apple', 'Zebra']);
    });

    test('handles null years as equal', () {
      final albums = [
        _FakeAlbum(title: 'A', year: null),
        _FakeAlbum(title: 'B', year: null),
      ];

      sortAlbumNSingles(albums, SortType.Name, true);

      expect(albums.length, 2);
    });
  });

  group('sortPlayLists', () {
    test('sorts by name ascending (case-insensitive)', () {
      final playlists = [
        _FakePlaylist(title: 'Zebra'),
        _FakePlaylist(title: 'apple'),
        _FakePlaylist(title: 'Mango'),
      ];

      sortPlayLists(playlists, SortType.Name, true);

      expect(playlists.map((p) => p.title).toList(), ['apple', 'Mango', 'Zebra']);
    });

    test('sorts by RecentlyPlayed descending (most recent first)', () {
      final now = DateTime.now();
      final playlists = [
        _FakePlaylist(title: 'Old', lastPlayed: now.subtract(const Duration(days: 10))),
        _FakePlaylist(title: 'New', lastPlayed: now),
        _FakePlaylist(title: 'Mid', lastPlayed: now.subtract(const Duration(days: 5))),
      ];

      sortPlayLists(playlists, SortType.RecentlyPlayed, true);

      expect(playlists.map((p) => p.title).toList(), ['New', 'Mid', 'Old']);
    });

    test('falls back to title sort when both lastPlayed are null', () {
      final playlists = [
        _FakePlaylist(title: 'Z', lastPlayed: null),
        _FakePlaylist(title: 'A', lastPlayed: null),
      ];

      sortPlayLists(playlists, SortType.RecentlyPlayed, true);

      expect(playlists[0].title, 'A');
      expect(playlists[1].title, 'Z');
    });

    test('null lastPlayed sorts after non-null', () {
      final now = DateTime.now();
      final playlists = [
        _FakePlaylist(title: 'Null', lastPlayed: null),
        _FakePlaylist(title: 'Has', lastPlayed: now),
      ];

      sortPlayLists(playlists, SortType.RecentlyPlayed, true);

      expect(playlists[0].title, 'Has');
      expect(playlists[1].title, 'Null');
    });
  });

  group('sortArtist', () {
    test('sorts by name ascending (case-insensitive)', () {
      final artists = [
        _FakeArtist(name: 'Zebra'),
        _FakeArtist(name: 'apple'),
        _FakeArtist(name: 'Mango'),
      ];

      sortArtist(artists, SortType.Name, true);

      expect(artists.map((a) => a.name).toList(), ['apple', 'Mango', 'Zebra']);
    });

    test('sorts by name descending', () {
      final artists = [
        _FakeArtist(name: 'apple'),
        _FakeArtist(name: 'Zebra'),
      ];

      sortArtist(artists, SortType.Name, false);

      expect(artists[0].name, 'Zebra');
      expect(artists[1].name, 'apple');
    });
  });
}

class _FakeAlbum {
  final String title;
  final String? year;
  _FakeAlbum({required this.title, this.year});
}

class _FakePlaylist {
  final String title;
  final DateTime? lastPlayed;
  _FakePlaylist({required this.title, this.lastPlayed});
}

class _FakeArtist {
  final String name;
  _FakeArtist({required this.name});
}
