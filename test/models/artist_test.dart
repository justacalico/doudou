import 'package:doudou/models/artist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Artist.fromJson', () {
    test('prefers artist field, then name, then title', () {
      final fromArtist = Artist.fromJson({'artist': 'A', 'browseId': 'b'});
      final fromName = Artist.fromJson({'name': 'N', 'browseId': 'b'});
      final fromTitle = Artist.fromJson({'title': 'T', 'browseId': 'b'});

      expect(fromArtist.name, 'A');
      expect(fromName.name, 'N');
      expect(fromTitle.name, 'T');
    });

    test('falls back to empty name when no name field present', () {
      final artist = Artist.fromJson({'browseId': 'b'});

      expect(artist.name, '');
    });

    test('handles non-Map input gracefully', () {
      final artist = Artist.fromJson('not a map');

      expect(artist.name, '');
      expect(artist.browseId, '');
      expect(artist.subscribers, '');
      expect(artist.thumbnailUrl, '');
    });

    test('parses subscribers as string', () {
      final artist = Artist.fromJson({
        'artist': 'A',
        'browseId': 'b',
        'subscribers': '12M subscribers',
      });

      expect(artist.subscribers, '12M subscribers');
    });

    test('parses subscribers as map with text field', () {
      final artist = Artist.fromJson({
        'artist': 'A',
        'browseId': 'b',
        'subscribers': {'text': '5M subscribers'},
      });

      expect(artist.subscribers, '5M subscribers');
    });

    test('handles null subscribers', () {
      final artist = Artist.fromJson({
        'artist': 'A',
        'browseId': 'b',
        'subscribers': null,
      });

      expect(artist.subscribers, '');
    });

    test('parses thumbnail url from list', () {
      final artist = Artist.fromJson({
        'artist': 'A',
        'browseId': 'b',
        'thumbnails': [
          {'url': 'https://example.com/i.jpg'}
        ],
      });

      expect(artist.thumbnailUrl, isNotEmpty);
    });

    test('returns empty thumbnail when thumbnails missing', () {
      final artist = Artist.fromJson({'artist': 'A', 'browseId': 'b'});

      expect(artist.thumbnailUrl, '');
    });

    test('parses radioId when present', () {
      final artist = Artist.fromJson({
        'artist': 'A',
        'browseId': 'b',
        'radioId': 'RDAMxxx',
      });

      expect(artist.radioId, 'RDAMxxx');
    });

    test('radioId is null when absent', () {
      final artist = Artist.fromJson({'artist': 'A', 'browseId': 'b'});

      expect(artist.radioId, isNull);
    });
  });

  group('Artist.toJson', () {
    test('serializes all fields', () {
      final artist = Artist(
        name: 'Pink Floyd',
        browseId: 'UCpink',
        radioId: 'RD',
        subscribers: '5M',
        thumbnailUrl: 'https://t',
      );

      final json = artist.toJson();

      expect(json['artist'], 'Pink Floyd');
      expect(json['browseId'], 'UCpink');
      expect(json['radioId'], 'RD');
      expect(json['subscribers'], '5M');
      expect((json['thumbnails'] as List).first['url'], 'https://t');
    });
  });

  group('ArtistContent', () {
    test('uses default title', () {
      final content = ArtistContent([]);

      expect(content.title, 'Artists');
      expect(content.content, isEmpty);
    });

    test('stores custom title and content', () {
      final artists = [
        Artist(name: 'A', browseId: 'b', thumbnailUrl: ''),
      ];
      final content = ArtistContent(artists, title: 'Featured');

      expect(content.title, 'Featured');
      expect(content.content.length, 1);
    });
  });
}
