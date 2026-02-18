import '../models/jellyfin_models.dart';
import 'base_service.dart';
import 'players/jellyfin_service.dart';
import 'players/plex_service.dart';
import 'players/subsonic_service.dart';
import 'players/soundcloud_service.dart';
import 'players/local_music_service.dart';

class MediaServiceManager {
  BaseMediaService? _currentService;
  ServerType _currentServerType = ServerType.jellyfin;
  JellyfinService? _sharedJellyfinService;
  LocalMusicService? _sharedLocalMusicService;

  ServerType get currentServerType => _currentServerType;
  BaseMediaService? get currentService => _currentService;
  LocalMusicService? get localMusicService => _sharedLocalMusicService;

  /// Constructor that uses a shared JellyfinService instance
  MediaServiceManager.withJellyfinService(JellyfinService jellyfinService) {
    _sharedJellyfinService = jellyfinService;
    _sharedLocalMusicService = LocalMusicService();
  }

  /// Default constructor
  MediaServiceManager() {
    _sharedLocalMusicService = LocalMusicService();
  }

  /// Initialize service based on server type
  void initializeService(ServerType serverType) {
    _currentServerType = serverType;

    switch (serverType) {
      case ServerType.jellyfin:
        // Use shared JellyfinService if available, otherwise create a new one
        final jellyfinService = _sharedJellyfinService ?? JellyfinService();
        _currentService = JellyfinServiceAdapter(jellyfinService);
        break;
      case ServerType.plex:
        _currentService = PlexService();
        break;
      case ServerType.subsonic:
        _currentService = SubsonicService();
        break;
      case ServerType.soundcloud:
        _currentService = SoundCloudService();
        break;
      case ServerType.local:
        _sharedLocalMusicService ??= LocalMusicService();
        _currentService = _sharedLocalMusicService;
        break;
    }
  }

  /// Set an already authenticated JellyfinService (for Quick Connect)
  void setAuthenticatedJellyfinService(JellyfinService service) {
    _sharedJellyfinService = service;
    _currentServerType = ServerType.jellyfin;
    _currentService = JellyfinServiceAdapter(service);
  }

  /// Initialize and set local music service as active
  Future<void> setLocalMusicService() async {
    _sharedLocalMusicService ??= LocalMusicService();
    await _sharedLocalMusicService!.initialize();
    _currentServerType = ServerType.local;
    _currentService = _sharedLocalMusicService;
  }

  /// Add a directory to the local music service
  Future<void> addLocalMusicDirectory(String directoryPath) async {
    _sharedLocalMusicService ??= LocalMusicService();
    await _sharedLocalMusicService!.addDirectory(directoryPath);
  }

  /// Remove a directory from the local music service
  Future<void> removeLocalMusicDirectory(String directoryPath) async {
    if (_sharedLocalMusicService != null) {
      await _sharedLocalMusicService!.removeDirectory(directoryPath);
    }
  }

  /// Scan local music directories
  Future<void> scanLocalMusicDirectories({
    Function(int, int)? onProgress,
  }) async {
    if (_sharedLocalMusicService != null) {
      await _sharedLocalMusicService!.scanDirectories(onProgress: onProgress);
    }
  }

  /// Authenticate with the current service
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    if (_currentService == null) return false;
    return await _currentService!.authenticate(
      serverUrl,
      identifier,
      credential,
    );
  }

  /// Last auth error from the current service (e.g. SoundCloud invalid_client). Null if not supported or none.
  String? get lastAuthError {
    final s = _currentService;
    if (s is SoundCloudService) return s.lastAuthError;
    return null;
  }

  /// Set server URL for the current service
  void setServer(String serverUrl) {
    _currentService?.setServer(serverUrl);
  }

  /// Validate credentials with the current service
  Future<bool> validateCredentials() async {
    if (_currentService == null) return false;
    return await _currentService!.validateCredentials();
  }

  /// Get libraries from the current service
  Future<List<Library>> getLibraries() async {
    if (_currentService == null) return [];
    return await _currentService!.getLibraries();
  }

  /// Get albums from the current service
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    if (_currentService == null) return [];
    return await _currentService!.getAlbums(
      libraryId: libraryId,
      limit: limit,
      startIndex: startIndex,
    );
  }

  /// Get artists from the current service
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    if (_currentService == null) return [];
    return await _currentService!.getArtists(
      libraryId: libraryId,
      limit: limit,
      startIndex: startIndex,
    );
  }

  /// Get tracks from the current service
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    if (_currentService == null) {
      return [];
    }

    final tracks = await _currentService!.getTracks(
      libraryId: libraryId,
      parentId: parentId,
      limit: limit,
      startIndex: startIndex,
    );

    return tracks;
  }

  /// Get ALL tracks from the current service (with pagination for large libraries)
  /// This is useful for shuffle all functionality where you need the complete library
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    if (_currentService == null) {
      return [];
    }

    final tracks = await _currentService!.getAllTracks(maxTracks: maxTracks);

    return tracks;
  }

  /// Get all starred/favorite tracks from the current service
  Future<List<Track>> getStarredTracks() async {
    if (_currentService == null) {
      return [];
    }

    final tracks = await _currentService!.getStarredTracks();

    return tracks;
  }

  /// Get all starred/favorite albums from the current service
  Future<List<Album>> getStarredAlbums() async {
    if (_currentService == null) return [];
    return await _currentService!.getStarredAlbums();
  }

  /// Get all starred/favorite artists from the current service
  Future<List<Artist>> getStarredArtists() async {
    if (_currentService == null) return [];
    return await _currentService!.getStarredArtists();
  }

  /// Get playlists from the current service
  Future<List<Playlist>> getPlaylists() async {
    if (_currentService == null) {
      return [];
    }

    final playlists = await _currentService!.getPlaylists();

    return playlists;
  }

  /// Get tracks from a playlist
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    if (_currentService == null) return [];
    return await _currentService!.getPlaylistTracks(playlistId);
  }

  /// Get stream URL from the current service
  String getStreamUrl(String trackId, {int? bitrate}) {
    if (_currentService == null) {
      return '';
    }

    final streamUrl = _currentService!.getStreamUrl(trackId, bitrate: bitrate);

    return streamUrl;
  }

  /// Get direct stream URL (no transcoding) from the current service
  String getDirectStreamUrl(String trackId) {
    if (_currentService == null) {
      return '';
    }

    if (_currentService is JellyfinServiceAdapter) {
      final jellyfinAdapter = _currentService as JellyfinServiceAdapter;
      return jellyfinAdapter.getDirectStreamUrl(trackId);
    }

    if (_currentService is PlexService) {
      final plexService = _currentService as PlexService;
      // For Plex, use direct download URL as it's most reliable
      return plexService.getDownloadUrl(trackId);
    }

    if (_currentService is SubsonicService) {
      final subsonicService = _currentService as SubsonicService;
      // Navidrome/Subsonic has dedicated direct stream URL method
      return subsonicService.getDirectStreamUrl(trackId);
    }

    // For other services, fallback to regular stream URL
    return _currentService!.getStreamUrl(trackId);
  }

  /// Get alternative stream URLs for fallback from the current service
  List<String> getAlternativeStreamUrls(String trackId) {
    if (_currentService == null) return [];
    return _currentService!.getAlternativeStreamUrls(trackId);
  }

  /// Get alternative stream URLs with async metadata fetching for better URLs
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    if (_currentService == null) return [];
    return await _currentService!.getAlternativeStreamUrlsAsync(trackId);
  }

  /// Get image URL from the current service
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    if (_currentService == null) return '';
    return _currentService!.getImageUrl(
      itemId,
      type: type,
      width: width,
      height: height,
    );
  }

  /// Get authentication headers for HTTP requests
  /// For Jellyfin: returns auth headers
  /// For Subsonic/Navidrome: returns empty (auth is in URL params)
  /// For Plex: returns X-Plex-Token header
  Future<Map<String, String>> getAuthHeaders() async {
    if (_currentService == null) return {};

    if (_currentService is JellyfinServiceAdapter) {
      final adapter = _currentService as JellyfinServiceAdapter;
      return await adapter.getAuthHeaders();
    }

    if (_currentService is PlexService) {
      final plexService = _currentService as PlexService;
      return plexService.getAuthHeaders();
    }

    // Subsonic/Navidrome and other services use URL params for auth
    return {};
  }

  /// Search content in the current service
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    if (_currentService == null) return SearchResults();
    return await _currentService!.search(
      query,
      includeItemTypes: includeItemTypes,
      limit: limit,
    );
  }

  /// Get server information from the current service
  Future<ServerInfo> getServerInfo() async {
    if (_currentService == null) {
      return ServerInfo(
        name: 'Unknown Server',
        version: 'Unknown',
        id: 'unknown',
        type: _currentServerType,
      );
    }
    return await _currentService!.getServerInfo();
  }

  /// Get current server configuration
  dynamic get currentServer => _currentService?.currentServer;

  /// Toggle favorite status for a track
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    if (_currentService == null) {
      return false;
    }

    final result = await _currentService!.toggleFavorite(itemId, isFavorite);

    return result;
  }

  /// Clear authentication for the current service
  void clearAuth() {
    _currentService?.clearAuth();
  }

  /// Clear current service
  void clearService() {
    _currentService?.clearAuth();
    _currentService = null;
  }

  /// Service-specific playlist management methods (not in base interface)
  Future<Playlist?> createPlaylist(String name) async {
    // Dynamic dispatch based on service type
    switch (_currentServerType) {
      case ServerType.jellyfin:
        if (_currentService is JellyfinServiceAdapter) {
          final adapter = _currentService as JellyfinServiceAdapter;
          return await adapter._jellyfinService.createPlaylist(name);
        }
        break;
      case ServerType.subsonic:
        if (_currentService is SubsonicService) {
          final subsonicService = _currentService as SubsonicService;
          return await subsonicService.createPlaylist(name);
        }
        break;
      case ServerType.plex:
        // Plex playlist creation not yet implemented
        break;
      case ServerType.soundcloud:
        if (_currentService is SoundCloudService) {
          return await (_currentService as SoundCloudService).createPlaylist(name);
        }
        break;
      case ServerType.local:
        if (_currentService is LocalMusicService) {
          final localMusicService = _currentService as LocalMusicService;
          return await localMusicService.createPlaylist(name);
        }
        break;
    }
    return null;
  }

  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    // Dynamic dispatch based on service type
    switch (_currentServerType) {
      case ServerType.jellyfin:
        if (_currentService is JellyfinServiceAdapter) {
          final adapter = _currentService as JellyfinServiceAdapter;
          return await adapter._jellyfinService.addToPlaylist(
            playlistId,
            trackId,
          );
        }
        break;
      case ServerType.subsonic:
        if (_currentService is SubsonicService) {
          final subsonicService = _currentService as SubsonicService;
          return await subsonicService.addToPlaylist(playlistId, trackId);
        }
        break;
      case ServerType.plex:
        // Plex add to playlist not yet implemented
        break;
      case ServerType.soundcloud:
        if (_currentService is SoundCloudService) {
          return await (_currentService as SoundCloudService).addToPlaylist(
            playlistId,
            trackId,
          );
        }
        break;
      case ServerType.local:
        if (_currentService is LocalMusicService) {
          final localMusicService = _currentService as LocalMusicService;
          return await localMusicService.addTrackToPlaylist(
            playlistId,
            trackId,
          );
        }
        break;
    }
    return false;
  }

  Future<bool> removeTrackFromPlaylist(
    String playlistId,
    String trackId, {
    String? playlistItemId,
    int? trackIndex,
  }) async {
    // Dynamic dispatch based on service type
    switch (_currentServerType) {
      case ServerType.jellyfin:
        if (_currentService is JellyfinServiceAdapter) {
          final adapter = _currentService as JellyfinServiceAdapter;
          return await adapter._jellyfinService.removeTrackFromPlaylist(
            playlistId,
            playlistItemId: playlistItemId,
            trackId: trackId,
          );
        }
        break;
      case ServerType.subsonic:
        if (_currentService is SubsonicService && trackIndex != null) {
          final subsonicService = _currentService as SubsonicService;
          return await subsonicService.removeTrackFromPlaylist(
            playlistId,
            trackIndex,
          );
        }
        break;
      case ServerType.local:
        if (_currentService is LocalMusicService) {
          final localMusicService = _currentService as LocalMusicService;
          return await localMusicService.removeTrackFromPlaylist(
            playlistId,
            trackId,
          );
        }
        break;
      case ServerType.plex:
        // Plex remove track from playlist not yet implemented
        break;
      case ServerType.soundcloud:
        if (_currentService is SoundCloudService) {
          return await (_currentService as SoundCloudService).removeTrackFromPlaylist(
            playlistId,
            trackId,
          );
        }
        break;
    }
    return false;
  }

  Future<bool> renamePlaylist(String playlistId, String newName) async {
    // Dynamic dispatch based on service type
    switch (_currentServerType) {
      case ServerType.jellyfin:
        if (_currentService is JellyfinServiceAdapter) {
          final adapter = _currentService as JellyfinServiceAdapter;
          return await adapter._jellyfinService.renamePlaylist(
            playlistId,
            newName,
          );
        }
        break;
      case ServerType.subsonic:
        if (_currentService is SubsonicService) {
          final subsonicService = _currentService as SubsonicService;
          return await subsonicService.renamePlaylist(playlistId, newName);
        }
        break;
      case ServerType.plex:
        // Plex rename playlist not yet implemented
        break;
      case ServerType.soundcloud:
        if (_currentService is SoundCloudService) {
          return await (_currentService as SoundCloudService).renamePlaylist(
            playlistId,
            newName,
          );
        }
        break;
      case ServerType.local:
        if (_currentService is LocalMusicService) {
          final localMusicService = _currentService as LocalMusicService;
          return await localMusicService.renamePlaylist(playlistId, newName);
        }
        break;
    }
    return false;
  }

  Future<bool> removePlaylist(String playlistId) async {
    // Dynamic dispatch based on service type
    switch (_currentServerType) {
      case ServerType.jellyfin:
        if (_currentService is JellyfinServiceAdapter) {
          final adapter = _currentService as JellyfinServiceAdapter;
          return await adapter._jellyfinService.removePlaylist(playlistId);
        }
        break;
      case ServerType.subsonic:
        if (_currentService is SubsonicService) {
          final subsonicService = _currentService as SubsonicService;
          return await subsonicService.removePlaylist(playlistId);
        }
        break;
      case ServerType.plex:
        // Plex remove playlist not yet implemented
        break;
      case ServerType.soundcloud:
        if (_currentService is SoundCloudService) {
          return await (_currentService as SoundCloudService).removePlaylist(
            playlistId,
          );
        }
        break;
      case ServerType.local:
        if (_currentService is LocalMusicService) {
          final localMusicService = _currentService as LocalMusicService;
          return await localMusicService.deletePlaylist(playlistId);
        }
        break;
    }
    return false;
  }
}

/// Adapter to make JellyfinService compatible with BaseMediaService interface
class JellyfinServiceAdapter implements BaseMediaService {
  final JellyfinService _jellyfinService;

  JellyfinServiceAdapter(this._jellyfinService);

  @override
  ServerType get serverType => ServerType.jellyfin;

  @override
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    return await _jellyfinService.authenticate(
      serverUrl,
      identifier,
      credential,
    );
  }

  @override
  void setServer(String serverUrl) {
    // Only set server if it's not already configured or if the URL is different
    final currentServer = _jellyfinService.currentServer;
    if (currentServer == null || currentServer.serverUrl != serverUrl) {
      // If the service is already authenticated, don't override the server config
      if (currentServer?.accessToken != null &&
          currentServer?.serverUrl == serverUrl) {
        return;
      }

      // Convert string URL to JellyfinServer object
      final server = JellyfinServer(serverUrl: serverUrl);
      _jellyfinService.setJellyfinServer(server);
    }
  }

  @override
  Future<bool> validateCredentials() async {
    return await _jellyfinService.validateCredentials();
  }

  @override
  Future<List<Library>> getLibraries() async {
    // For now, return a default music library for Jellyfin
    // This should be implemented properly in JellyfinService later
    return [Library(id: 'music', name: 'Music', collectionType: 'music')];
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    return await _jellyfinService.getAlbums();
  }

  @override
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    return await _jellyfinService.getArtists();
  }

  @override
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    if (parentId != null) {
      // If parentId is provided, get album tracks
      return await _jellyfinService.getAlbumTracks(parentId);
    }
    // Otherwise get all tracks or library tracks
    return await _jellyfinService.getTracks(
      libraryId: libraryId,
      limit: limit,
      startIndex: startIndex,
    );
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    // Jellyfin can return all tracks with a high limit
    // The getTracks method handles pagination internally
    return await _jellyfinService.getTracks(limit: maxTracks ?? 50000);
  }

  @override
  Future<List<Track>> getStarredTracks() async {
    // Get favorite tracks from Jellyfin
    return await _jellyfinService.getFavoriteTracks();
  }

  @override
  Future<List<Album>> getStarredAlbums() async {
    // Get favorite albums from Jellyfin
    return await _jellyfinService.getFavoriteAlbums();
  }

  @override
  Future<List<Artist>> getStarredArtists() async {
    // Get favorite artists from Jellyfin
    return await _jellyfinService.getFavoriteArtists();
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    return await _jellyfinService.getPlaylists();
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    return await _jellyfinService.getPlaylistTracks(playlistId);
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    return _jellyfinService.getStreamUrl(trackId);
  }

  /// Get direct stream URL (no transcoding)
  String getDirectStreamUrl(String trackId) {
    return _jellyfinService.getDirectStreamUrl(trackId);
  }

  /// Get authentication headers for HTTP requests
  Future<Map<String, String>> getAuthHeaders() async {
    return await _jellyfinService.getAuthHeaders();
  }

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    return _jellyfinService.getImageUrl(itemId, width: width, height: height);
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    return await _jellyfinService.search(
      query,
      includeItemTypes: includeItemTypes,
      limit: limit,
    );
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    return await _jellyfinService.getServerInfo();
  }

  @override
  get currentServer => _jellyfinService.currentServer;

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    // Return Jellyfin alternative stream URLs
    return [
      _jellyfinService.getStreamUrl(trackId), // Primary transcoded URL
      _jellyfinService.getDirectStreamUrl(trackId), // Direct stream
      _jellyfinService.getUniversalStreamUrl(trackId), // Universal fallback
    ];
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    // Jellyfin doesn't need async metadata fetching
    return getAlternativeStreamUrls(trackId);
  }

  @override
  void clearAuth() {
    _jellyfinService.clearAuth();
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    return await _jellyfinService.toggleFavorite(itemId, isFavorite);
  }
}
