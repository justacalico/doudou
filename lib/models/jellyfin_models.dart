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
      serverUrl: json['serverUrl'],
      apiKey: json['apiKey'],
      userId: json['userId'],
      accessToken: json['accessToken'],
      username: json['username'],
      password: json['password'],
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

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['Id'],
      name: json['Name'],
      artistName: json['AlbumArtist'],
      imageUrl:
          json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : null,
      year: json['ProductionYear'],
      dateCreated: json['DateCreated'] != null
          ? DateTime.tryParse(json['DateCreated'])
          : null,
      isFavorite: json['UserData']?['IsFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'AlbumArtist': artistName,
      'ImageTags': imageUrl != null ? {'Primary': imageUrl} : null,
      'ProductionYear': year,
      'DateCreated': dateCreated?.toIso8601String(),
      'UserData': {'IsFavorite': isFavorite},
    };
  }

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
  /// Optional artist ID (e.g. YouTube Music browseId) for navigation when not in library.
  final String? artistId;
  final String? playlistItemId;
  final int? duration; // in milliseconds
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
    this.artistId,
    this.playlistItemId,
    this.duration,
    this.trackNumber,
    this.imageUrl,
    this.isFavorite = false,
    this.playCount,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['Id'],
      name: json['Name'],
      albumName: json['Album'],
      artistName: json['Artists']?.join(', '),
      albumId: json['AlbumId'],
      artistId: json['ArtistId'],
      playlistItemId: json['PlaylistItemId'] ?? json['PlaylistItemID'],
      duration: json['RunTimeTicks'] != null
          ? (json['RunTimeTicks'] / 10000)
                .round() // Convert from ticks to milliseconds
          : null,
      trackNumber: json['IndexNumber'],
      imageUrl:
          json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : json['AlbumId'], // Fallback to album image
      isFavorite: json['UserData']?['IsFavorite'] ?? false,
      playCount: json['UserData']?['PlayCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Album': albumName,
      'Artists': artistName?.split(', '),
      'AlbumId': albumId,
      'ArtistId': artistId,
      'PlaylistItemId': playlistItemId,
      'RunTimeTicks': duration != null ? duration! * 10000 : null,
      'IndexNumber': trackNumber,
      'ImageTags': imageUrl != null ? {'Primary': imageUrl} : null,
      'UserData': {'IsFavorite': isFavorite, 'PlayCount': playCount},
    };
  }
}

class Artist {
  final String id;
  final String name;
  final String? imageUrl;

  Artist({required this.id, required this.name, this.imageUrl});

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['Id'],
      name: json['Name'],
      imageUrl:
          json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'ImageTags': imageUrl != null ? {'Primary': imageUrl} : null,
    };
  }
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

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['Id'],
      name: json['Name'],
      imageUrl:
          json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : null,
      trackCount: json['ChildCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'ImageTags': imageUrl != null ? {'Primary': imageUrl} : null,
      'ChildCount': trackCount,
    };
  }
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

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['Id'],
      name: json['Name'],
      collectionType: json['CollectionType'] ?? 'unknown',
      imageUrl:
          json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'CollectionType': collectionType,
      'ImageTags': imageUrl != null ? {'Primary': imageUrl} : null,
    };
  }
}

/// One section from YouTube Music home (e.g. "Quick picks", "Recommendations").
/// Used when server is YouTube Music to show personalized home content.
class YTMHomeSection {
  final String title;
  final List<Album> albums;
  final List<Playlist> playlists;
  final List<Track> tracks;

  const YTMHomeSection({
    required this.title,
    this.albums = const [],
    this.playlists = const [],
    this.tracks = const [],
  });

  bool get isEmpty =>
      albums.isEmpty && playlists.isEmpty && tracks.isEmpty;
}
