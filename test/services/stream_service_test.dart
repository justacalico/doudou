import 'package:doudou/services/stream_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Audio', () {
    test('toJson serializes all fields', () {
      final audio = Audio(
        itag: 251,
        audioCodec: Codec.opus,
        bitrate: 160000,
        duration: 200,
        loudnessDb: -3.5,
        url: 'https://example.com/audio',
        size: 4096,
      );

      final json = audio.toJson();

      expect(json['itag'], 251);
      expect(json['audioCodec'], 'Codec.opus');
      expect(json['bitrate'], 160000);
      expect(json['approxDurationMs'], 200);
      expect(json['loudnessDb'], -3.5);
      expect(json['url'], 'https://example.com/audio');
      expect(json['size'], 4096);
    });

    test('fromJson round-trips an opus audio', () {
      final original = Audio(
        itag: 251,
        audioCodec: Codec.opus,
        bitrate: 160000,
        duration: 200,
        loudnessDb: -3.5,
        url: 'https://example.com/audio',
        size: 4096,
      );

      final restored = Audio.fromJson(original.toJson());

      expect(restored.itag, 251);
      expect(restored.audioCodec, Codec.opus);
      expect(restored.bitrate, 160000);
      expect(restored.duration, 200);
      expect(restored.loudnessDb, -3.5);
      expect(restored.url, 'https://example.com/audio');
      expect(restored.size, 4096);
    });

    test('fromJson parses mp4a codec', () {
      final audio = Audio.fromJson({
        'itag': 140,
        'audioCodec': 'Codec.mp4a',
        'bitrate': 128000,
        'approxDurationMs': 180,
        'loudnessDb': -2.0,
        'url': 'https://x',
        'size': 2048,
      });

      expect(audio.audioCodec, Codec.mp4a);
      expect(audio.itag, 140);
    });

    test('fromJson defaults missing numeric fields to zero', () {
      final audio = Audio.fromJson({
        'itag': 251,
        'audioCodec': 'Codec.opus',
        'url': 'https://x',
      });

      expect(audio.bitrate, 0);
      expect(audio.duration, 0);
      expect(audio.size, 0);
      expect(audio.loudnessDb, 0.0);
    });

    test('fromJson treats any non-mp4a codec string as opus', () {
      final audio = Audio.fromJson({
        'itag': 1,
        'audioCodec': 'something else',
        'url': 'https://x',
      });

      expect(audio.audioCodec, Codec.opus);
    });
  });

  group('Codec enum', () {
    test('has mp4a and opus values', () {
      expect(Codec.values, contains(Codec.mp4a));
      expect(Codec.values, contains(Codec.opus));
    });
  });

  group('StreamProvider', () {
    test('stores playable, statusMSG, and audioFormats', () {
      final provider = StreamProvider(
        playable: true,
        statusMSG: 'OK',
        audioFormats: [
          Audio(
            itag: 251,
            audioCodec: Codec.opus,
            bitrate: 160000,
            duration: 200,
            loudnessDb: -3.0,
            url: 'https://x',
            size: 1024,
          ),
        ],
      );

      expect(provider.playable, isTrue);
      expect(provider.statusMSG, 'OK');
      expect(provider.audioFormats!.length, 1);
    });

    test('defaults statusMSG to empty string', () {
      final provider = StreamProvider(playable: false);

      expect(provider.statusMSG, '');
    });

    test('hmStreamingData serializes playable state', () {
      final provider = StreamProvider(playable: false, statusMSG: 'err');

      final data = provider.hmStreamingData;

      expect(data['playable'], false);
      expect(data['statusMSG'], 'err');
      expect(data['lowQualityAudio'], isNull);
      expect(data['highQualityAudio'], isNull);
    });

    test('hmStreamingData serializes audio formats', () {
      final audio = Audio(
        itag: 251,
        audioCodec: Codec.opus,
        bitrate: 160000,
        duration: 200,
        loudnessDb: -3.0,
        url: 'https://x',
        size: 1024,
      );
      final provider = StreamProvider(
        playable: true,
        statusMSG: 'OK',
        audioFormats: [audio],
      );

      final data = provider.hmStreamingData;

      expect(data['playable'], true);
      expect(data['statusMSG'], 'OK');
      // On macOS/iOS, highestQualityAudio prefers mp4a; on others, itag 251/140.
      // With only one opus format, the fallback to first applies.
      expect(data['highQualityAudio'], isNotNull);
      expect(data['lowQualityAudio'], isNotNull);
    });
  });
}
