// Ported from Harmony-Music (anandnet/Harmony-Music) lib/services/stream_service.dart
// Reference: https://github.com/anandnet/Harmony-Music/blob/main/lib/services/stream_service.dart
// This is Harmony's StreamProvider class - their working YouTube streaming implementation.

import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Harmony-Music StreamProvider: fetches YouTube audio streams using youtube_explode_dart.
/// Ported from Harmony-Music lib/services/stream_service.dart.
class HarmonyStreamProvider {
  final bool playable;
  final List<HarmonyAudio>? audioFormats;
  final String statusMSG;

  HarmonyStreamProvider({
    required this.playable,
    this.audioFormats,
    this.statusMSG = "",
  });

  /// Fetch stream info for a video ID. 1:1 port of Harmony-Music stream_service.dart StreamProvider.fetch(videoId).
  /// Uses youtube_explode_dart 2.x: streamsClient.getManifest(videoId), audioOnly, highestQualityAudio (itag 251/140).
  static Future<HarmonyStreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();

    try {
      final res = await yt.videos.streamsClient.getManifest(videoId);
      final audio = res.audioOnly;
      return HarmonyStreamProvider(
        playable: true,
        statusMSG: "OK",
        audioFormats: audio
            .map((e) => HarmonyAudio(
                  itag: e.tag,
                  audioCodec:
                      e.audioCodec.contains('mp') ? HarmonyCodec.mp4a : HarmonyCodec.opus,
                  bitrate: e.bitrate.bitsPerSecond,
                  duration: e.duration ?? 0,
                  loudnessDb: e.loudnessDb,
                  url: e.url.toString(),
                  size: e.size.totalBytes,
                ))
            .toList(),
      );
    } catch (e) {
      if (e is SocketException) {
        return HarmonyStreamProvider(
          playable: false,
          statusMSG: "networkError",
        );
      } else if (e is VideoUnplayableException) {
        return HarmonyStreamProvider(
          playable: false,
          statusMSG: e.reason ?? "Song is unplayable",
        );
      } else if (e is VideoRequiresPurchaseException) {
        return HarmonyStreamProvider(
          playable: false,
          statusMSG: "Song requires purchase",
        );
      } else if (e is VideoUnavailableException) {
        return HarmonyStreamProvider(
          playable: false,
          statusMSG: "Song is unavailable",
        );
      } else if (e is YoutubeExplodeException) {
        return HarmonyStreamProvider(
          playable: false,
          statusMSG: e.message,
        );
      } else {
        return HarmonyStreamProvider(
          playable: false,
          statusMSG: "Unknown error occurred",
        );
      }
    }
  }

  /// Highest quality audio (Harmony's highestQualityAudio: itag 251 or 140).
  /// Reference: Harmony-Music lib/services/stream_service.dart – highestQualityAudio getter.
  HarmonyAudio? get highestQualityAudio =>
      audioFormats?.lastWhere(
        (item) => item.itag == 251 || item.itag == 140,
        orElse: () => audioFormats!.first,
      );

  /// Highest bitrate MP4A audio (itag 140 or 139).
  /// Reference: Harmony-Music lib/services/stream_service.dart – highestBitrateMp4aAudio.
  HarmonyAudio? get highestBitrateMp4aAudio =>
      audioFormats?.lastWhere(
        (item) => item.itag == 140 || item.itag == 139,
        orElse: () => audioFormats!.first,
      );

  /// Highest bitrate Opus audio (itag 251 or 250).
  /// Reference: Harmony-Music lib/services/stream_service.dart – highestBitrateOpusAudio.
  HarmonyAudio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere(
        (item) => item.itag == 251 || item.itag == 250,
        orElse: () => audioFormats!.first,
      );

  /// Low quality audio (itag 249 or 139).
  /// Reference: Harmony-Music lib/services/stream_service.dart – lowQualityAudio.
  HarmonyAudio? get lowQualityAudio =>
      audioFormats?.lastWhere(
        (item) => item.itag == 249 || item.itag == 139,
        orElse: () => audioFormats!.first,
      );

  /// Get streaming data map (Harmony format).
  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson(),
    };
  }
}

/// Harmony-Music Audio class: represents an audio stream format.
/// Ported from Harmony-Music lib/services/stream_service.dart – Audio class.
class HarmonyAudio {
  final int itag;
  final HarmonyCodec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;

  HarmonyAudio({
    required this.itag,
    required this.audioCodec,
    required this.bitrate,
    required this.duration,
    required this.loudnessDb,
    required this.url,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size,
      };

  factory HarmonyAudio.fromJson(Map<String, dynamic> json) => HarmonyAudio(
        audioCodec: (json["audioCodec"] as String).contains("mp4a")
            ? HarmonyCodec.mp4a
            : HarmonyCodec.opus,
        itag: json['itag'] as int,
        duration: json["approxDurationMs"] as int? ?? 0,
        bitrate: json["bitrate"] as int? ?? 0,
        loudnessDb: (json['loudnessDb'] as num?)?.toDouble() ?? 0.0,
        url: json['url'] as String,
        size: json["size"] as int? ?? 0,
      );
}

/// Harmony-Music Codec enum.
/// Ported from Harmony-Music lib/services/stream_service.dart – Codec enum.
enum HarmonyCodec { mp4a, opus }
