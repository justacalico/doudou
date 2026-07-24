import 'package:doudou/models/hm_streaming_data.dart';
import 'package:doudou/services/stream_service.dart';
import 'package:flutter_test/flutter_test.dart';

Audio _audio(int itag) => Audio(
      itag: itag,
      audioCodec: Codec.opus,
      bitrate: 128000,
      duration: 200,
      loudnessDb: -3.0,
      url: 'https://example.com/a$itag',
      size: 1024,
    );

void main() {
  group('HMStreamingData.fromJson', () {
    test('parses playable payload with both audio formats', () {
      final data = HMStreamingData.fromJson({
        'playable': true,
        'statusMSG': 'OK',
        'lowQualityAudio': {
          'itag': 249,
          'audioCodec': 'Codec.opus',
          'bitrate': 64000,
          'approxDurationMs': 200,
          'loudnessDb': -3.0,
          'url': 'https://low',
          'size': 512,
        },
        'highQualityAudio': {
          'itag': 251,
          'audioCodec': 'Codec.opus',
          'bitrate': 160000,
          'approxDurationMs': 200,
          'loudnessDb': -3.0,
          'url': 'https://high',
          'size': 2048,
        },
      });

      expect(data.playable, isTrue);
      expect(data.statusMSG, 'OK');
      expect(data.lowQualityAudio, isNotNull);
      expect(data.highQualityAudio, isNotNull);
      expect(data.lowQualityAudio!.itag, 249);
      expect(data.highQualityAudio!.itag, 251);
    });

    test('parses non-playable payload without audio formats', () {
      final data = HMStreamingData.fromJson({
        'playable': false,
        'statusMSG': 'VideoUnplayable',
      });

      expect(data.playable, isFalse);
      expect(data.statusMSG, 'VideoUnplayable');
      expect(data.lowQualityAudio, isNull);
      expect(data.highQualityAudio, isNull);
    });
  });

  group('HMStreamingData.audio getter', () {
    test('returns high quality audio by default (qualityIndex=1)', () {
      final low = _audio(249);
      final high = _audio(251);
      final data = HMStreamingData(
        playable: true,
        statusMSG: 'OK',
        lowQualityAudio: low,
        highQualityAudio: high,
      );

      expect(data.audio, high);
    });

    test('returns low quality audio when qualityIndex=0', () {
      final low = _audio(249);
      final high = _audio(251);
      final data = HMStreamingData(
        playable: true,
        statusMSG: 'OK',
        lowQualityAudio: low,
        highQualityAudio: high,
      );

      data.setQualityIndex(0);

      expect(data.audio, low);
    });

    test('returns high quality audio when qualityIndex=1 after switch', () {
      final low = _audio(249);
      final high = _audio(251);
      final data = HMStreamingData(
        playable: true,
        statusMSG: 'OK',
        lowQualityAudio: low,
        highQualityAudio: high,
      );

      data.setQualityIndex(0);
      data.setQualityIndex(1);

      expect(data.audio, high);
    });
  });

  group('HMStreamingData.toJson', () {
    test('round-trips playable payload', () {
      final low = _audio(249);
      final high = _audio(251);
      final data = HMStreamingData(
        playable: true,
        statusMSG: 'OK',
        lowQualityAudio: low,
        highQualityAudio: high,
      );

      final json = data.toJson();

      expect(json['playable'], true);
      expect(json['statusMSG'], 'OK');
      expect(json['lowQualityAudio'], isNotNull);
      expect(json['highQualityAudio'], isNotNull);
    });

    test('serializes null audio formats as null', () {
      final data = HMStreamingData(playable: false, statusMSG: 'err');

      final json = data.toJson();

      expect(json['playable'], false);
      expect(json['statusMSG'], 'err');
      expect(json['lowQualityAudio'], isNull);
      expect(json['highQualityAudio'], isNull);
    });
  });
}
