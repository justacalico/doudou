import 'package:doudou/services/continuations.dart';
import 'package:doudou/services/nav_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getContinuationToken', () {
    test('extracts token from last continuation item', () {
      final results = [
        {'other': 1},
        {
          'continuationItemRenderer': {
            'continuationEndpoint': {
              'continuationCommand': {'token': 'tok123'}
            }
          }
        },
      ];

      expect(getContinuationToken(results), 'tok123');
    });

    test('returns null when no continuation item', () {
      expect(getContinuationToken([{'a': 1}]), isNull);
    });

    test('throws StateError for empty list (known quirk)', () {
      // getContinuationToken calls results.last before nav(), so an empty
      // list throws StateError rather than returning null.
      expect(() => getContinuationToken([]), throwsStateError);
    });
  });

  group('getContinuationString', () {
    test('builds ctoken and continuation query string', () {
      expect(getContinuationString('abc'), '&ctoken=abc&continuation=abc');
    });

    test('handles null ctoken', () {
      expect(getContinuationString(null), '&ctoken=null&continuation=null');
    });
  });

  group('getContinuationParams', () {
    test('extracts next continuation data', () {
      final results = {
        'continuations': [
          {
            'nextContinuationData': {'continuation': 'nextTok'}
          }
        ],
      };

      expect(getContinuationParams(results), '&ctoken=nextTok&continuation=nextTok');
    });

    test('uses ctokenPath to navigate custom continuation data', () {
      final results = {
        'continuations': [
          {
            'nextCustomContinuationData': {'continuation': 'customTok'}
          }
        ],
      };

      expect(
        getContinuationParams(results, ctokenPath: 'Custom'),
        '&ctoken=customTok&continuation=customTok',
      );
    });
  });

  group('getReloadableContinuationParams', () {
    test('extracts reload continuation data', () {
      final results = {
        'continuations': [
          {
            'reloadContinuationData': {'continuation': 'reloadTok'}
          }
        ],
      };

      expect(
        getReloadableContinuationParams(results),
        '&ctoken=reloadTok&continuation=reloadTok',
      );
    });
  });

  group('getContinuationContents', () {
    test('parses contents key when present', () {
      final continuation = {
        'contents': [1, 2, 3],
      };

      final result = getContinuationContents(continuation, (items) => items);

      expect(result, [1, 2, 3]);
    });

    test('parses items key when contents absent', () {
      final continuation = {
        'items': ['a', 'b'],
      };

      final result = getContinuationContents(continuation, (items) => items);

      expect(result, ['a', 'b']);
    });

    test('returns empty list when neither key present', () {
      expect(getContinuationContents({}, (_) => []), isEmpty);
    });

    test('uses parseFunc to transform items', () {
      final continuation = {
        'contents': [1, 2, 3],
      };

      final result = getContinuationContents(continuation, (items) => items.map((e) => e * 2).toList());

      expect(result, [2, 4, 6]);
    });
  });

  group('validateResponse', () {
    test('returns true when parsed count meets expected', () {
      // perPage=5, limit=5, currentCount=0 → expected = min(5, 5) = 5
      expect(validateResponse({'parsed': [1, 2, 3, 4, 5]}, 5, 5, 0), isTrue);
    });

    test('returns false when parsed count is below expected', () {
      expect(validateResponse({'parsed': [1]}, 5, 5, 0), isFalse);
    });

    test('expected count is clamped to perPage when remaining is larger', () {
      // remaining = 100 - 0 = 100, perPage = 10, expected = min(10, 100) = 10
      expect(validateResponse({'parsed': List.filled(10, 1)}, 10, 100, 0), isTrue);
      expect(validateResponse({'parsed': List.filled(9, 1)}, 10, 100, 0), isFalse);
    });

    test('expected count is clamped to remaining when smaller than perPage', () {
      // remaining = 3 - 1 = 2, perPage = 10, expected = min(10, 2) = 2
      expect(validateResponse({'parsed': [1, 2]}, 10, 3, 1), isTrue);
      expect(validateResponse({'parsed': [1]}, 10, 3, 1), isFalse);
    });
  });

  group('getParsedContinuationItems', () {
    test('extracts results and parsed items for continuationType', () {
      final response = {
        'continuationContents': {
          'musicShelfContinuation': {
            'contents': ['a', 'b'],
          },
        },
      };

      final result = getParsedContinuationItems(
        response,
        (dynamic contents) => (contents as List).map((e) => e.toString().toUpperCase()).toList(),
        'musicShelfContinuation',
      );

      expect(result['results'], isA<Map>());
      expect(result['parsed'], ['A', 'B']);
    });
  });

  group('getContinuationsPlaylist', () {
    test('fetches items until limit reached', () async {
      final contents = [
        {'videoId': 'v1'},
        {
          'continuationItemRenderer': {
            'continuationEndpoint': {
              'continuationCommand': {'token': 'tok2'}
            }
          }
        },
      ];

      int callCount = 0;
      Future<Map<String, dynamic>> requestFunc(Map<String, dynamic> params) async {
        callCount++;
        if (callCount == 1) {
          return {
            'onResponseReceivedActions': [
              {
                'appendContinuationItemsAction': {
                  'continuationItems': [
                    {'videoId': 'v2'},
                    {
                      'continuationItemRenderer': {
                        'continuationEndpoint': {
                          'continuationCommand': {'token': 'tok3'}
                        }
                      }
                    },
                  ],
                }
              }
            ]
          };
        }
        return {
          'onResponseReceivedActions': [
            {
              'appendContinuationItemsAction': {
                'continuationItems': [
                  {'videoId': 'v3'},
                  {'videoId': 'v4'},
                ],
              }
            }
          ]
        };
      }

      final items = await getContinuationsPlaylist(
        {'contents': contents},
        3,
        requestFunc,
        (items) => (items as List)
            .whereType<Map>()
            .where((e) => e.containsKey('videoId'))
            .toList(),
      );

      expect(items.length, 3);
    });

    test('stops when continuation items are empty', () async {
      final contents = [
        {
          'continuationItemRenderer': {
            'continuationEndpoint': {
              'continuationCommand': {'token': 'tok'}
            }
          }
        },
      ];

      Future<Map<String, dynamic>> requestFunc(Map<String, dynamic> params) async {
        return {
          'onResponseReceivedActions': [
            {
              'appendContinuationItemsAction': {
                'continuationItems': <dynamic>[],
              }
            }
          ]
        };
      }

      final items = await getContinuationsPlaylist(
        {'contents': contents},
        100,
        requestFunc,
        (items) => (items as List).whereType<Map>().toList(),
      );

      expect(items, isEmpty);
    });

    test('stops on request error', () async {
      final contents = [
        {
          'continuationItemRenderer': {
            'continuationEndpoint': {
              'continuationCommand': {'token': 'tok'}
            }
          }
        },
      ];

      Future<Map<String, dynamic>> requestFunc(Map<String, dynamic> params) async {
        throw Exception('network error');
      }

      final items = await getContinuationsPlaylist(
        {'contents': contents},
        100,
        requestFunc,
        (items) => (items as List).whereType<Map>().toList(),
      );

      expect(items, isEmpty);
    });
  });

  group('getContinuations', () {
    test('returns empty list when no continuations and no additionalParams', () async {
      final items = await getContinuations(
        {'someKey': 1},
        'musicShelfContinuation',
        10,
        (_) async => {},
        (_) => [],
      );

      expect(items, isEmpty);
    });

    test('fetches items using additionalParams_', () async {
      int callCount = 0;
      Future<Map<String, dynamic>> requestFunc(String params) async {
        callCount++;
        if (callCount == 1) {
          return {
            'continuationContents': {
              'musicShelfContinuation': {
                'contents': [1, 2],
              },
            },
          };
        }
        return {
          'continuationContents': {
            'musicShelfContinuation': {
              'contents': <dynamic>[],
            },
          },
        };
      }

      final items = await getContinuations(
        {},
        'musicShelfContinuation',
        10,
        requestFunc,
        (dynamic contents) => (contents as List).whereType<int>().toList(),
        additionalParams_: 'params1',
      );

      expect(items, [1, 2]);
    });
  });

  group('resendRequestUntilParsedResponseIsValid', () {
    test('returns first valid response without retry', () async {
      Future<dynamic> requestFunc(String params) async => {'data': 1};
      dynamic parseFunc(dynamic r) => {'parsed': [1, 2, 3]};
      bool validateFunc(dynamic r) => true;

      final result = await resendRequestUntilParsedResponseIsValid(
        requestFunc,
        'p',
        parseFunc,
        validateFunc,
        3,
      );

      expect(result['parsed'].length, 3);
    });

    test('retries until valid response', () async {
      int callCount = 0;
      Future<dynamic> requestFunc(String params) async {
        callCount++;
        return {'call': callCount};
      }

      dynamic parseFunc(dynamic r) => {'parsed': List.filled((r['call'] as int), 1)};
      bool validateFunc(dynamic r) => (r['parsed'] as List).length >= 3;

      final result = await resendRequestUntilParsedResponseIsValid(
        requestFunc,
        'p',
        parseFunc,
        validateFunc,
        5,
      );

      expect(result['parsed'].length, 3);
      expect(callCount, 3);
    });

    test('stops after maxRetries even if not valid', () async {
      int callCount = 0;
      Future<dynamic> requestFunc(String params) async {
        callCount++;
        return {'call': callCount};
      }

      dynamic parseFunc(dynamic r) => {'parsed': [1]};
      bool validateFunc(dynamic r) => false;

      final result = await resendRequestUntilParsedResponseIsValid(
        requestFunc,
        'p',
        parseFunc,
        validateFunc,
        2,
      );

      expect(callCount, 3); // 1 initial + 2 retries
      expect(result['parsed'].length, 1);
    });

    test('keeps the longer parsed result across retries', () async {
      int callCount = 0;
      Future<dynamic> requestFunc(String params) async {
        callCount++;
        return {'call': callCount};
      }

      // First call returns 1 item, second returns 5, third returns 2
      dynamic parseFunc(dynamic r) {
        final c = r['call'] as int;
        return {'parsed': List.filled(c == 2 ? 5 : (c == 3 ? 2 : 1), 1)};
      }

      bool validateFunc(dynamic r) => (r['parsed'] as List).length >= 10;

      final result = await resendRequestUntilParsedResponseIsValid(
        requestFunc,
        'p',
        parseFunc,
        validateFunc,
        3,
      );

      // Should keep the 5-item result from call 2
      expect(result['parsed'].length, 5);
    });
  });
}
