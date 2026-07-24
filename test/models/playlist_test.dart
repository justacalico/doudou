import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/playlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Playlist.fromJson', () {
    test('parses a full playlist payload', () {
      final pl = Playlist.fromJson({
        'title': 'My Mix',
        'playlistId': 'PL123',
        'thumbnails': [
          {'url': 'https://example.com/p.jpg'}
        ],
        'description': 'A cool mix',
        'itemCount': '50 songs',
        'isPipedPlaylist': true,
        'isCloudPlaylist': false,
      });

      expect(pl.title, 'My Mix');
      expect(pl.playlistId, 'PL123');
      expect(pl.description, 'A cool mix');
      expect(pl.songCount, '50 songs');
      expect(pl.isPipedPlaylist, isTrue);
      expect(pl.isCloudPlaylist, isFalse);
    });

    test('falls back to browseId when playlistId missing', () {
      final pl = Playlist.fromJson({
        'title': 'T',
        'browseId': 'BR123',
        'thumbnails': [],
      });

      expect(pl.playlistId, 'BR123');
    });

    test('defaults description to "Playlist"', () {
      final pl = Playlist.fromJson({
        'title': 'T',
        'playlistId': 'p',
        'thumbnails': [],
      });

      expect(pl.description, 'Playlist');
    });

    test('defaults isPipedPlaylist to false', () {
      final pl = Playlist.fromJson({
        'title': 'T',
        'playlistId': 'p',
        'thumbnails': [],
      });

      expect(pl.isPipedPlaylist, isFalse);
    });

    test('defaults isCloudPlaylist to true', () {
      final pl = Playlist.fromJson({
        'title': 'T',
        'playlistId': 'p',
        'thumbnails': [],
      });

      expect(pl.isCloudPlaylist, isTrue);
    });

    test('returns empty thumbnailUrl when thumbnails empty', () {
      final pl = Playlist.fromJson({
        'title': 'T',
        'playlistId': 'p',
        'thumbnails': [],
      });

      expect(pl.thumbnailUrl, '');
    });

    test('returns empty thumbnailUrl when first url is whitespace', () {
      final pl = Playlist.fromJson({
        'title': 'T',
        'playlistId': 'p',
        'thumbnails': [
          {'url': '   '}
        ],
      });

      expect(pl.thumbnailUrl, '');
    });
  });

  group('Playlist.toJson', () {
    test('round-trips basic fields', () {
      final pl = Playlist(
        title: 'T',
        playlistId: 'p',
        thumbnailUrl: 'https://t',
        description: 'd',
        songCount: '10',
        isPipedPlaylist: true,
        isCloudPlaylist: false,
      );

      final json = pl.toJson();

      expect(json['title'], 'T');
      expect(json['playlistId'], 'p');
      expect(json['description'], 'd');
      expect(json['itemCount'], '10');
      expect(json['isPipedPlaylist'], true);
      expect(json['isCloudPlaylist'], false);
      expect((json['thumbnails'] as List).first['url'], 'https://t');
    });
  });

  group('Playlist.copyWith', () {
    test('overrides title and thumbnailUrl only', () {
      final pl = Playlist(
        title: 'Old',
        playlistId: 'p',
        thumbnailUrl: 'https://old',
        description: 'd',
        songCount: '5',
      );

      final copy = pl.copyWith(title: 'New', thumbnailUrl: 'https://new');

      expect(copy.title, 'New');
      expect(copy.thumbnailUrl, 'https://new');
      expect(copy.playlistId, 'p');
      expect(copy.description, 'd');
      expect(copy.songCount, '5');
    });

    test('preserves all fields when no args', () {
      final pl = Playlist(
        title: 'T',
        playlistId: 'p',
        thumbnailUrl: 'https://t',
        description: 'd',
        songCount: '5',
        isPipedPlaylist: true,
        isCloudPlaylist: false,
      );

      final copy = pl.copyWith();

      expect(copy.title, 'T');
      expect(copy.thumbnailUrl, 'https://t');
      expect(copy.isPipedPlaylist, isTrue);
      expect(copy.isCloudPlaylist, isFalse);
    });
  });

  group('Playlist.toMediaItem', () {
    test('produces a MediaItem', () {
      final pl = Playlist(
        title: 'Title',
        playlistId: 'pid',
        thumbnailUrl: 'https://x',
      );

      final item = pl.toMediaItem();

      expect(item, isA<MediaItem>());
      expect(item.id, 'pid');
      expect(item.title, 'Title');
      expect(item.playable, isFalse);
    });
  });

  group('Playlist.newTitle setter', () {
    test('updates title', () {
      final pl = Playlist(
        title: 'Old',
        playlistId: 'p',
        thumbnailUrl: '',
      );

      pl.newTitle = 'Renamed';

      expect(pl.title, 'Renamed');
    });
  });

  group('PlaylistContent', () {
    test('fromJson parses title and playlist list', () {
      final content = PlaylistContent.fromJson({
        'title': 'Featured',
        'playlists': [
          {
            'title': 'P1',
            'playlistId': 'pl1',
            'thumbnails': [],
          },
        ],
      });

      expect(content.title, 'Featured');
      expect(content.playlistList.length, 1);
      expect(content.playlistList[0].title, 'P1');
    });

    test('toJson round-trips', () {
      final content = PlaylistContent(
        title: 'My',
        playlistList: [
          Playlist(title: 'P', playlistId: 'p', thumbnailUrl: 'https://t'),
        ],
      );

      final json = content.toJson();

      expect(json['type'], 'Playlist Content');
      expect(json['title'], 'My');
      expect((json['playlists'] as List).length, 1);
    });
  });
}
