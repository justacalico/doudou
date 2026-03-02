class JellyfinServer {
  final String serverUrl;
  final String? apiKey;
  final String? userId;
  final String? accessToken;
  final String? username;
  final String? password;

  JellyfinServer({
    required this.serverUrl,
    this.apiKey,
    this.userId,
    this.accessToken,
    this.username,
    this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'apiKey': apiKey,
      'userId': userId,
      'accessToken': accessToken,
      'username': username,
      'password': password,
    };
  }

  factory JellyfinServer.fromJson(Map<String, dynamic> json) {
    return JellyfinServer(
      serverUrl: json['serverUrl'] as String,
      apiKey: json['apiKey'] as String?,
      userId: json['userId'] as String?,
      accessToken: json['accessToken'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }
}

class Album {
  final String id;
  final String name;
  final String? artistName;
  final String? imageUrl;
  final int? year;
  final DateTime? dateCreated;
  final bool isFavorite;

  Album({
    required this.id,
    required this.name,
    this.artistName,
    this.imageUrl,
    this.year,
    this.dateCreated,
    this.isFavorite = false,
  });

  Album copyWith({
    String? id,
    String? name,
    String? artistName,
    String? imageUrl,
    int? year,
    DateTime? dateCreated,
    bool? isFavorite,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artistName: artistName ?? this.artistName,
      imageUrl: imageUrl ?? this.imageUrl,
      year: year ?? this.year,
      dateCreated: dateCreated ?? this.dateCreated,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class Track {
  final String id;
  final String name;
  final String? albumName;
  final String? artistName;
  final String? albumId;
  final String? playlistItemId;
  final int? duration; // in seconds
  final int? trackNumber;
  final String? imageUrl;
  final bool isFavorite;
  final int? playCount;

  Track({
    required this.id,
    required this.name,
    this.albumName,
    this.artistName,
    this.albumId,
    this.playlistItemId,
    this.duration,
    this.trackNumber,
    this.imageUrl,
    this.isFavorite = false,
    this.playCount,
  });
}

class Artist {
  final String id;
  final String name;
  final String? imageUrl;

  Artist({
    required this.id,
    required this.name,
    this.imageUrl,
  });
}

class Playlist {
  final String id;
  final String name;
  final String? imageUrl;
  final int trackCount;

  Playlist({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.trackCount,
  });
}

class Library {
  final String id;
  final String name;
  final String collectionType;
  final String? imageUrl;

  Library({
    required this.id,
    required this.name,
    required this.collectionType,
    this.imageUrl,
  });
}

class SearchResults {
  final List<Album> albums;
  final List<Artist> artists;
  final List<Track> tracks;

  const SearchResults({
    this.albums = const [],
    this.artists = const [],
    this.tracks = const [],
  });
}
