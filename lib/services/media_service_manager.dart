import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';
import 'base_service.dart';
import 'jellyfin_service.dart';
import 'plex_service.dart';
import 'navidrome_service.dart';

class MediaServiceManager {
  BaseMediaService? _currentService;
  ServerType _currentServerType = ServerType.jellyfin;

  ServerType get currentServerType => _currentServerType;
  BaseMediaService? get currentService => _currentService;

  /// Initialize service based on server type
  void initializeService(ServerType serverType) {
    _currentServerType = serverType;
    
    switch (serverType) {
      case ServerType.jellyfin:
        _currentService = JellyfinServiceAdapter(JellyfinService());
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
    if (_currentService == null) return [];
    return await _currentService!.getTracks(libraryId: libraryId, parentId: parentId, limit: limit, startIndex: startIndex);
  }

  /// Get playlists from the current service
  Future<List<Playlist>> getPlaylists() async {
    if (_currentService == null) return [];
    return await _currentService!.getPlaylists();
  }

  /// Get tracks from a playlist
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    if (_currentService == null) return [];
    return await _currentService!.getPlaylistTracks(playlistId);
  }

  /// Get stream URL from the current service
  String getStreamUrl(String trackId, {int? bitrate}) {
    if (kDebugMode) {
      print('MediaServiceManager.getStreamUrl called for trackId: $trackId');
      print('Current service: $_currentService');
      print('Current server type: $_currentServerType');
    }
    
    if (_currentService == null) {
      if (kDebugMode) {
        print('ERROR: Current service is null!');
      }
      return '';
    }
    
    final streamUrl = _currentService!.getStreamUrl(trackId, bitrate: bitrate);
    if (kDebugMode) {
      print('Stream URL generated: $streamUrl');
    }
    
    return streamUrl;
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

  /// Clear authentication for the current service
  void clearAuth() {
    _currentService?.clearAuth();
  }

  /// Clear current service
  void clearService() {
    _currentService?.clearAuth();
    _currentService = null;
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
    return ServerInfo(
      name: 'Jellyfin Server',
      version: 'Unknown',
      id: _jellyfinService.currentServer?.serverUrl ?? 'unknown',
      type: ServerType.jellyfin,
    );
  }

  @override
  get currentServer => _jellyfinService.currentServer;

  @override
  void clearAuth() {
    _jellyfinService.clearAuth();
  }
}