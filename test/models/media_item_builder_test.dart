import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/media_Item_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaItemBuilder.fromJson', () {
    test('parses title, videoId, and artists', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'My Song',
        'videoId': 'vid1',
        'artists': [
          {'name': 'Artist A', 'id': 'a1'},
          {'name': 'Artist B', 'id': 'a2'},
        ],
        'thumbnails': [
          {'url': 'https://example.com/t.jpg'}
        ],
      });

      expect(item.id, 'vid1');
      expect(item.title, 'My Song');
      expect(item.artist, 'Artist A, Artist B');
    });

    test('handles empty/invalid json without throwing', () {
      final item = MediaItemBuilder.fromJson(null);
      expect(item.id, '');
      expect(item.title, '');
      expect(item.artist, '');
    });

    test('handles artists that are not a list', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'artists': 'not a list',
      });

      expect(item.artist, '');
    });

    test('filters out empty/whitespace artist names', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'artists': [
          {'name': 'Real'},
          {'name': '   '},
          {'name': ''},
          {'name': 'Other'},
        ],
      });

      expect(item.artist, 'Real, Other');
    });

    test('handles artists entries that are not maps', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'artists': ['string', 42, {'name': 'OK'}],
      });

      expect(item.artist, 'OK');
    });

    test('parses album when album map has an id', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'album': {'name': 'Album Name', 'id': 'alb1'},
      });

      expect(item.album, 'Album Name');
      expect(item.extras!['album'], isA<Map>());
    });

    test('ignores album when album map has no id', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'album': {'name': 'No Id'},
      });

      expect(item.album, isNull);
    });

    test('parses duration from numeric seconds', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'duration': 180,
      });

      expect(item.duration, const Duration(seconds: 180));
    });

    test('parses duration from string seconds', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'duration': '240',
      });

      expect(item.duration, const Duration(seconds: 240));
    });

    test('parses duration from length string MM:SS', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'length': '3:45',
      });

      expect(item.duration, const Duration(minutes: 3, seconds: 45));
    });

    test('parses duration from length string HH:MM:SS', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'length': '1:02:03',
      });

      expect(item.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('returns null duration when no duration or length', () {
      final item = MediaItemBuilder.fromJson({'title': 'T', 'videoId': 'v'});

      expect(item.duration, isNull);
    });

    test('prefers duration seconds over length string', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'duration': 100,
        'length': '3:45',
      });

      expect(item.duration, const Duration(seconds: 100));
    });

    test('stores url in extras when provided in json', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'url': 'https://stream.url',
      });

      expect(item.extras!['url'], 'https://stream.url');
    });

    test('uses url argument when json url is empty', () {
      final item = MediaItemBuilder.fromJson(
        {'title': 'T', 'videoId': 'v'},
        url: 'https://arg.url',
      );

      expect(item.extras!['url'], 'https://arg.url');
    });

    test('stores extras fields (date, year, trackDetails)', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'date': '2024-01-01',
        'year': '2024',
        'trackDetails': '1/10',
      });

      expect(item.extras!['date'], '2024-01-01');
      expect(item.extras!['year'], '2024');
      expect(item.extras!['trackDetails'], '1/10');
    });

    test('parses thumbnail url into artUri', () {
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'thumbnails': [
          {'url': 'https://example.com/photo=s100'}
        ],
      });

      expect(item.artUri, isNotNull);
      expect(item.artUri.toString(), isNotEmpty);
    });

    test('handles invalid thumbnail url without throwing', () {
      // Uri.parse is lenient and doesn't throw for most strings;
      // the important thing is that fromJson doesn't crash.
      final item = MediaItemBuilder.fromJson({
        'title': 'T',
        'videoId': 'v',
        'thumbnails': [
          {'url': '%%not-a-url%%'}
        ],
      });

      expect(item.artUri, isNotNull);
    });
  });

  group('MediaItemBuilder.toDuration', () {
    test('parses HH:MM:SS', () {
      expect(
        MediaItemBuilder.toDuration('1:23:45'),
        const Duration(hours: 1, minutes: 23, seconds: 45),
      );
    });

    test('parses MM:SS', () {
      expect(
        MediaItemBuilder.toDuration('5:30'),
        const Duration(minutes: 5, seconds: 30),
      );
    });

    test('parses single number as seconds', () {
      expect(MediaItemBuilder.toDuration('90'), const Duration(seconds: 90));
    });

    test('returns null for null input', () {
      expect(MediaItemBuilder.toDuration(null), isNull);
    });

    test('handles invalid segments as zero', () {
      expect(
        MediaItemBuilder.toDuration('xx:yy'),
        Duration.zero,
      );
    });

    test('handles empty string as zero seconds', () {
      expect(MediaItemBuilder.toDuration(''), const Duration(seconds: 0));
    });
  });

  group('MediaItemBuilder.toJson', () {
    test('round-trips a MediaItem', () {
      final original = MediaItem(
        id: 'vid1',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(seconds: 200),
        artUri: Uri.parse('https://example.com/t.jpg'),
        extras: {
          'url': 'https://stream',
          'length': '3:20',
          'album': {'name': 'Album', 'id': 'a1'},
          'artists': [
            {'name': 'Artist', 'id': 'ar1'}
          ],
          'date': '2024-01-01',
          'trackDetails': '1/10',
          'year': '2024',
          'backendType': 'subsonic',
          'serverId': 2,
        },
      );

      final json = MediaItemBuilder.toJson(original);

      expect(json['videoId'], 'vid1');
      expect(json['title'], 'Song');
      expect(json['duration'], 200);
      expect(json['url'], 'https://stream');
      expect(json['length'], '3:20');
      expect(json['year'], '2024');
      expect(json['backendType'], 'subsonic');
      expect(json['serverId'], 2);
      expect((json['thumbnails'] as List).first['url'], 'https://example.com/t.jpg');
    });
  });
}
