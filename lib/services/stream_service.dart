import 'dart:async';
import 'dart:convert' show json;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../utils/helper.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  // The default adapter drops pooled connections after 3s of idleness, so
  // every play more than a few seconds apart paid a fresh TCP+TLS handshake
  // to the InnerTube host inside the tap-to-play path. Keeping connections
  // alive for minutes lets back-to-back song changes reuse the session.
  static final Dio _innertubeDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ))
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () =>
          HttpClient()..idleTimeout = const Duration(minutes: 5),
    );

  /// InnerTube clients tried in order when resolving a stream, matching how
  /// Metrolist rotates clients. All of them return ready-to-use stream urls
  /// without signature deciphering, so a client that produces nothing usable
  /// only costs one extra player request before the manifest pipeline
  /// fallback kicks in.
  static final List<YoutubeApiClient> innertubePlayerClients = [
    YoutubeApiClient.visionos,
    YoutubeApiClient.androidVr,
    YoutubeApiClient.ios,
  ];

  static String _normalizeId(String videoId) =>
      videoId.startsWith("MPED") ? videoId.substring(4) : videoId;

  /// Opens a connection to the InnerTube host ahead of playback so the first
  /// player request after launch doesn't pay the handshake inside a play
  /// action. Fire-and-forget: failures are irrelevant, the next real request
  /// retries anyway.
  static void warmConnections() {
    unawaited(_innertubeDio
        .get<void>('https://www.youtube.com/generate_204')
        .then((_) {}, onError: (_) {}));
  }

  /// Resolves stream urls with a single InnerTube `player` request per
  /// client, trying [clients] in order until one produces usable audio
  /// formats.
  ///
  /// Returns null when every client's response lacks directly usable audio
  /// formats (ciphered signatures, live streams, non-OK playability), in
  /// which case the caller should fall back to the full manifest pipeline.
  /// A non-playable result is only returned when the manifest pipeline would
  /// hit the same wall, e.g. when there is no connectivity.
  static Future<StreamProvider?> fetchViaInnertube(String videoId,
      {Dio? dio, List<YoutubeApiClient>? clients}) async {
    final resolvedDio = dio ?? _innertubeDio;
    for (final client in clients ?? innertubePlayerClients) {
      final provider = await _fetchViaClient(videoId, client, resolvedDio);
      // A playable response is used right away and a network failure hits
      // every client identically, so only null (nothing usable from this
      // client) advances to the next one.
      if (provider != null) return provider;
    }
    return null;
  }

  static Future<StreamProvider?> _fetchViaClient(
      String videoId, YoutubeApiClient client, Dio dio) async {
    final clientContext = client.payload['context']['client'] as Map;
    try {
      final response = await dio.post(
        client.apiUrl,
        data: {...client.payload, 'videoId': _normalizeId(videoId)},
        options: Options(headers: {
          if (clientContext['userAgent'] != null)
            'User-Agent': clientContext['userAgent'],
          'X-Youtube-Client-Name': clientContext['clientName'],
          'X-Youtube-Client-Version': clientContext['clientVersion'],
          'Origin': 'https://www.youtube.com',
          'Sec-Fetch-Mode': 'navigate',
          'Content-Type': 'application/json',
          ...client.headers,
        }),
      );
      final body = response.data;
      return parseInnertubeResponse(body is String ? json.decode(body) : body);
    } on DioException catch (e) {
      if (e.error is SocketException ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return StreamProvider(
            playable: false, statusMSG: "networkError: ${e.message}");
      }
      logPlaybackDebugError(
          'StreamProvider.fetchViaInnertube($videoId, '
          '${clientContext['clientName']})',
          e);
      return null;
    } catch (e) {
      logPlaybackDebugError(
          'StreamProvider.fetchViaInnertube($videoId, '
          '${clientContext['clientName']})',
          e);
      return null;
    }
  }

  /// Extracts audio formats from an InnerTube `player` response. Only formats
  /// carrying a ready-to-use url are usable; ciphered entries are left for
  /// the manifest pipeline to decipher.
  static StreamProvider? parseInnertubeResponse(dynamic data) {
    if (data is! Map) return null;
    final playabilityStatus = data['playabilityStatus'];
    if (playabilityStatus is! Map ||
        playabilityStatus['status']?.toString().toUpperCase() != 'OK') {
      return null;
    }
    final streamingData = data['streamingData'];
    if (streamingData is! Map) return null;
    final formats = <dynamic>[
      if (streamingData['formats'] is List) ...streamingData['formats'],
      if (streamingData['adaptiveFormats'] is List)
        ...streamingData['adaptiveFormats'],
    ];
    final audioFormats = <Audio>[];
    for (final format in formats) {
      if (format is! Map) continue;
      final url = format['url'];
      final mimeType = format['mimeType']?.toString() ?? '';
      if (!mimeType.startsWith('audio/') || url is! String || url.isEmpty) {
        continue;
      }
      audioFormats.add(Audio(
          itag: format['itag'] is num
              ? (format['itag'] as num).toInt()
              : int.tryParse('${format['itag']}') ?? 0,
          audioCodec: mimeType.contains('mp4') ? Codec.mp4a : Codec.opus,
          bitrate: (format['bitrate'] as num?)?.toInt() ?? 0,
          duration: int.tryParse('${format['approxDurationMs']}') ?? 0,
          loudnessDb: (format['loudnessDb'] as num?)?.toDouble() ?? 0.0,
          url: url,
          size: int.tryParse('${format['contentLength']}') ?? 0));
    }
    if (audioFormats.isEmpty) return null;
    return StreamProvider(
        playable: true, statusMSG: 'OK', audioFormats: audioFormats);
  }

  static Future<StreamProvider> fetch(String videoId,
      {bool useInnertube = true}) async {
    if (useInnertube) {
      final provider = await fetchViaInnertube(videoId);
      if (provider != null) return provider;
    }
    final yt = YoutubeExplode();

    try {
      final res =
          await yt.videos.streamsClient.getManifest(_normalizeId(videoId));
      final audio = res.audioOnly;
      return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: audio
              .map((e) => Audio(
                  itag: e.tag,
                  audioCodec:
                      e.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
                  bitrate: e.bitrate.bitsPerSecond,
                  duration: 0,
                  loudnessDb: 0.0,
                  url: e.url.toString(),
                  size: e.size.totalBytes))
              .toList());
    } catch (e) {
      logPlaybackDebugError('StreamProvider.fetch($videoId)', e);
      if (e is SocketException) {
        return StreamProvider(
          playable: false,
          statusMSG: "networkError: ${e.message}",
        );
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
          playable: false,
          statusMSG: "VideoUnplayableException: ${e.message}",
        );
      } else if (e is VideoRequiresPurchaseException) {
        return StreamProvider(
          playable: false,
          statusMSG: "VideoRequiresPurchaseException: Song requires purchase",
        );
      } else if (e is VideoUnavailableException) {
        return StreamProvider(
          playable: false,
          statusMSG: "VideoUnavailableException: Song is unavailable",
        );
      } else if (e is YoutubeExplodeException) {
        return StreamProvider(
          playable: false,
          statusMSG: "YoutubeExplodeException: ${e.message}",
        );
      } else {
        return StreamProvider(
          playable: false,
          statusMSG: "${e.runtimeType}: $e",
        );
      }
    }
  }

  Audio? get highestQualityAudio =>
      (Platform.isIOS || Platform.isMacOS
          ? highestBitrateMp4aAudio
          : audioFormats?.lastWhere(
              (item) => item.itag == 251 || item.itag == 140,
              orElse: () => audioFormats!.first)) ??
      audioFormats?.first;

  Audio? get highestBitrateMp4aAudio =>
      audioFormats?.lastWhere((item) => item.itag == 140 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 250,
          orElse: () => audioFormats!.first);

  Audio? get lowQualityAudio =>
      (Platform.isIOS || Platform.isMacOS
          ? audioFormats?.lastWhere(
              (item) => item.itag == 139 || item.itag == 140,
              orElse: () => highestBitrateMp4aAudio ?? audioFormats!.first)
          : audioFormats?.lastWhere(
              (item) => item.itag == 249 || item.itag == 139,
              orElse: () => audioFormats!.first)) ??
      audioFormats?.first;

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson()
    };
  }
}

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.loudnessDb,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'])?.toDouble() ?? 0.0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }
