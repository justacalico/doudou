// YouTube Music audio playback test.
// Verifies that stream URLs can be resolved for a known video.
// Requires network access; may fail in restricted CI environments.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:doudou/services/players/youtube_music_service.dart';

void main() {
  group('YouTube Music playback', () {
    late YouTubeMusicService service;

    setUp(() {
      service = YouTubeMusicService();
    });

    test('resolves at least one stream URL for a known video', () async {
      // Use a well-known public video ID (e.g. Rick Astley - Never Gonna Give You Up)
      const videoId = 'dQw4w9WgXcQ';

      final urls = await service.getAlternativeStreamUrlsAsync(
        videoId,
        requireAuth: false,
      );

      expect(urls, isNotEmpty, reason: 'Should resolve at least one stream URL');
      expect(
        urls.every((u) => u.startsWith('http://') || u.startsWith('https://')),
        isTrue,
        reason: 'All URLs should be valid HTTP(S)',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('resolved stream URL is reachable', () async {
      const videoId = 'dQw4w9WgXcQ';

      final urls = await service.getAlternativeStreamUrlsAsync(
        videoId,
        requireAuth: false,
      );

      if (urls.isEmpty) {
        fail('No stream URLs resolved - cannot verify reachability');
      }

      final client = http.Client();
      try {
        final response = await client
            .head(Uri.parse(urls.first))
            .timeout(const Duration(seconds: 10));

        expect(
          response.statusCode,
          anyOf(200, 206),
          reason: 'Stream URL should return 200 OK or 206 Partial',
        );
      } finally {
        client.close();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
