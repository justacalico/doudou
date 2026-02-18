import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Pure Dart InnerTube API client for extracting YouTube Music audio streams.
///
/// Talks directly to YouTube's private InnerTube API, the same backend that
/// official YouTube/YouTube Music clients use. Multiple client identities are
/// tried in order; ANDROID returns direct stream URLs without login for most
/// music content.
///
/// References: InnerTune (z-huang/InnerTune) innertube module; Harmony-Music
/// (anandnet/Harmony-Music) lib/services/constant.dart for baseUrl/youtubei/v1 and API key.
class InnerTubeClient {
  InnerTubeClient({this.cookie, this.visitorData});

  /// Optional cookie string for authenticated requests (SAPISID-based auth).
  String? cookie;

  /// Visitor data token included in every request context.
  String? visitorData;

  static const String _youtubeBase = 'https://www.youtube.com/youtubei/v1';
  static const String _musicBase = 'https://music.youtube.com/youtubei/v1';

  // ---------------------------------------------------------------------------
  // Client definitions – order matters: ANDROID first (works without auth for
  // YouTube Music tracks), then authenticated music clients, then IOS fallback.
  // ---------------------------------------------------------------------------

  static const List<_ClientConfig> _clients = [
    // ANDROID on www.youtube.com – works for music tracks without login
    _ClientConfig(
      name: 'ANDROID',
      version: '19.29.37',
      apiKey: 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w',
      userAgent: 'com.google.android.youtube/19.29.37 (Linux; U; Android 14) gzip',
      baseUrl: _youtubeBase,
      androidSdkVersion: 34,
      osName: 'Android',
      osVersion: '14',
      platform: 'MOBILE',
    ),
    // IOS on www.youtube.com – good fallback, may need login for music-only
    _ClientConfig(
      name: 'IOS',
      version: '19.29.1',
      apiKey: 'AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc',
      userAgent: 'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)',
      baseUrl: _youtubeBase,
      osName: 'iOS',
      osVersion: '17.5.1.21F90',
      platform: 'MOBILE',
      deviceModel: 'iPhone16,2',
    ),
    // ANDROID_MUSIC on music.youtube.com – needs cookies for auth
    _ClientConfig(
      name: 'ANDROID_MUSIC',
      version: '7.27.52',
      apiKey: 'AIzaSyAOghZGza2MQSZkY_zfZ370N-PUdXEo8AI',
      userAgent: 'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14) gzip',
      baseUrl: _musicBase,
      androidSdkVersion: 34,
      osName: 'Android',
      osVersion: '14',
      platform: 'MOBILE',
      needsCookie: true,
    ),
    // IOS_MUSIC on music.youtube.com – needs cookies for auth
    _ClientConfig(
      name: 'IOS_MUSIC',
      version: '7.27.0',
      apiKey: 'AIzaSyBAETezhkwP0ZWA02RsqT1zu78Fpt0bC_s',
      userAgent: 'com.google.ios.youtubemusic/7.27.0 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
      baseUrl: _musicBase,
      osName: 'iOS',
      osVersion: '18.1.0.22B83',
      platform: 'MOBILE',
      deviceModel: 'iPhone16,2',
      needsCookie: true,
    ),
    // WEB_REMIX on music.youtube.com – needs cookies for auth
    _ClientConfig(
      name: 'WEB_REMIX',
      version: '1.20241106.01.00',
      apiKey: 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      baseUrl: _musicBase,
      referer: 'https://music.youtube.com/',
      platform: 'WEB',
      needsCookie: true,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Resolve audio stream URLs for [videoId].
  ///
  /// Returns a list of playable audio URLs sorted by descending bitrate.
  /// Tries multiple InnerTube client identities until one succeeds.
  Future<List<InnerTubeStreamResult>> getStreamUrls(String videoId) async {
    for (final client in _clients) {
      if (client.needsCookie && (cookie == null || cookie!.isEmpty)) {
        continue;
      }
      try {
        final results = await _playerRequest(client, videoId);
        if (results.isNotEmpty) {
          if (kDebugMode) {
            print('[InnerTube] SUCCESS client=${client.name} '
                'streams=${results.length} for $videoId');
          }
          return results;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[InnerTube] client=${client.name} FAILED for $videoId: $e');
        }
      }
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<List<InnerTubeStreamResult>> _playerRequest(
    _ClientConfig client,
    String videoId,
  ) async {
    final uri = Uri.parse('${client.baseUrl}/player').replace(
      queryParameters: {'key': client.apiKey, 'prettyPrint': 'false'},
    );

    final contextClient = <String, dynamic>{
      'clientName': client.name,
      'clientVersion': client.version,
      'hl': 'en',
      'gl': 'US',
    };

    if (visitorData != null && visitorData!.isNotEmpty) {
      contextClient['visitorData'] = visitorData;
    }
    if (client.androidSdkVersion != null) {
      contextClient['androidSdkVersion'] = client.androidSdkVersion;
    }
    if (client.osName != null) {
      contextClient['osName'] = client.osName;
    }
    if (client.osVersion != null) {
      contextClient['osVersion'] = client.osVersion;
    }
    if (client.platform != null) {
      contextClient['platform'] = client.platform;
    }
    if (client.deviceModel != null) {
      contextClient['deviceModel'] = client.deviceModel;
    }

    final body = <String, dynamic>{
      'context': {
        'client': contextClient,
      },
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': client.userAgent,
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': client.name,
      'X-YouTube-Client-Version': client.version,
      'x-origin': 'https://music.youtube.com',
    };

    if (client.referer != null) {
      headers['Referer'] = client.referer!;
    }

    if (cookie != null && cookie!.isNotEmpty && client.needsCookie) {
      headers['cookie'] = cookie!;
      final sapisid = _extractSAPISID(cookie!);
      if (sapisid != null) {
        final origin = client.baseUrl.startsWith(_musicBase)
            ? 'https://music.youtube.com'
            : 'https://www.youtube.com';
        final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final hash = _sha1Hash('$ts $sapisid $origin');
        headers['Authorization'] = 'SAPISIDHASH ${ts}_$hash';
      }
    }

    final httpClient = http.Client();
    try {
      final response = await httpClient
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('[InnerTube] ${client.name}: HTTP ${response.statusCode}');
        }
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final playabilityStatus =
          json['playabilityStatus'] as Map<String, dynamic>?;
      final status = playabilityStatus?['status'] as String?;
      if (status != null && status != 'OK') {
        if (kDebugMode) {
          final reason = playabilityStatus?['reason'] as String? ?? 'unknown';
          print('[InnerTube] ${client.name}: playability=$status reason=$reason');
        }
        return [];
      }

      final streamingData =
          json['streamingData'] as Map<String, dynamic>?;
      if (streamingData == null) return [];

      final results = <InnerTubeStreamResult>[];

      final adaptiveFormats =
          streamingData['adaptiveFormats'] as List<dynamic>? ?? [];
      for (final fmt in adaptiveFormats) {
        if (fmt is! Map<String, dynamic>) continue;
        final url = fmt['url'] as String?;
        if (url == null || url.isEmpty) continue;

        final mimeType = fmt['mimeType'] as String? ?? '';
        final isAudio = mimeType.startsWith('audio/');
        if (!isAudio) continue;

        final bitrate = fmt['bitrate'] as int? ?? 0;
        final quality = fmt['audioQuality'] as String? ?? '';
        final codec = _extractCodec(mimeType);
        final contentLength =
            int.tryParse(fmt['contentLength']?.toString() ?? '') ?? 0;
        final sampleRate =
            int.tryParse(fmt['audioSampleRate']?.toString() ?? '') ?? 0;
        final channels = fmt['audioChannels'] as int? ?? 0;
        final loudnessDb = (fmt['loudnessDb'] as num?)?.toDouble();
        final approxDurationMs =
            int.tryParse(fmt['approxDurationMs']?.toString() ?? '') ?? 0;

        results.add(InnerTubeStreamResult(
          url: url,
          mimeType: mimeType,
          codec: codec,
          bitrate: bitrate,
          quality: quality,
          contentLength: contentLength,
          sampleRate: sampleRate,
          channels: channels,
          loudnessDb: loudnessDb,
          approxDurationMs: approxDurationMs,
          clientName: client.name,
        ));
      }

      if (results.isEmpty) {
        final hlsUrl = streamingData['hlsManifestUrl'] as String?;
        if (hlsUrl != null && hlsUrl.isNotEmpty) {
          results.add(InnerTubeStreamResult(
            url: hlsUrl,
            mimeType: 'application/x-mpegURL',
            codec: 'hls',
            bitrate: 0,
            quality: 'HLS',
            contentLength: 0,
            sampleRate: 0,
            channels: 0,
            clientName: client.name,
          ));
        }
      }

      // Prefer opus (smaller, higher quality at same bitrate), then sort by bitrate
      results.sort((a, b) {
        if (a.codec.contains('opus') && !b.codec.contains('opus')) return -1;
        if (!a.codec.contains('opus') && b.codec.contains('opus')) return 1;
        return b.bitrate.compareTo(a.bitrate);
      });

      return results;
    } finally {
      httpClient.close();
    }
  }

  static String _extractCodec(String mimeType) {
    final match = RegExp(r'codecs="([^"]+)"').firstMatch(mimeType);
    return match?.group(1) ?? '';
  }

  static String? _extractSAPISID(String cookies) {
    final match = RegExp(r'SAPISID=([^;]+)').firstMatch(cookies);
    return match?.group(1);
  }

  static String _sha1Hash(String input) {
    try {
      final bytes = utf8.encode(input);
      return _simpleSha1(bytes);
    } catch (_) {
      return '';
    }
  }

  /// Minimal SHA-1 (pure Dart, zero deps).
  static String _simpleSha1(List<int> data) {
    int h0 = 0x67452301;
    int h1 = 0xEFCDAB89;
    int h2 = 0x98BADCFE;
    int h3 = 0x10325476;
    int h4 = 0xC3D2E1F0;

    final bitLen = data.length * 8;
    final padded = List<int>.from(data)..add(0x80);
    while (padded.length % 64 != 56) {
      padded.add(0);
    }
    padded.addAll([
      (bitLen >> 56) & 0xff, (bitLen >> 48) & 0xff,
      (bitLen >> 40) & 0xff, (bitLen >> 32) & 0xff,
      (bitLen >> 24) & 0xff, (bitLen >> 16) & 0xff,
      (bitLen >> 8) & 0xff, bitLen & 0xff,
    ]);

    int rotl(int n, int c) => ((n << c) | (n >> (32 - c))) & 0xFFFFFFFF;

    for (var i = 0; i < padded.length; i += 64) {
      final w = List<int>.filled(80, 0);
      for (var j = 0; j < 16; j++) {
        w[j] = (padded[i + j * 4] << 24) |
            (padded[i + j * 4 + 1] << 16) |
            (padded[i + j * 4 + 2] << 8) |
            padded[i + j * 4 + 3];
      }
      for (var j = 16; j < 80; j++) {
        w[j] = rotl(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1);
      }

      var a = h0, b = h1, c = h2, d = h3, e = h4;
      for (var j = 0; j < 80; j++) {
        int f, k;
        if (j < 20) {
          f = (b & c) | (~b & d); k = 0x5A827999;
        } else if (j < 40) {
          f = b ^ c ^ d; k = 0x6ED9EBA1;
        } else if (j < 60) {
          f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC;
        } else {
          f = b ^ c ^ d; k = 0xCA62C1D6;
        }
        f &= 0xFFFFFFFF;
        final temp = (rotl(a, 5) + f + e + k + w[j]) & 0xFFFFFFFF;
        e = d; d = c; c = rotl(b, 30); b = a; a = temp;
      }

      h0 = (h0 + a) & 0xFFFFFFFF; h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF; h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
    }

    String hex(int v) => v.toRadixString(16).padLeft(8, '0');
    return '${hex(h0)}${hex(h1)}${hex(h2)}${hex(h3)}${hex(h4)}';
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _ClientConfig {
  const _ClientConfig({
    required this.name,
    required this.version,
    required this.apiKey,
    required this.userAgent,
    required this.baseUrl,
    this.referer,
    this.androidSdkVersion,
    this.osName,
    this.osVersion,
    this.platform,
    this.deviceModel,
    this.needsCookie = false,
  });

  final String name;
  final String version;
  final String apiKey;
  final String userAgent;
  final String baseUrl;
  final String? referer;
  final int? androidSdkVersion;
  final String? osName;
  final String? osVersion;
  final String? platform;
  final String? deviceModel;
  final bool needsCookie;
}

class InnerTubeStreamResult {
  const InnerTubeStreamResult({
    required this.url,
    required this.mimeType,
    required this.codec,
    required this.bitrate,
    required this.quality,
    required this.contentLength,
    required this.sampleRate,
    required this.channels,
    required this.clientName,
    this.loudnessDb,
    this.approxDurationMs = 0,
  });

  final String url;
  final String mimeType;
  final String codec;
  final int bitrate;
  final String quality;
  final int contentLength;
  final int sampleRate;
  final int channels;
  final double? loudnessDb;
  final int approxDurationMs;
  final String clientName;
}
