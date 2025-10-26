import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';
import 'base_service.dart';
import 'jellyfin_service.dart';
import 'plex_service.dart';
import 'navidrome_service.dart';

class MediaServiceManager {
  BaseMediaService? _currentService;
  ServerType _currentServerType = ServerType.jellyfin;
  JellyfinService? _sharedJellyfinService;

  ServerType get currentServerType => _currentServerType;
  BaseMediaService? get currentService => _currentService;

  /// Constructor that uses a shared JellyfinService instance
  MediaServiceManager.withJellyfinService(JellyfinService jellyfinService) {
    _sharedJellyfinService = jellyfinService;
  }

  /// Default constructor
  MediaServiceManager();

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
      case ServerType.navidrome:
        _currentService = NavidromeService();
        break;
    }
  }

  /// Authenticate with the current service
  Future<bool> authenticate(String serverUrl, String identifier, String credential) async {
    if (_currentService == null) return false;
    return await _currentService!.authenticate(serverUrl, identifier, credential);
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
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
    if (_currentService == null) return [];
    return await _currentService!.getAlbums(libraryId: libraryId, limit: limit, startIndex: startIndex);
  }

  /// Get artists from the current service
  Future<List<Artist>> getArtists({String? libraryId, int? limit, int? startIndex}) async {
    if (_currentService == null) return [];
    return await _currentService!.getArtists(libraryId: libraryId, limit: limit, startIndex: startIndex);
  }

  /// Get tracks from the current service
  Future<List<Track>> getTracks({String? libraryId, String? parentId, int? limit, int? startIndex}) async {
    if (kDebugMode) {
      print('MediaServiceManager.getTracks called:');
      print('  - libraryId: $libraryId');
      print('  - parentId: $parentId');
      print('  - limit: $limit');
      print('  - startIndex: $startIndex');
      print('  - currentService: ${_currentService?.runtimeType}');
      print('  - currentServerType: $currentServerType');
    }
    
    if (_currentService == null) {
      if (kDebugMode) {
        print('MediaServiceManager: No current service available!');
      }
      return [];
    }
    
    final tracks = await _currentService!.getTracks(libraryId: libraryId, parentId: parentId, limit: limit, startIndex: startIndex);
    
    if (kDebugMode) {
      print('MediaServiceManager: Service returned ${tracks.length} tracks');
      if (tracks.isNotEmpty) {
        print('MediaServiceManager: First track: ${tracks.first.name}');
      }
    }
    
    return tracks;
  }

  /// Get playlists from the current service
  Future<List<Playlist>> getPlaylists() async {
    if (kDebugMode) {
      print('MediaServiceManager.getPlaylists() called');
      print('  - currentService: ${_currentService?.runtimeType}');
      print('  - currentServerType: $currentServerType');
    }
    
    if (_currentService == null) {
      if (kDebugMode) {
        print('MediaServiceManager: No current service available for getPlaylists!');
      }
      return [];
    }
    
    final playlists = await _currentService!.getPlaylists();
    
    if (kDebugMode) {
      print('MediaServiceManager: Service returned ${playlists.length} playlists');
      if (playlists.isNotEmpty) {
        print('MediaServiceManager: First playlist: ${playlists.first.name} (${playlists.first.trackCount} tracks)');
      }
    }
    
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
      if (kDebugMode) {
        print('ERROR: Current service is null!');
      }
      return '';
    }
    
    final streamUrl = _currentService!.getStreamUrl(trackId, bitrate: bitrate);
    
    return streamUrl;
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
  String getImageUrl(String itemId, {String type = 'Primary', int? width, int? height}) {
    if (_currentService == null) return '';
    return _currentService!.getImageUrl(itemId, type: type, width: width, height: height);
  }

  /// Search content in the current service
  Future<SearchResults> search(String query, {List<String>? includeItemTypes, int? limit}) async {
    if (_currentService == null) return SearchResults();
    return await _currentService!.search(query, includeItemTypes: includeItemTypes, limit: limit);
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
    if (kDebugMode) {
      print('MediaServiceManager.toggleFavorite: itemId=$itemId, isFavorite=$isFavorite, serverType=$_currentServerType');
    }
    
    if (_currentService == null) {
      if (kDebugMode) {
        print('MediaServiceManager.toggleFavorite: ERROR - No current service!');
      }
      return false;
    }
    
    final result = await _currentService!.toggleFavorite(itemId, isFavorite);
    
    if (kDebugMode) {
      print('MediaServiceManager.toggleFavorite: Service returned $result');
    }
    
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
      case ServerType.navidrome:
        if (_currentService is NavidromeService) {
          final navidromeService = _currentService as NavidromeService;
          return await navidromeService.createPlaylist(name);
        }
        break;
      case ServerType.plex:
        // Plex playlist creation could be implemented here
        if (kDebugMode) {
          print('Plex playlist creation not yet implemented');
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
          return await adapter._jellyfinService.addToPlaylist(playlistId, trackId);
        }
        break;
      case ServerType.navidrome:
        if (_currentService is NavidromeService) {
          final navidromeService = _currentService as NavidromeService;
          return await navidromeService.addToPlaylist(playlistId, trackId);
        }
        break;
      case ServerType.plex:
        // Plex add to playlist could be implemented here
        if (kDebugMode) {
          print('Plex add to playlist not yet implemented');
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
          return await adapter._jellyfinService.renamePlaylist(playlistId, newName);
        }
        break;
      case ServerType.navidrome:
        if (_currentService is NavidromeService) {
          final navidromeService = _currentService as NavidromeService;
          return await navidromeService.renamePlaylist(playlistId, newName);
        }
        break;
      case ServerType.plex:
        // Plex rename playlist could be implemented here
        if (kDebugMode) {
          print('Plex rename playlist not yet implemented');
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
      case ServerType.navidrome:
        if (_currentService is NavidromeService) {
          final navidromeService = _currentService as NavidromeService;
          return await navidromeService.removePlaylist(playlistId);
        }
        break;
      case ServerType.plex:
        // Plex remove playlist could be implemented here
        if (kDebugMode) {
          print('Plex remove playlist not yet implemented');
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
  Future<bool> authenticate(String serverUrl, String identifier, String credential) async {
    return await _jellyfinService.authenticate(serverUrl, identifier, credential);
  }

  @override
  void setServer(String serverUrl) {
    // Convert string URL to JellyfinServer object
    final server = JellyfinServer(
      serverUrl: serverUrl,
    );
    _jellyfinService.setJellyfinServer(server);
  }

  @override
  Future<bool> validateCredentials() async {
    return await _jellyfinService.validateCredentials();
  }

  @override
  Future<List<Library>> getLibraries() async {
    // For now, return a default music library for Jellyfin
    // This should be implemented properly in JellyfinService later
    return [
      Library(id: 'music', name: 'Music', collectionType: 'music'),
    ];
  }

  @override
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
    return await _jellyfinService.getAlbums();
  }

  @override
  Future<List<Artist>> getArtists({String? libraryId, int? limit, int? startIndex}) async {
    return await _jellyfinService.getArtists();
  }

  @override
  Future<List<Track>> getTracks({String? libraryId, String? parentId, int? limit, int? startIndex}) async {
    if (parentId != null) {
      // If parentId is provided, get album tracks
      return await _jellyfinService.getAlbumTracks(parentId);
    }
    // Otherwise get all tracks or library tracks
    return await _jellyfinService.getTracks(libraryId: libraryId, limit: limit, startIndex: startIndex);
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

  @override
  String getImageUrl(String itemId, {String type = 'Primary', int? width, int? height}) {
    return _jellyfinService.getImageUrl(itemId, width: width, height: height);
  }

  @override
  Future<SearchResults> search(String query, {List<String>? includeItemTypes, int? limit}) async {
    return await _jellyfinService.search(query, includeItemTypes: includeItemTypes, limit: limit);
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
      _jellyfinService.getStreamUrl(trackId),          // Primary transcoded URL
      _jellyfinService.getDirectStreamUrl(trackId),    // Direct stream
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