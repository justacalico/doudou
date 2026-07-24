import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getDatestamp', () {
    test('returns days since epoch as a positive int', () {
      final stamp = getDatestamp();

      expect(stamp, isPositive);
      // As of 2024+ we're well past 19000 days since epoch.
      expect(stamp, greaterThan(19000));
    });
  });

  group('parseDuration', () {
    test('returns null for null input', () {
      expect(parseDuration(null), isNull);
    });

    test('parses seconds-only string', () {
      expect(parseDuration('45'), 45);
    });

    test('parses MM:SS', () {
      expect(parseDuration('3:45'), 225);
    });

    test('parses HH:MM:SS', () {
      expect(parseDuration('1:02:03'), 3723);
    });

    test('parses zero', () {
      expect(parseDuration('0:00'), 0);
    });
  });

  group('validatePlaylistId', () {
    test('strips VL prefix', () {
      expect(validatePlaylistId('VLPL123'), 'PL123');
    });

    test('returns unchanged when no VL prefix', () {
      expect(validatePlaylistId('PL123'), 'PL123');
    });

    test('handles empty string', () {
      expect(validatePlaylistId(''), '');
    });
  });

  group('sumTotalDuration', () {
    test('returns 0 when no tracks key', () {
      expect(sumTotalDuration({}), 0);
    });

    test('sums duration_seconds across tracks', () {
      final tracks = [
        MediaItem(id: '1', title: 'A', extras: {'duration_seconds': 100}),
        MediaItem(id: '2', title: 'B', extras: {'duration_seconds': 200}),
        MediaItem(id: '3', title: 'C', extras: {}),
      ];

      expect(sumTotalDuration({'tracks': tracks}), 300);
    });

    test('returns 0 when tracks is empty', () {
      expect(sumTotalDuration({'tracks': <MediaItem>[]}), 0);
    });
  });

  group('getItemText', () {
    test('returns text from flex column run', () {
      final item = {
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Hello'}
                ]
              }
            }
          }
        ],
      };

      expect(getItemText(item, 0), 'Hello');
    });

    test('throws when column missing (known quirk: getFlexColumnItem returns {})', () {
      // getFlexColumnItem returns an empty map (not null) for missing columns,
      // so getItemText's null check doesn't catch it and accessing
      // column['text']['runs'] throws NoSuchMethodError.
      expect(
        () => getItemText({'flexColumns': []}, 0),
        throwsNoSuchMethodError,
      );
    });

    test('throws when column missing with noneIfAbsent (same quirk)', () {
      expect(
        () => getItemText({'flexColumns': []}, 0, noneIfAbsent: true),
        throwsNoSuchMethodError,
      );
    });

    test('returns null when runIndex exceeds runs length', () {
      final item = {
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'only'}
                ]
              }
            }
          }
        ],
      };

      expect(getItemText(item, 0, runIndex: 5, noneIfAbsent: true), isNull);
    });
  });

  group('getFixedColumnItem', () {
    test('returns renderer when runs present', () {
      final item = {
        'fixedColumns': [
          {
            'musicResponsiveListItemFixedColumnRenderer': {
              'text': {
                'runs': [
                  {'text': '3:45'}
                ]
              }
            }
          }
        ],
      };

      final result = getFixedColumnItem(item, 0);

      expect(result, isNotNull);
      expect(result!['text']['runs'][0]['text'], '3:45');
    });

    test('returns null when text has no runs', () {
      final item = {
        'fixedColumns': [
          {
            'musicResponsiveListItemFixedColumnRenderer': {
              'text': {'simpleText': '3:45'}
            }
          }
        ],
      };

      expect(getFixedColumnItem(item, 0), isNull);
    });
  });

  group('isExpired', () {
    test('returns true when both url and epoch are null', () {
      expect(isExpired(), isTrue);
    });

    test('returns false when epoch is far in the future', () {
      final futureEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 999999;
      expect(isExpired(epoch: futureEpoch), isFalse);
    });

    test('returns true when epoch is in the past', () {
      expect(isExpired(epoch: 1), isTrue);
    });

    test('parses expire param from url', () {
      final futureEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 999999;
      final url = 'https://example.com/stream?expire=$futureEpoch&other=x';

      expect(isExpired(url: url), isFalse);
    });

    test('returns true when url has no expire param', () {
      expect(isExpired(url: 'https://example.com/stream'), isTrue);
    });
  });

  group('findObjectByKey', () {
    test('returns the item containing the key', () {
      final list = [
        {'a': 1},
        {'b': 2},
      ];

      final result = findObjectByKey(list, 'b');

      expect(result, {'b': 2});
    });

    test('returns null when no item has the key', () {
      expect(findObjectByKey([{'a': 1}], 'z'), isNull);
    });

    test('returns the key value when isKey is true', () {
      final list = [
        {'a': 1},
      ];

      expect(findObjectByKey(list, 'a', isKey: true), 1);
    });

    test('supports nested lookup', () {
      final list = [
        {'wrapper': {'target': 'found'}},
        {'wrapper': {'other': 'x'}},
      ];

      final result = findObjectByKey(list, 'target', nested: 'wrapper');

      expect(result, {'target': 'found'});
    });
  });

  group('findObjectsByKey', () {
    test('returns all items containing the key', () {
      final list = [
        {'a': 1},
        {'b': 2},
        {'a': 3},
      ];

      final results = findObjectsByKey(list, 'a');

      expect(results.length, 2);
    });

    test('returns empty list when nothing matches', () {
      expect(findObjectsByKey([{'a': 1}], 'z'), isEmpty);
    });

    test('supports nested lookup', () {
      final list = [
        {'wrapper': {'target': 1}},
        {'wrapper': {'other': 2}},
        {'wrapper': {'target': 3}},
      ];

      final results = findObjectsByKey(list, 'target', nested: 'wrapper');

      expect(results.length, 2);
    });
  });

  group('getSearchParams', () {
    test('returns null when no filter, scope, or ignoreSpelling', () {
      expect(getSearchParams(null, null, false), isNull);
    });

    test('returns uploads params for uploads scope', () {
      expect(getSearchParams(null, 'uploads', false), 'agIYAw%3D%3D');
    });

    test('returns library params for library scope without filter', () {
      expect(getSearchParams(null, 'library', false), 'agIYBA%3D%3D');
    });

    test('returns ignoreSpelling params when only ignoreSpelling is true', () {
      expect(getSearchParams(null, null, true), 'EhGKAQ4IARABGAEgASgAOAFAAUICCAE%3D');
    });

    test('returns playlists filter params with spelling', () {
      final params = getSearchParams('playlists', null, false);
      expect(params, 'Eg-KAQwIABAAGAAgACgBMABqChAEEAMQCRAFEAo%3D');
    });

    test('returns playlists filter params ignoring spelling', () {
      final params = getSearchParams('playlists', null, true);
      expect(params, 'Eg-KAQwIABAAGAAgACgBMABCAggBagoQBBADEAkQBRAK');
    });

    test('returns featured_playlists params', () {
      final params = getSearchParams('featured_playlists', null, false);
      expect(params, contains('EgeKAQQoA'));
      expect(params, contains('Dg'));
    });

    test('returns community_playlists params', () {
      final params = getSearchParams('community_playlists', null, false);
      expect(params, contains('EgeKAQQoA'));
      expect(params, contains('EA'));
    });

    test('returns songs filter params', () {
      final params = getSearchParams('songs', null, false);
      expect(params, contains('EgWKAQ'));
      expect(params, contains('II'));
    });

    test('returns library + songs filter params', () {
      final params = getSearchParams('songs', 'library', false);
      expect(params, contains('EgWKAQ'));
      expect(params, contains('II'));
      expect(params, contains('AWoKEAUQCRADEAoYBA%3D%3D'));
    });
  });

  group('getDotSeparatorIndex', () {
    test('returns index of the bullet separator', () {
      final runs = [
        {'text': 'Artist'},
        {'text': ' • '},
        {'text': 'Album'},
      ];

      expect(getDotSeparatorIndex(runs), 1);
    });

    test('returns -1 when no separator present', () {
      final runs = [
        {'text': 'Artist'},
        {'text': 'Album'},
      ];

      expect(getDotSeparatorIndex(runs), -1);
    });
  });
}
