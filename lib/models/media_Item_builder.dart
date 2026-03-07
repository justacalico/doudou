// ignore_for_file: file_names

import 'package:audio_service/audio_service.dart';
import '../models/thumbnail.dart';

class MediaItemBuilder {
  static MediaItem fromJson(dynamic json, {String? url}) {
    final map = json is Map ? json : const <String, dynamic>{};
    final artistName = _parseArtistNames(map['artists']);

    Map? album;
    final rawAlbum = map['album'];
    if (rawAlbum is Map && rawAlbum['id'] != null) {
      album = rawAlbum;
    }
    final thumbnailUrl = _firstThumbnailUrl(map['thumbnails']);
    final duration = _parseDuration(
      secondsRaw: map['duration'],
      lengthRaw: map['length'],
    );
    final mediaId = map["videoId"]?.toString() ?? "";
    final title = map["title"]?.toString() ?? "";
    final backendType = map['backendType']?.toString();
    final parsedUrl = map['url']?.toString().trim().isNotEmpty == true
        ? map['url'].toString()
        : null;
    final resolvedUrl = backendType == 'plex' ? null : (parsedUrl ?? url);

    Uri artUri;
    try {
      artUri = Uri.parse(
        thumbnailUrl.isEmpty ? "" : Thumbnail(thumbnailUrl).high,
      );
    } catch (_) {
      artUri = Uri.parse('');
    }

    return MediaItem(
        id: mediaId,
        title: title,
        duration: duration,
        album: album != null ? album['name'] : null,
        artist: artistName,
        artUri: artUri,
        extras: {
          'url': resolvedUrl,
          'length': map['length'],
          'album': album,
          'artists': map['artists'],
          'date': map['date'],
          'trackDetails': map['trackDetails'],
          'year': map['year'],
          if (map['backendType'] != null) 'backendType': map['backendType'],
          if (map['serverId'] != null) 'serverId': map['serverId'],
        });
  }

  static String _parseArtistNames(dynamic rawArtists) {
    if (rawArtists is! List) return '';
    final names = rawArtists
        .map((e) => e is Map ? e['name']?.toString().trim() : null)
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
    return names.join(', ');
  }

  static String _firstThumbnailUrl(dynamic rawThumbnails) {
    if (rawThumbnails is! List || rawThumbnails.isEmpty) return '';
    final first = rawThumbnails.first;
    if (first is! Map) return '';
    return first['url']?.toString().trim() ?? '';
  }

  static Duration? _parseDuration({
    required dynamic secondsRaw,
    required dynamic lengthRaw,
  }) {
    if (secondsRaw is num) {
      return Duration(seconds: secondsRaw.round());
    }
    if (secondsRaw is String) {
      final seconds = int.tryParse(secondsRaw.trim());
      if (seconds != null) return Duration(seconds: seconds);
    }
    return toDuration(lengthRaw?.toString());
  }

  static Duration? toDuration(String? time) {
    if (time == null) {
      return null;
    }

    int sec = 0;
    final splitted = time.split(":");
    if (splitted.length == 3) {
      final h = int.tryParse(splitted[0]) ?? 0;
      final m = int.tryParse(splitted[1]) ?? 0;
      final s = int.tryParse(splitted[2]) ?? 0;
      sec += h * 3600 + m * 60 + s;
    } else if (splitted.length == 2) {
      final m = int.tryParse(splitted[0]) ?? 0;
      final s = int.tryParse(splitted[1]) ?? 0;
      sec += m * 60 + s;
    } else if (splitted.length == 1) {
      sec += int.tryParse(splitted[0]) ?? 0;
    }
    return Duration(seconds: sec);
  }

  static Map<String, dynamic> toJson(MediaItem mediaItem) => {
        "videoId": mediaItem.id,
        "title": mediaItem.title,
        'album': mediaItem.extras!['album'],
        'artists': mediaItem.extras!['artists'],
        'length': mediaItem.extras!['length'],
        'duration': mediaItem.duration?.inSeconds,
        'date': mediaItem.extras!['date'],
        'thumbnails': [
          {'url': mediaItem.artUri.toString()}
        ],
        'url': mediaItem.extras!['url'],
        'trackDetails': mediaItem.extras?['trackDetails'],
        'year': mediaItem.extras?['year'],
        if (mediaItem.extras?['backendType'] != null)
          'backendType': mediaItem.extras!['backendType'],
        if (mediaItem.extras?['serverId'] != null)
          'serverId': mediaItem.extras!['serverId'],
      };
}
