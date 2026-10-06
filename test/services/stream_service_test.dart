import 'dart:convert' show jsonEncode, jsonDecode, utf8;
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:doudou/services/stream_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(
      RequestOptions options, Uint8List? requestBody) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    Uint8List? body;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      body = Uint8List.fromList(chunks.expand((c) => c).toList());
    }
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(Map<String, dynamic> payload,
    {void Function(RequestOptions, Uint8List?)? onRequest,
    int probeStatus = 200}) {
  final dio = Dio();
  dio.httpClientAdapter = _FakeAdapter((options, body) async {
    if (options.method != 'POST') {
      // Stream url probe: googlevideo rejects HEAD/whole-file GETs for gated
      // urls, so the probe is a ranged GET that expects 2xx.
      return ResponseBody.fromBytes(const [0], probeStatus);
    }
    onRequest?.call(options, body);
    return ResponseBody.fromString(jsonEncode(payload), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  });
  return dio;
}

Map<String, dynamic> _playerResponse({
  String status = 'OK',
  List<Map<String, dynamic>>? adaptiveFormats,
  List<Map<String, dynamic>>? formats,
}) =>
    {
      'playabilityStatus': {'status': status},
      'streamingData': {
        if (formats != null) 'formats': formats,
        if (adaptiveFormats != null) 'adaptiveFormats': adaptiveFormats,
      },
    };

Map<String, dynamic> _audioFormat({
  int itag = 140,
  String mimeType = 'audio/mp4; codecs="mp4a.40.2"',
  String? url =
      'https://rr1---sn.example.googlevideo.com/videoplayback?c=VISIONOS&expire=2000000000',
  int bitrate = 131072,
  String contentLength = '3456789',
  String approxDurationMs = '213000',
  double loudnessDb = -3.5,
}) =>
    {
      'itag': itag,
      'mimeType': mimeType,
      if (url != null) 'url': url,
      'bitrate': bitrate,
      'contentLength': contentLength,
      'approxDurationMs': approxDurationMs,
      'loudnessDb': loudnessDb,
    };

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

  group('StreamProvider.parseInnertubeResponse', () {
    test('returns playable provider with parsed audio formats', () {
      final provider = StreamProvider.parseInnertubeResponse(_playerResponse(
        adaptiveFormats: [
          _audioFormat(itag: 140),
          _audioFormat(
            itag: 251,
            mimeType: 'audio/webm; codecs="opus"',
            url:
                'https://rr2---sn.example.googlevideo.com/videoplayback?c=VISIONOS&expire=2000000000',
            bitrate: 150000,
          ),
        ],
      ));

      expect(provider, isNotNull);
      expect(provider!.playable, isTrue);
      expect(provider.statusMSG, 'OK');
      expect(provider.audioFormats, hasLength(2));

      final mp4a = provider.audioFormats![0];
      expect(mp4a.itag, 140);
      expect(mp4a.audioCodec, Codec.mp4a);
      expect(mp4a.bitrate, 131072);
      expect(mp4a.duration, 213000);
      expect(mp4a.size, 3456789);
      expect(mp4a.loudnessDb, -3.5);
      expect(mp4a.url, contains('googlevideo.com'));

      final opus = provider.audioFormats![1];
      expect(opus.itag, 251);
      expect(opus.audioCodec, Codec.opus);
    });

    test('skips non-audio and ciphered formats', () {
      final provider = StreamProvider.parseInnertubeResponse(_playerResponse(
        adaptiveFormats: [
          _audioFormat(
            itag: 18,
            mimeType: 'video/mp4; codecs="avc1.42001E"',
          ),
          {
            'itag': 251,
            'mimeType': 'audio/webm; codecs="opus"',
            'signatureCipher': 's=abc&sp=sig&url=https%3A%2F%2Fciphered',
          },
          _audioFormat(itag: 140),
        ],
      ));

      expect(provider, isNotNull);
      expect(provider!.audioFormats, hasLength(1));
      expect(provider.audioFormats!.single.itag, 140);
    });

    test('returns null when every audio format is ciphered', () {
      final provider = StreamProvider.parseInnertubeResponse(_playerResponse(
        adaptiveFormats: [
          {
            'itag': 140,
            'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
            'signatureCipher': 's=abc&sp=sig&url=https%3A%2F%2Fciphered',
          },
        ],
      ));

      expect(provider, isNull);
    });

    test('returns null when playability status is not OK', () {
      for (final status in ['ERROR', 'UNPLAYABLE', 'LOGIN_REQUIRED']) {
        expect(
          StreamProvider.parseInnertubeResponse(_playerResponse(
              status: status, adaptiveFormats: [_audioFormat()])),
          isNull,
          reason: 'status $status should not produce a provider',
        );
      }
    });

    test('returns null when streamingData is missing', () {
      expect(
        StreamProvider.parseInnertubeResponse({
          'playabilityStatus': {'status': 'OK'}
        }),
        isNull,
      );
    });

    test('returns null for non-map payloads', () {
      expect(StreamProvider.parseInnertubeResponse('nope'), isNull);
      expect(StreamProvider.parseInnertubeResponse(null), isNull);
      expect(StreamProvider.parseInnertubeResponse([1, 2]), isNull);
    });
  });

  group('StreamProvider.fetchViaInnertube', () {
    setUp(() => StreamProvider.debugVisitorData = null);
    tearDown(() => StreamProvider.debugVisitorData = null);

    test('posts videoId once and returns playable provider', () async {
      RequestOptions? captured;
      Uint8List? capturedBody;
      final dio = _dioReturning(
        _playerResponse(adaptiveFormats: [_audioFormat()]),
        onRequest: (options, body) {
          captured = options;
          capturedBody = body;
        },
      );

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(provider!.playable, isTrue);
      expect(provider.audioFormats, hasLength(1));
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.uri.path, endsWith('/youtubei/v1/player'));

      final sentBody =
          jsonDecode(utf8.decode(capturedBody!)) as Map<String, dynamic>;
      expect(sentBody['videoId'], 'dQw4w9WgXcQ');
      expect(sentBody['context']['client']['clientName'], 'VISIONOS');
    });

    test('strips the MPED prefix from the video id', () async {
      Uint8List? capturedBody;
      final dio = _dioReturning(
        _playerResponse(adaptiveFormats: [_audioFormat()]),
        onRequest: (options, body) => capturedBody = body,
      );

      await StreamProvider.fetchViaInnertube('MPEDdQw4w9WgXcQ', dio: dio);

      final sentBody =
          jsonDecode(utf8.decode(capturedBody!)) as Map<String, dynamic>;
      expect(sentBody['videoId'], 'dQw4w9WgXcQ');
    });

    test('returns null when response is not playable so caller can fall back',
        () async {
      final dio = _dioReturning(_playerResponse(
          status: 'UNPLAYABLE', adaptiveFormats: [_audioFormat()]));

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNull);
    });

    test('returns networkError result without fallback on connection failure',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('no route to host'),
        );
      });

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(provider!.playable, isFalse);
      expect(provider.statusMSG, startsWith('networkError'));
    });

    test('returns null on non-network http errors so caller can fall back',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        return ResponseBody.fromString('rate limited', 429);
      });

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNull);
    });

    test('tries the next client when the first yields no usable formats',
        () async {
      final requestedClients = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        if (options.method != 'POST') {
          return ResponseBody.fromBytes(const [0], 200);
        }
        final sent = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
        final clientName = sent['context']['client']['clientName'] as String;
        requestedClients.add(clientName);
        final payload = clientName == 'VISIONOS'
            ? _playerResponse(adaptiveFormats: [
                {
                  'itag': 140,
                  'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
                  'signatureCipher': 's=abc&url=https%3A%2F%2Fciphered',
                },
              ])
            : _playerResponse(adaptiveFormats: [_audioFormat()]);
        return ResponseBody.fromString(jsonEncode(payload), 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
      });

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(provider!.playable, isTrue);
      expect(requestedClients, ['VISIONOS', 'ANDROID_VR']);
    });

    test('stops after the first playable response', () async {
      var requests = 0;
      final dio = _dioReturning(
        _playerResponse(adaptiveFormats: [_audioFormat()]),
        onRequest: (options, _) {
          if (options.method == 'POST') requests++;
        },
      );

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(requests, 1);
    });

    test('stops retrying clients on a network failure', () async {
      var requests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        requests++;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('no route to host'),
        );
      });

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(provider!.playable, isFalse);
      expect(provider.statusMSG, startsWith('networkError'));
      expect(requests, 1);
    });

    test('returns null when every client yields nothing usable', () async {
      var requests = 0;
      final dio = _dioReturning(
        _playerResponse(
            status: 'UNPLAYABLE', adaptiveFormats: [_audioFormat()]),
        onRequest: (_, __) => requests++,
      );

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNull);
      expect(requests, StreamProvider.innertubePlayerClients.length);
    });

    test('honours a custom client list', () async {
      final requestedClients = <String>[];
      final dio = _dioReturning(
        _playerResponse(adaptiveFormats: [_audioFormat()]),
        onRequest: (options, body) {
          final sent = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
          requestedClients.add(sent['context']['client']['clientName']);
        },
      );

      final provider = await StreamProvider.fetchViaInnertube(
        'dQw4w9WgXcQ',
        dio: dio,
        clients: [YoutubeApiClient.androidVr],
      );

      expect(provider, isNotNull);
      expect(provider!.playable, isTrue);
      expect(requestedClients, ['ANDROID_VR']);
    });

    test('moves to the next client when the selected url is gated', () async {
      // A client can answer OK yet hand out a url the media host refuses to
      // serve. The tail probe must fail the client over instead of returning
      // a stream that stalls in the player.
      final requestedClients = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        if (options.method != 'POST') {
          final gated = options.uri.host.contains('gated');
          return ResponseBody.fromBytes(const [0], gated ? 403 : 200);
        }
        final sent = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
        final clientName = sent['context']['client']['clientName'] as String;
        requestedClients.add(clientName);
        final url = clientName == 'VISIONOS'
            ? 'https://rr1---sn.gated.googlevideo.com/videoplayback?c=VISIONOS&expire=2000000000'
            : 'https://rr1---sn.open.googlevideo.com/videoplayback?c=ANDROID_VR&expire=2000000000';
        return ResponseBody.fromString(
            jsonEncode(
                _playerResponse(adaptiveFormats: [_audioFormat(url: url)])),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      });

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(provider!.playable, isTrue);
      expect(provider.audioFormats!.first.url, contains('open.googlevideo'));
      expect(requestedClients, ['VISIONOS', 'ANDROID_VR']);
    });

    test('probes the last byte of the selected url', () async {
      String? ranged;
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        if (options.method != 'POST') {
          ranged = options.headers['Range']?.toString();
          return ResponseBody.fromBytes(const [0], 206);
        }
        return ResponseBody.fromString(
            jsonEncode(_playerResponse(adaptiveFormats: [
              _audioFormat(itag: 251, contentLength: '5000000'),
            ])),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      });

      await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(ranged, 'bytes=4999999-4999999');
    });

    test('learns visitorData from responseContext and resends it', () async {
      final bodies = <Map<String, dynamic>>[];
      final visitorHeaders = <String?>[];
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        if (options.method != 'POST') {
          return ResponseBody.fromBytes(const [0], 200);
        }
        final sent = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
        bodies.add(sent);
        visitorHeaders.add(options.headers['X-Goog-Visitor-Id']?.toString());
        final clientName = sent['context']['client']['clientName'] as String;
        // First client: unplayable but still carries a visitor token.
        if (clientName == 'VISIONOS') {
          return ResponseBody.fromString(
              jsonEncode({
                'playabilityStatus': {'status': 'LOGIN_REQUIRED'},
                'responseContext': {'visitorData': 'VD_TEST'},
              }),
              200);
        }
        return ResponseBody.fromString(
            jsonEncode(_playerResponse(adaptiveFormats: [_audioFormat()])),
            200);
      });

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(provider!.playable, isTrue);
      expect(bodies, hasLength(2));
      expect(bodies.first['context']['client'].containsKey('visitorData'),
          isFalse);
      expect(bodies.last['context']['client']['visitorData'], 'VD_TEST');
      expect(visitorHeaders.last, 'VD_TEST');
    });

    test('retries clients once visitorData becomes available', () async {
      // If the token is only learned on the last client, a second pass over
      // the earlier clients with it attached may still succeed.
      final bodies = <Map<String, dynamic>>[];
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        if (options.method != 'POST') {
          return ResponseBody.fromBytes(const [0], 200);
        }
        final sent = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
        bodies.add(sent);
        final clientName = sent['context']['client']['clientName'] as String;
        final hasToken = sent['context']['client'].containsKey('visitorData');
        return ResponseBody.fromString(
            jsonEncode({
              'playabilityStatus': {
                'status': hasToken ? 'OK' : 'LOGIN_REQUIRED'
              },
              // Only the last anonymous client reports a session token.
              if (clientName == 'IOS')
                'responseContext': {'visitorData': 'VD_LATE'},
              if (hasToken)
                'streamingData': {
                  'adaptiveFormats': [_audioFormat()],
                },
            }),
            200);
      });

      final provider =
          await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: dio);

      expect(provider, isNotNull);
      expect(provider!.playable, isTrue);
      // Three anonymous attempts, then a second pass that succeeds.
      expect(bodies, hasLength(4));
      expect(
          bodies
              .take(3)
              .every((b) => !b['context']['client'].containsKey('visitorData')),
          isTrue);
      expect(bodies.last['context']['client']['visitorData'], 'VD_LATE');
      expect(bodies.last['context']['client']['clientName'], 'VISIONOS');
    });
  });

  group('StreamProvider.verifyStreamUrl', () {
    test('accepts a successful ranged response', () async {
      final dio = _dioReturning({});
      expect(await StreamProvider.verifyStreamUrl('https://x.y/z', dio: dio),
          isTrue);
    });

    test('rejects a forbidden ranged response', () async {
      final dio = _dioReturning({}, probeStatus: 403);
      expect(await StreamProvider.verifyStreamUrl('https://x.y/z', dio: dio),
          isFalse);
    });

    test('rejects unreachable urls and empty strings', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('down'),
        );
      });
      expect(await StreamProvider.verifyStreamUrl('https://x.y/z', dio: dio),
          isFalse);
      expect(await StreamProvider.verifyStreamUrl('', dio: dio), isFalse);
    });
  });

  group('StreamProvider.warmConnections', () {
    setUp(() => StreamProvider.debugVisitorData = null);
    tearDown(() => StreamProvider.debugVisitorData = null);

    test('harvests visitorData from the youtube homepage', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options, body) async {
        if (options.method == 'GET' && options.uri.host == 'www.youtube.com') {
          return ResponseBody.fromString(
              '<html>ytcfg.set({"VISITOR_DATA":"VD_HOME"})</html>', 200);
        }
        return ResponseBody.fromBytes(const [0], 200);
      });

      StreamProvider.warmConnections(dio: dio);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The next player request must carry the learned session token.
      Map<String, dynamic>? sent;
      final playerDio = Dio();
      playerDio.httpClientAdapter = _FakeAdapter((options, body) async {
        if (options.method != 'POST') {
          return ResponseBody.fromBytes(const [0], 200);
        }
        sent = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
        return ResponseBody.fromString(
            jsonEncode(_playerResponse(adaptiveFormats: [_audioFormat()])),
            200);
      });

      await StreamProvider.fetchViaInnertube('dQw4w9WgXcQ', dio: playerDio);

      expect(sent?['context']?['client']?['visitorData'], 'VD_HOME');
    });
  });
}
