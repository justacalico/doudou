import 'dart:typed_data';

import 'package:doudou/server/sync_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toWireValue/fromWireValue', () {
    test('passes through json primitives', () {
      expect(toWireValue('x'), 'x');
      expect(toWireValue(3), 3);
      expect(toWireValue(2.5), 2.5);
      expect(toWireValue(true), true);
      expect(toWireValue(null), isNull);
    });

    test('round trips nested maps and lists', () {
      final value = {
        'title': 'song',
        'duration': 201,
        'artists': ['a', 'b'],
        'nested': {
          'flag': true,
          'items': [
            {'x': 1},
            {'y': null},
          ],
        },
      };
      final wire = toWireValue(value);
      expect(wire, isA<Map>());
      expect(fromWireValue(wire), value);
    });

    test('stringifies non string map keys', () {
      final wire = toWireValue({1: 'one', 'k': 'v'}) as Map;
      expect(wire['1'], 'one');
      expect(wire['k'], 'v');
      expect(fromWireValue(wire), {'1': 'one', 'k': 'v'});
    });

    test('encodes bytes as base64 and decodes them back', () {
      final bytes = Uint8List.fromList([1, 2, 3, 250]);
      final wire = toWireValue(bytes) as Map;
      expect(wire.containsKey('\$b64'), isTrue);
      final back = fromWireValue(wire);
      expect(back, isA<Uint8List>());
      expect(back, bytes);
    });

    test('handles bytes nested inside structures', () {
      final value = {
        'blob': Uint8List.fromList([9, 9]),
        'list': [Uint8List.fromList([7])],
      };
      final back = fromWireValue(toWireValue(value)) as Map;
      expect(back['blob'], Uint8List.fromList([9, 9]));
      expect((back['list'] as List).first, Uint8List.fromList([7]));
    });

    test('falls back to string for unknown types', () {
      final back = fromWireValue(toWireValue(DateTime(2024, 1, 1)));
      expect(back, isA<String>());
    });
  });

  group('valueHash', () {
    test('is stable regardless of map key order', () {
      final a = {'x': 1, 'y': 2, 'z': {'p': true, 'q': 's'}};
      final b = {'z': {'q': 's', 'p': true}, 'y': 2, 'x': 1};
      expect(valueHash(a), valueHash(b));
    });

    test('differs for different values', () {
      expect(valueHash({'x': 1}), isNot(valueHash({'x': 2})));
      expect(valueHash('a'), isNot(valueHash('b')));
    });

    test('differs between value and missing', () {
      expect(valueHash(null), isA<String>());
    });
  });
}
