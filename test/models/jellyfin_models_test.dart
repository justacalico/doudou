import 'package:doudou/models/jellyfin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JellyfinServer', () {
    test('toJson serializes all fields', () {
      final server = JellyfinServer(
        serverUrl: 'https://jellyfin.example',
        apiKey: 'key123',
        userId: 'user42',
        accessToken: 'tok',
        username: 'alice',
        password: 'pw',
      );

      final json = server.toJson();

      expect(json['serverUrl'], 'https://jellyfin.example');
      expect(json['apiKey'], 'key123');
      expect(json['userId'], 'user42');
      expect(json['accessToken'], 'tok');
      expect(json['username'], 'alice');
      expect(json['password'], 'pw');
    });

    test('fromJson round-trips', () {
      final original = JellyfinServer(
        serverUrl: 'https://demo.jellyfin.org',
        apiKey: 'k',
        userId: 'u',
        accessToken: 'a',
        username: 'bob',
        password: 'p',
      );

      final restored = JellyfinServer.fromJson(original.toJson());

      expect(restored.serverUrl, original.serverUrl);
      expect(restored.apiKey, original.apiKey);
      expect(restored.userId, original.userId);
      expect(restored.accessToken, original.accessToken);
      expect(restored.username, original.username);
      expect(restored.password, original.password);
    });

    test('fromJson handles null optional fields', () {
      final restored = JellyfinServer.fromJson({
        'serverUrl': 'https://x',
      });

      expect(restored.serverUrl, 'https://x');
      expect(restored.apiKey, isNull);
      expect(restored.userId, isNull);
      expect(restored.accessToken, isNull);
      expect(restored.username, isNull);
      expect(restored.password, isNull);
    });
  });

  group('Album (jellyfin)', () {
    test('defaults isFavorite to false', () {
      final album = Album(id: 'a1', name: 'Greatest Hits');

      expect(album.isFavorite, isFalse);
      expect(album.id, 'a1');
      expect(album.name, 'Greatest Hits');
    });

    test('copyWith overrides only provided fields', () {
      final album = Album(
        id: 'a1',
        name: 'Old',
        artistName: 'Old Artist',
        year: 1999,
        isFavorite: false,
      );

      final updated = album.copyWith(name: 'New', isFavorite: true);

      expect(updated.id, 'a1');
      expect(updated.name, 'New');
      expect(updated.artistName, 'Old Artist');
      expect(updated.year, 1999);
      expect(updated.isFavorite, isTrue);
    });

    test('copyWith preserves dateCreated when not overridden', () {
      final date = DateTime.utc(2024, 1, 2);
      final album = Album(id: 'a', name: 'n', dateCreated: date);
      final copy = album.copyWith(name: 'm');

      expect(copy.dateCreated, date);
    });
  });

  group('Track', () {
    test('stores all fields', () {
      final track = Track(
        id: 't1',
        name: 'Song',
        albumName: 'Album',
        artistName: 'Artist',
        albumId: 'a1',
        playlistItemId: 'p1',
        duration: 240,
        trackNumber: 5,
        imageUrl: 'https://img',
        isFavorite: true,
        playCount: 12,
      );

      expect(track.id, 't1');
      expect(track.name, 'Song');
      expect(track.albumName, 'Album');
      expect(track.artistName, 'Artist');
      expect(track.albumId, 'a1');
      expect(track.playlistItemId, 'p1');
      expect(track.duration, 240);
      expect(track.trackNumber, 5);
      expect(track.imageUrl, 'https://img');
      expect(track.isFavorite, isTrue);
      expect(track.playCount, 12);
    });

    test('defaults isFavorite to false', () {
      final track = Track(id: 't', name: 'n');
      expect(track.isFavorite, isFalse);
    });
  });

  group('Artist (jellyfin)', () {
    test('stores id, name, imageUrl', () {
      final artist = Artist(id: 'ar1', name: 'Pink Floyd', imageUrl: 'https://i');

      expect(artist.id, 'ar1');
      expect(artist.name, 'Pink Floyd');
      expect(artist.imageUrl, 'https://i');
    });
  });

  group('Playlist (jellyfin)', () {
    test('stores fields including trackCount', () {
      final pl = Playlist(id: 'pl1', name: 'Mix', imageUrl: 'https://i', trackCount: 42);

      expect(pl.id, 'pl1');
      expect(pl.name, 'Mix');
      expect(pl.imageUrl, 'https://i');
      expect(pl.trackCount, 42);
    });
  });

  group('Library', () {
    test('stores fields', () {
      final lib = Library(
        id: 'l1',
        name: 'Music',
        collectionType: 'music',
        imageUrl: 'https://i',
      );

      expect(lib.id, 'l1');
      expect(lib.name, 'Music');
      expect(lib.collectionType, 'music');
      expect(lib.imageUrl, 'https://i');
    });
  });

  group('SearchResults', () {
    test('defaults to empty lists', () {
      const results = SearchResults();

      expect(results.albums, isEmpty);
      expect(results.artists, isEmpty);
      expect(results.tracks, isEmpty);
    });

    test('stores provided lists', () {
      final results = SearchResults(
        albums: [Album(id: 'a', name: 'A')],
        artists: [Artist(id: 'ar', name: 'AR')],
        tracks: [Track(id: 't', name: 'T')],
      );

      expect(results.albums.length, 1);
      expect(results.artists.length, 1);
      expect(results.tracks.length, 1);
    });
  });
}
