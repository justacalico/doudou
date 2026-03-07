import '../models/thumbnail.dart';

class Artist {
  Artist({
    required this.name,
    required this.browseId,
    this.radioId,
    required this.thumbnailUrl,
    this.subscribers,
  });
  final String name;
  final String browseId;
  final String? radioId;
  final String? subscribers;
  final String thumbnailUrl;
  factory Artist.fromJson(dynamic json) {
    final map = json is Map ? json : const <String, dynamic>{};
    final subscribersRaw = map['subscribers'];
    final subscribers = subscribersRaw == null
        ? ''
        : subscribersRaw is String
            ? subscribersRaw
            : (subscribersRaw is Map
                ? subscribersRaw['text']?.toString() ?? ''
                : '');

    final rawThumbs = map["thumbnails"];
    String thumbUrl = '';
    if (rawThumbs is List && rawThumbs.isNotEmpty && rawThumbs.first is Map) {
      thumbUrl = (rawThumbs.first['url']?.toString() ?? '').trim();
    }

    return Artist(
      name: map['artist']?.toString() ??
          map['name']?.toString() ??
          map['title']?.toString() ??
          '',
      browseId: map['browseId']?.toString() ?? '',
      radioId: map['radioId']?.toString(),
      subscribers: subscribers,
      thumbnailUrl: thumbUrl.isEmpty ? '' : Thumbnail(thumbUrl).high,
    );
  }

  Map<String, dynamic> toJson() => {
        'artist': name,
        'browseId': browseId,
        'radioId': radioId,
        'subscribers': subscribers,
        'thumbnails': [
          {'url': thumbnailUrl}
        ]
      };
}

class ArtistContent {
  ArtistContent(this.content, {this.title = "Artists"});
  final List<Artist> content;
  final String title;
}
