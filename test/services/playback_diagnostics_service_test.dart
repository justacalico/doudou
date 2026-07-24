import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/utils/helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaybackDiagnosticsService.sanitizeUrl', () {
    test('returns empty string for null input', () {
      expect(PlaybackDiagnosticsService.sanitizeUrl(null), '');
    });

    test('returns empty string for empty input', () {
      expect(PlaybackDiagnosticsService.sanitizeUrl(''), '');
    });

    test('redacts token query parameters in a stream URL', () {
      final sanitized = PlaybackDiagnosticsService.sanitizeUrl(
        'https://example.com/stream?id=1&token=secret&api_key=k',
      );

      expect(sanitized, isNot(contains('secret')));
      expect(sanitized, isNot(contains('api_key=k')));
    });

    test('preserves non-secret query parameters', () {
      final sanitized = PlaybackDiagnosticsService.sanitizeUrl(
        'https://example.com/stream?id=1&name=ok',
      );

      // The sanitized URL may re-encode, but the safe param value survives.
      expect(sanitized, contains('id=1'));
      expect(sanitized, contains('name=ok'));
    });

    test('delegates to sanitizeLogString for non-URL strings', () {
      final input = 'Authorization: Bearer abc.def';
      final sanitized = PlaybackDiagnosticsService.sanitizeUrl(input);

      expect(sanitized, isNot(contains('abc.def')));
    });
  });
}
