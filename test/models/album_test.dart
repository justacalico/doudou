import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/album.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Album.fromJson', () {
    test('parses a full album payload', () {
      final album = Album.fromJson({
        'title': 'Dark Side of the Moon',
        'browseId': 'MPREb_xxx',
        'artists': [
          {'name': 'Pink Floyd', 'id': 'UCpink'},
        ],
        'year': '1973',
        'audioPlaylistId': 'PLabc',
        'description': 'Studio album',
        'thumbnails': [
          {'url': 'https://example.com/thumb.jpg'}
        ],
      });

      expect(album.title, 'Dark Side of the Moon');
      expect(album.browseId, 'MPREb_xxx');
      expect(album.audioPlaylistId, 'PLabc');
      expect(album.year, '1973');
      expect(album.description, 'Studio album');
      expect(album.artists!.length, 1);
      expect(album.artists![0]['name'], 'Pink Floyd');
    });

    test('falls back to empty artist when artists is null', () {
      final album = Album.fromJson({
        'title': 'No Artist',
        'browseId': 'b',
        'thumbnails': [],
      });

      expect(album.artists, [
        {'name': ''}
      ]);
    });

    test('falls back to type when description is null', () {
      final album = Album.fromJson({
        'title': 'T',
        'browseId': 'b',
        'type': 'Single',
        'thumbnails': [],
      });

      expect(album.description, 'Single');
    });

    test('falls back to "Album" when description and type are null', () {
      final album = Album.fromJson({
        'title': 'T',
        'browseId': 'b',
        'thumbnails': [],
      });

      expect(album.description, 'Album');
    });

    test('returns empty thumbnailUrl when thumbnails missing or empty', () {
      final album = Album.fromJson({
        'title': 'T',
        'browseId': 'b',
        'thumbnails': [],
      });

      expect(album.thumbnailUrl, '');
    });

    test('returns empty thumbnailUrl when first thumb url is whitespace', () {
      final album = Album.fromJson({
        'title': 'T',
        'browseId': 'b',
        'thumbnails': [
          {'url': '   '}
        ],
      });

      expect(album.thumbnailUrl, '');
    });
  });

  group('Album.toJson', () {
    test('round-trips basic fields', () {
      final album = Album(
        title: 'T',
        browseId: 'b',
        artists: [
          {'name': 'A'}
        ],
        year: '2020',
        audioPlaylistId: 'pl',
        description: 'desc',
        thumbnailUrl: 'https://t',
      );

      final json = album.toJson();

      expect(json['title'], 'T');
      expect(json['browseId'], 'b');
      expect(json['year'], '2020');
      expect(json['audioPlaylistId'], 'pl');
      expect(json['description'], 'desc');
      expect((json['thumbnails'] as List).first['url'], 'https://t');
    });
  });

  group('Album.toMediaItem', () {
    test('produces a MediaItem with id and title', () {
      final album = Album(
        title: 'Title',
        browseId: 'bid',
        artists: [
          {'name': 'A'}
        ],
        thumbnailUrl: 'https://x',
      );

      final item = album.toMediaItem();

      expect(item, isA<MediaItem>());
      expect(item.id, 'bid');
      expect(item.title, 'Title');
      expect(item.playable, isFalse);
      expect(item.artUri, Uri.parse('https://x'));
    });
  });

  group('AlbumContent', () {
    test('fromJson parses title and album list', () {
      final content = AlbumContent.fromJson({
        'title': 'Top Albums',
        'albumlist': [
          {
            'title': 'A1',
            'browseId': 'b1',
            'thumbnails': [],
          },
          {
            'title': 'A2',
            'browseId': 'b2',
            'thumbnails': [],
          },
        ],
      });

      expect(content.title, 'Top Albums');
      expect(content.albumList.length, 2);
      expect(content.albumList[0].title, 'A1');
      expect(content.albumList[1].browseId, 'b2');
    });

    test('toJson round-trips', () {
      final content = AlbumContent(
        title: 'My List',
        albumList: [
          Album(
            title: 'A',
            browseId: 'b',
            artists: [
              {'name': 'X'}
            ],
            thumbnailUrl: 'https://t',
          ),
        ],
      );

      final json = content.toJson();

      expect(json['type'], 'Album Content');
      expect(json['title'], 'My List');
      expect((json['albumlist'] as List).length, 1);
    });
  });
}
