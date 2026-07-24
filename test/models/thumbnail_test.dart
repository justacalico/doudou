import 'package:doudou/models/thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('Thumbnail.sizewith', () {
    test('rewrites -rj style URLs with size param', () {
      final t = Thumbnail('https://example.com/photo-rj');

      final sized = t.sizewith(400);

      expect(sized, contains('=w400-h400-l90-rj'));
    });

    test('rewrites =s style URLs with size param', () {
      final t = Thumbnail('https://example.com/photo=s100');

      final sized = t.sizewith(250);

      expect(sized, 'https://example.com/photo=s250');
    });

    test('returns url unchanged for unknown pattern and small size', () {
      final t = Thumbnail('https://example.com/photo.jpg');

      final sized = t.sizewith(150);

      expect(sized, 'https://example.com/photo.jpg');
    });
  });

  group('Thumbnail getters', () {
    test('high returns sizewith(400)', () {
      final t = Thumbnail('https://example.com/photo=s100');

      expect(t.high, 'https://example.com/photo=s400');
    });

    test('medium returns sizewith(250)', () {
      final t = Thumbnail('https://example.com/photo=s100');

      expect(t.medium, 'https://example.com/photo=s250');
    });

    test('low returns sizewith(150)', () {
      final t = Thumbnail('https://example.com/photo=s100');

      expect(t.low, 'https://example.com/photo=s150');
    });

    test('url returns the raw url', () {
      const raw = 'https://example.com/photo=s100';
      final t = Thumbnail(raw);

      expect(t.url, raw);
    });
  });

  group('Thumbnail.extraHigh', () {
    test('uses 1000 on desktop platforms', () {
      // GetPlatform.isDesktop reflects the host running the test.
      // We just assert the getter returns a non-empty string and that
      // the size param matches the platform's expectation.
      final t = Thumbnail('https://example.com/photo=s100');
      final extra = t.extraHigh;

      if (GetPlatform.isDesktop) {
        expect(extra, 'https://example.com/photo=s1000');
      } else {
        expect(extra, 'https://example.com/photo=s600');
      }
    });
  });
}
