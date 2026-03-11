import 'package:flutter_test/flutter_test.dart';

import 'package:doudou/utils/helper.dart';

void main() {
  group('sanitizeLogMap', () {
    test('masks secret-like keys', () {
      final input = <String, dynamic>{
        'token': 'abc',
        'password': 'pass',
        'cookie': 'c=v',
        'api_key': 'k',
        'Authorization': 'Bearer top-secret',
        'safe': 'ok',
      };

      final sanitized = sanitizeLogMap(input);

      expect(sanitized['token'], '***');
      expect(sanitized['password'], '***');
      expect(sanitized['cookie'], '***');
      expect(sanitized['api_key'], '***');
      expect(sanitized['Authorization'], '***');
      expect(sanitized['safe'], 'ok');
    });

    test('masks nested values in maps and lists', () {
      final input = <String, dynamic>{
        'request': {
          'headers': {
            'Authorization': 'Bearer abc.123',
            'x-custom': 'value',
          },
          'items': [
            {'cookie': 'sid=1'},
            {'name': 'normal'},
          ],
        },
      };

      final sanitized = sanitizeLogMap(input);
      final request = sanitized['request'] as Map<String, dynamic>;
      final headers = request['headers'] as Map<String, dynamic>;
      final items = request['items'] as List<dynamic>;

      expect(headers['Authorization'], '***');
      expect(headers['x-custom'], 'value');
      expect((items[0] as Map<String, dynamic>)['cookie'], '***');
      expect((items[1] as Map<String, dynamic>)['name'], 'normal');
    });
  });

  group('sanitizeLogString', () {
    test('redacts bearer and authorization strings', () {
      const input =
          'Authorization: Bearer very-secret-token bearer second-secret';
      final sanitized = sanitizeLogString(input);

      expect(sanitized.contains('very-secret-token'), isFalse);
      expect(sanitized.contains('second-secret'), isFalse);
      expect(sanitized.contains('Authorization: ***'), isTrue);
      expect(sanitized.contains('Bearer ***'), isTrue);
    });

    test('redacts secret query parameters in URLs', () {
      const input =
          'https://example.com/stream?id=1&token=abc&api_key=xyz&name=ok';
      final sanitized = sanitizeLogString(input);

      expect(sanitized.contains('token=abc'), isFalse);
      expect(sanitized.contains('api_key=xyz'), isFalse);
      expect(
        sanitized.contains('token=%2A%2A%2A') ||
            sanitized.contains('token=***'),
        isTrue,
      );
      expect(
        sanitized.contains('api_key=%2A%2A%2A') ||
            sanitized.contains('api_key=***') ||
            !sanitized.contains('api_key='),
        isTrue,
      );
      expect(sanitized.contains('name=ok'), isTrue);
    });

    test('truncates long strings deterministically', () {
      final input = 'a' * 300;
      final sanitized = sanitizeLogString(input, maxStringLen: 50);

      expect(sanitized.length, 53);
      expect(sanitized.endsWith('...'), isTrue);
    });
  });

  test('sanitizeForLog handles null and mixed types', () {
    final value = {
      'count': 7,
      'ok': true,
      'token': 'secret',
      'list': [
        'safe',
        {'password': 'hidden'}
      ],
    };

    final sanitized = sanitizeForLog(value) as Map<String, dynamic>;
    final list = sanitized['list'] as List<dynamic>;

    expect(sanitized['count'], 7);
    expect(sanitized['ok'], true);
    expect(sanitized['token'], '***');
    expect(list[0], 'safe');
    expect((list[1] as Map<String, dynamic>)['password'], '***');
    expect(sanitizeForLog(null), isNull);
  });
}
