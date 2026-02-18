import '../models/jellyfin_models.dart';

enum ServerType { jellyfin, plex, subsonic, soundcloud, youtubeMusic, local }

/// Base interface for all media server services
abstract class BaseMediaService {
  ServerType get serverType;

  /// Authenticate with the server
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  );

  /// Set server configuration
  void setServer(String serverUrl);

  /// Validate stored credentials
  Future<bool> validateCredentials();

  /// Get user libraries/collections
  Future<List<Library>> getLibraries();

  /// Get albums from a library
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  });

  /// Get artists from a library
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  });

  /// Get tracks/songs from a library or album
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  });

  /// Get all tracks from the library (with pagination support for large libraries)
  /// Returns all available tracks, useful for shuffle all functionality
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    // Default implementation falls back to getTracks with a high limit
    return getTracks(limit: maxTracks ?? 10000);
  }

  /// Get all starred/favorite tracks
  Future<List<Track>> getStarredTracks() async {
    // Default implementation - override in services that support starring
    return [];
  }

  /// Get all starred/favorite albums
  Future<List<Album>> getStarredAlbums() async {
    // Default implementation - override in services that support starring
    return [];
  }

  /// Get all starred/favorite artists
  Future<List<Artist>> getStarredArtists() async {
    // Default implementation - override in services that support starring
    return [];
  }

  /// Get playlists
  Future<List<Playlist>> getPlaylists();

  /// Get tracks from a playlist
  Future<List<Track>> getPlaylistTracks(String playlistId);

  /// Get stream URL for a track
  String getStreamUrl(String trackId, {int? bitrate});

  /// Get alternative stream URLs for fallback (optional implementation)
  List<String> getAlternativeStreamUrls(String trackId) => [];

  /// Get alternative stream URLs with async metadata fetching for better URLs (optional implementation)
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async =>
      getAlternativeStreamUrls(trackId);

  /// Get image URL for an item
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  });

  /// Search for content
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  });

  /// Get server info
  Future<ServerInfo> getServerInfo();

  /// Get current server configuration
  dynamic get currentServer;

  /// Toggle favorite status for a track
  Future<bool> toggleFavorite(String itemId, bool isFavorite);

  /// Clear authentication
  void clearAuth();
}

/// Search results container
class SearchResults {
  final List<Album> albums;
  final List<Artist> artists;
  final List<Track> tracks;
  final List<Playlist> playlists;

  SearchResults({
    this.albums = const [],
    this.artists = const [],
    this.tracks = const [],
    this.playlists = const [],
  });
}

/// Server information
class ServerInfo {
  final String name;
  final String version;
  final String id;
  final ServerType type;

  ServerInfo({
    required this.name,
    required this.version,
    required this.id,
    required this.type,
  });
}
