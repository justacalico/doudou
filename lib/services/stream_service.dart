import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();

    try {
      final res = await yt.videos.streamsClient.getManifest(videoId);
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
      if (e is SocketException) {
        return StreamProvider(
          playable: false,
          statusMSG: "networkError: ${e.message}",
        );
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
          playable: false,
          statusMSG:
              "VideoUnplayableException: ${e.message}",
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
