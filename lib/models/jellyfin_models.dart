class JellyfinServer {
  final String serverUrl;
  final String? apiKey;
  final String? userId;
  final String? accessToken;

  JellyfinServer({
    required this.serverUrl,
    this.apiKey,
    this.userId,
    this.accessToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'apiKey': apiKey,
      'userId': userId,
      'accessToken': accessToken,
    };
  }

  factory JellyfinServer.fromJson(Map<String, dynamic> json) {
    return JellyfinServer(
      serverUrl: json['serverUrl'],
      apiKey: json['apiKey'],
      userId: json['userId'],
      accessToken: json['accessToken'],
    );
  }
}

class Album {
  final String id;
  final String name;
  final String? artistName;
  final String? imageUrl;
  final int? year;

  Album({
    required this.id,
    required this.name,
    this.artistName,
    this.imageUrl,
    this.year,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['Id'],
      name: json['Name'],
      artistName: json['AlbumArtist'],
      imageUrl: json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : null,
      year: json['ProductionYear'],
    );
  }
}

class Track {
  final String id;
  final String name;
  final String? albumName;
  final String? artistName;
  final String? albumId;
  final int? duration; // in milliseconds
  final int? trackNumber;
  final String? imageUrl;
  final bool isFavorite;

  Track({
    required this.id,
    required this.name,
    this.albumName,
    this.artistName,
    this.albumId,
    this.duration,
    this.trackNumber,
    this.imageUrl,
    this.isFavorite = false,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['Id'],
      name: json['Name'],
      albumName: json['Album'],
      artistName: json['Artists']?.join(', '),
      albumId: json['AlbumId'],
      duration: json['RunTimeTicks'] != null
          ? (json['RunTimeTicks'] / 10000).round() // Convert from ticks to milliseconds
          : null,
      trackNumber: json['IndexNumber'],
      imageUrl: json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : json['AlbumId'], // Fallback to album image
      isFavorite: json['UserData']?['IsFavorite'] ?? false,
    );
  }
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

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['Id'],
      name: json['Name'],
      imageUrl: json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : null,
    );
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
      imageUrl: json['ImageTags'] != null && json['ImageTags']['Primary'] != null
          ? json['Id'] // We'll construct the full URL in the service
          : null,
      trackCount: json['ChildCount'] ?? 0,
    );
  }
}
