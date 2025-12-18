import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/jellyfin_models.dart';
import '../base_service.dart';

/// Service for playing music from local filesystem directories
class LocalMusicService implements BaseMediaService {
  List<String> _musicDirectories = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Track> _tracks = [];
  final List<Playlist> _playlists = [];
  bool _isInitialized = false;
  bool _isScanning = false;
  
  // Map from track ID to file path for efficient lookup
  final Map<String, String> _trackIdToPath = {};
  
  // Supported audio formats
  static const List<String> supportedFormats = [
    '.mp3', '.flac', '.wav', '.ogg', '.m4a', '.aac', 
    '.wma', '.opus', '.aiff', '.alac', '.ape', '.webm'
  ];

  // Cache keys
  static const String _directoriesKey = 'local_music_directories';
  static const String _cachedTracksKey = 'local_music_cached_tracks';
  static const String _cachedAlbumsKey = 'local_music_cached_albums';
  static const String _cachedArtistsKey = 'local_music_cached_artists';
  static const String _cachedPathsKey = 'local_music_cached_paths';
  static const String _lastScanKey = 'local_music_last_scan';

  @override
  ServerType get serverType => ServerType.local;

  @override
  dynamic get currentServer => LocalMusicServer(directories: _musicDirectories);

  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  List<String> get musicDirectories => List.unmodifiable(_musicDirectories);

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved directories
    final savedDirs = prefs.getStringList(_directoriesKey);
    if (savedDirs != null) {
      _musicDirectories = savedDirs;
    }
    
    // Load cached data
    await _loadCachedData(prefs);
    
    _isInitialized = true;
    
    if (kDebugMode) {
      print('LocalMusicService initialized with ${_musicDirectories.length} directories');
      print('Cached: ${_albums.length} albums, ${_artists.length} artists, ${_tracks.length} tracks');
    }
  }

  /// Add a directory to scan for music
  Future<void> addDirectory(String directoryPath) async {
    if (!_musicDirectories.contains(directoryPath)) {
      final dir = Directory(directoryPath);
      if (await dir.exists()) {
        _musicDirectories.add(directoryPath);
        await _saveDirectories();
        
        if (kDebugMode) {
          print('LocalMusicService: Added directory $directoryPath');
        }
      } else {
        throw Exception('Directory does not exist: $directoryPath');
      }
    }
  }

  /// Remove a directory from the music sources
  Future<void> removeDirectory(String directoryPath) async {
    _musicDirectories.remove(directoryPath);
    await _saveDirectories();
    
    // Remove tracks from that directory
    _tracks.removeWhere((track) => track.id.startsWith(_generatePathHash(directoryPath)));
    
    // Rebuild albums and artists
    _rebuildCollections();
    await _saveCachedData();
    
    if (kDebugMode) {
      print('LocalMusicService: Removed directory $directoryPath');
    }
  }

  /// Scan all directories for music files
  Future<void> scanDirectories({Function(int, int)? onProgress}) async {
    if (_isScanning) return;
    _isScanning = true;
    
    try {
      final newTracks = <Track>[];
      int totalFiles = 0;
      int processedFiles = 0;
      
      // First pass: count total files
      for (final dirPath in _musicDirectories) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File && _isAudioFile(entity.path)) {
              totalFiles++;
            }
          }
        }
      }
      
      if (kDebugMode) {
        print('LocalMusicService: Found $totalFiles audio files to scan');
      }
      
      // Second pass: process files
      for (final dirPath in _musicDirectories) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File && _isAudioFile(entity.path)) {
              processedFiles++;
              onProgress?.call(processedFiles, totalFiles);
              
              try {
                final track = await _createTrackFromFile(entity, dirPath);
                newTracks.add(track);
              } catch (e) {
                if (kDebugMode) {
                  print('Error processing file ${entity.path}: $e');
                }
              }
            }
          }
        }
      }
      
      _tracks = newTracks;
      _rebuildCollections();
      await _saveCachedData();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastScanKey, DateTime.now().toIso8601String());
      
      if (kDebugMode) {
        print('LocalMusicService: Scan complete. Found ${_tracks.length} tracks');
        print('Built ${_albums.length} albums and ${_artists.length} artists');
      }
    } finally {
      _isScanning = false;
    }
  }

  /// Create a Track object from a local file
  Future<Track> _createTrackFromFile(File file, String baseDir) async {
    final filePath = file.path;
    final fileName = path.basenameWithoutExtension(filePath);
    final parentDir = path.dirname(filePath);
    final parentDirName = path.basename(parentDir);
    
    // Generate unique ID based on file path
    final trackId = _generateFileId(filePath);
    
    // Try to parse track info from filename and directory structure
    // Common formats: "01 - Track Name.mp3" or "Artist - Track Name.mp3"
    String trackName = fileName;
    String? artistName;
    String? albumName;
    int? trackNumber;
    
    // Try to extract track number from filename
    final trackNumberMatch = RegExp(r'^(\d+)[\s._-]+(.+)$').firstMatch(fileName);
    if (trackNumberMatch != null) {
      trackNumber = int.tryParse(trackNumberMatch.group(1)!);
      trackName = trackNumberMatch.group(2)!.trim();
    }
    
    // Try to extract artist from "Artist - Track" format
    final artistTrackMatch = RegExp(r'^([^-]+)\s*-\s*(.+)$').firstMatch(trackName);
    if (artistTrackMatch != null) {
      artistName = artistTrackMatch.group(1)!.trim();
      trackName = artistTrackMatch.group(2)!.trim();
    }
    
    // Use parent directory as album name (common folder structure)
    albumName = parentDirName;
    
    // Try to detect artist from grandparent directory (Artist/Album/Track structure)
    final grandParentDir = path.dirname(parentDir);
    if (grandParentDir != baseDir) {
      final potentialArtist = path.basename(grandParentDir);
      // Don't use the base directory name as artist
      if (potentialArtist.isNotEmpty && !_musicDirectories.contains(grandParentDir)) {
        artistName ??= potentialArtist;
      }
    }
    
    // Generate album ID based on album folder path
    final albumId = _generatePathHash(parentDir);
    
    // Store the file path for later retrieval
    _trackIdToPath[trackId] = filePath;
    
    return Track(
      id: trackId,
      name: trackName,
      albumName: albumName,
      artistName: artistName ?? 'Unknown Artist',
      albumId: albumId,
      duration: null, // Would need metadata extraction for this
      trackNumber: trackNumber,
      imageUrl: _findAlbumArt(parentDir),
      isFavorite: false,
    );
  }

  /// Find album art in a directory
  String? _findAlbumArt(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;
    
    const artFileNames = [
      'cover.jpg', 'cover.png', 'cover.jpeg',
      'folder.jpg', 'folder.png', 'folder.jpeg',
      'album.jpg', 'album.png', 'album.jpeg',
      'front.jpg', 'front.png', 'front.jpeg',
      'art.jpg', 'art.png', 'art.jpeg',
    ];
    
    for (final artName in artFileNames) {
      final artFile = File(path.join(dirPath, artName));
      if (artFile.existsSync()) {
        return artFile.path;
      }
    }
    
    // Look for any image file
    try {
      final files = dir.listSync();
      for (final file in files) {
        if (file is File) {
          final ext = path.extension(file.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
            return file.path;
          }
        }
      }
    } catch (_) {}
    
    return null;
  }

  /// Rebuild albums and artists from tracks
  void _rebuildCollections() {
    final albumsMap = <String, Album>{};
    final artistsMap = <String, Artist>{};
    
    for (final track in _tracks) {
      // Build albums
      if (track.albumId != null) {
        if (!albumsMap.containsKey(track.albumId)) {
          albumsMap[track.albumId!] = Album(
            id: track.albumId!,
            name: track.albumName ?? 'Unknown Album',
            artistName: track.artistName,
            imageUrl: track.imageUrl,
          );
        }
      }
      
      // Build artists
      final artistName = track.artistName ?? 'Unknown Artist';
      final artistId = _generatePathHash(artistName);
      if (!artistsMap.containsKey(artistId)) {
        artistsMap[artistId] = Artist(
          id: artistId,
          name: artistName,
        );
      }
    }
    
    _albums = albumsMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _artists = artistsMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Generate a unique ID for a file path
  String _generateFileId(String filePath) {
    final bytes = utf8.encode(filePath);
    final hash = md5.convert(bytes);
    return 'local_$hash';
  }

  /// Generate a hash for a path (used for album/artist IDs)
  String _generatePathHash(String pathStr) {
    final bytes = utf8.encode(pathStr);
    final hash = md5.convert(bytes);
    return 'local_$hash';
  }

  /// Check if a file is a supported audio format
  bool _isAudioFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return supportedFormats.contains(ext);
  }

  /// Save directories to preferences
  Future<void> _saveDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_directoriesKey, _musicDirectories);
  }

  /// Save cached data to preferences
  Future<void> _saveCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save tracks as JSON
    final tracksJson = _tracks.map((t) => t.toJson()).toList();
    await prefs.setString(_cachedTracksKey, jsonEncode(tracksJson));
    
    // Save albums as JSON
    final albumsJson = _albums.map((a) => a.toJson()).toList();
    await prefs.setString(_cachedAlbumsKey, jsonEncode(albumsJson));
    
    // Save artists as JSON
    final artistsJson = _artists.map((a) => a.toJson()).toList();
    await prefs.setString(_cachedArtistsKey, jsonEncode(artistsJson));
    
    // Save track ID to path mapping
    await prefs.setString(_cachedPathsKey, jsonEncode(_trackIdToPath));
  }

  /// Load cached data from preferences
  Future<void> _loadCachedData(SharedPreferences prefs) async {
    try {
      // Load tracks
      final tracksString = prefs.getString(_cachedTracksKey);
      if (tracksString != null) {
        final tracksList = jsonDecode(tracksString) as List;
        _tracks = tracksList.map((json) => Track.fromJson(json)).toList();
      }
      
      // Load albums
      final albumsString = prefs.getString(_cachedAlbumsKey);
      if (albumsString != null) {
        final albumsList = jsonDecode(albumsString) as List;
        _albums = albumsList.map((json) => Album.fromJson(json)).toList();
      }
      
      // Load artists
      final artistsString = prefs.getString(_cachedArtistsKey);
      if (artistsString != null) {
        final artistsList = jsonDecode(artistsString) as List;
        _artists = artistsList.map((json) => Artist.fromJson(json)).toList();
      }
      
      // Load track ID to path mapping
      final pathsString = prefs.getString(_cachedPathsKey);
      if (pathsString != null) {
        final pathsMap = jsonDecode(pathsString) as Map<String, dynamic>;
        _trackIdToPath.clear();
        pathsMap.forEach((key, value) {
          _trackIdToPath[key] = value as String;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cached data: $e');
      }
      // Clear corrupted cache
      _tracks = [];
      _albums = [];
      _artists = [];
      _trackIdToPath.clear();
    }
  }

  // ==================== BaseMediaService Implementation ====================

  @override
  Future<bool> authenticate(String serverUrl, String identifier, String credential) async {
    // Local music doesn't need authentication
    await initialize();
    return _musicDirectories.isNotEmpty;
  }

  @override
  void setServer(String serverUrl) {
    // For local music, serverUrl is treated as a directory path
    if (serverUrl.isNotEmpty && !_musicDirectories.contains(serverUrl)) {
      addDirectory(serverUrl);
    }
  }

  @override
  Future<bool> validateCredentials() async {
    await initialize();
    // Validate that at least one directory exists
    for (final dirPath in _musicDirectories) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<Library>> getLibraries() async {
    await initialize();
    // Return each directory as a library
    return _musicDirectories.map((dirPath) => Library(
      id: _generatePathHash(dirPath),
      name: path.basename(dirPath),
      collectionType: 'music',
    )).toList();
  }

  @override
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
    await initialize();
    
    var albums = _albums;
    
    // Filter by library (directory) if specified
    if (libraryId != null) {
      final dirPath = _musicDirectories.firstWhere(
        (d) => _generatePathHash(d) == libraryId,
        orElse: () => '',
      );
      if (dirPath.isNotEmpty) {
        albums = albums.where((album) {
          // Check if any track from this album is in this directory
          return _tracks.any((track) => 
            track.albumId == album.id && 
            track.id.startsWith('local_') // All local tracks start with local_
          );
        }).toList();
      }
    }
    
    // Apply pagination
    if (startIndex != null && startIndex > 0) {
      albums = albums.skip(startIndex).toList();
    }
    if (limit != null && limit > 0) {
      albums = albums.take(limit).toList();
    }
    
    return albums;
  }

  @override
  Future<List<Artist>> getArtists({String? libraryId, int? limit, int? startIndex}) async {
    await initialize();
    
    var artists = _artists;
    
    // Apply pagination
    if (startIndex != null && startIndex > 0) {
      artists = artists.skip(startIndex).toList();
    }
    if (limit != null && limit > 0) {
      artists = artists.take(limit).toList();
    }
    
    return artists;
  }

  @override
  Future<List<Track>> getTracks({String? libraryId, String? parentId, int? limit, int? startIndex}) async {
    await initialize();
    
    var tracks = _tracks;
    
    // Filter by album (parentId)
    if (parentId != null) {
      tracks = tracks.where((t) => t.albumId == parentId).toList();
      // Sort by track number
      tracks.sort((a, b) => (a.trackNumber ?? 999).compareTo(b.trackNumber ?? 999));
    }
    
    // Apply pagination
    if (startIndex != null && startIndex > 0) {
      tracks = tracks.skip(startIndex).toList();
    }
    if (limit != null && limit > 0) {
      tracks = tracks.take(limit).toList();
    }
    
    return tracks;
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    await initialize();
    return _playlists;
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    // TODO: Implement local playlists
    return [];
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    // First try to get the path from our cached map (fast lookup)
    final cachedPath = _trackIdToPath[trackId];
    if (cachedPath != null && File(cachedPath).existsSync()) {
      return 'file://$cachedPath';
    }
    
    // If not in cache, search through directories (slower but thorough)
    for (final dirPath in _musicDirectories) {
      final foundPath = _findFileByTrackId(dirPath, trackId);
      if (foundPath != null) {
        // Cache the path for future lookups
        _trackIdToPath[trackId] = foundPath;
        return 'file://$foundPath';
      }
    }
    
    if (kDebugMode) {
      print('LocalMusicService: File not found for track ID $trackId');
    }
    return '';
  }

  /// Find a file by its track ID
  String? _findFileByTrackId(String dirPath, String trackId) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;
    
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && _isAudioFile(entity.path)) {
          if (_generateFileId(entity.path) == trackId) {
            return entity.path;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching for file: $e');
      }
    }
    
    return null;
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    final url = getStreamUrl(trackId);
    return url.isNotEmpty ? [url] : [];
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    return getAlternativeStreamUrls(trackId);
  }

  @override
  String getImageUrl(String itemId, {String type = 'Primary', int? width, int? height}) {
    // For local files, the imageUrl field contains the actual file path
    // Check if it's an album
    final album = _albums.firstWhere(
      (a) => a.id == itemId,
      orElse: () => Album(id: '', name: ''),
    );
    if (album.id.isNotEmpty && album.imageUrl != null) {
      return 'file://${album.imageUrl}';
    }
    
    // Check if it's a track
    final track = _tracks.firstWhere(
      (t) => t.id == itemId,
      orElse: () => Track(id: '', name: ''),
    );
    if (track.id.isNotEmpty && track.imageUrl != null) {
      return 'file://${track.imageUrl}';
    }
    
    // If itemId is already a path, return it
    if (itemId.startsWith('/') || itemId.startsWith('file://')) {
      return itemId.startsWith('file://') ? itemId : 'file://$itemId';
    }
    
    return '';
  }

  @override
  Future<SearchResults> search(String query, {List<String>? includeItemTypes, int? limit}) async {
    await initialize();
    
    final queryLower = query.toLowerCase();
    
    final matchingAlbums = _albums.where((a) => 
      a.name.toLowerCase().contains(queryLower) ||
      (a.artistName?.toLowerCase().contains(queryLower) ?? false)
    ).take(limit ?? 20).toList();
    
    final matchingArtists = _artists.where((a) =>
      a.name.toLowerCase().contains(queryLower)
    ).take(limit ?? 20).toList();
    
    final matchingTracks = _tracks.where((t) =>
      t.name.toLowerCase().contains(queryLower) ||
      (t.artistName?.toLowerCase().contains(queryLower) ?? false) ||
      (t.albumName?.toLowerCase().contains(queryLower) ?? false)
    ).take(limit ?? 50).toList();
    
    return SearchResults(
      albums: matchingAlbums,
      artists: matchingArtists,
      tracks: matchingTracks,
      playlists: [],
    );
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    return ServerInfo(
      name: 'Local Music',
      version: '1.0.0',
      id: 'local_music',
      type: ServerType.jellyfin,
    );
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    // Find and update track favorite status
    final trackIndex = _tracks.indexWhere((t) => t.id == itemId);
    if (trackIndex >= 0) {
      final track = _tracks[trackIndex];
      _tracks[trackIndex] = Track(
        id: track.id,
        name: track.name,
        albumName: track.albumName,
        artistName: track.artistName,
        albumId: track.albumId,
        duration: track.duration,
        trackNumber: track.trackNumber,
        imageUrl: track.imageUrl,
        isFavorite: isFavorite,
        playCount: track.playCount,
      );
      await _saveCachedData();
      return true;
    }
    return false;
  }

  @override
  void clearAuth() {
    // Clear all data
    _musicDirectories.clear();
    _albums.clear();
    _artists.clear();
    _tracks.clear();
    _playlists.clear();
    _isInitialized = false;
  }

  /// Get tracks for a specific artist
  Future<List<Track>> getArtistTracks(String artistId) async {
    await initialize();
    
    final artist = _artists.firstWhere(
      (a) => a.id == artistId,
      orElse: () => Artist(id: '', name: ''),
    );
    
    if (artist.id.isEmpty) return [];
    
    return _tracks.where((t) => 
      t.artistName?.toLowerCase() == artist.name.toLowerCase()
    ).toList();
  }

  /// Get albums for a specific artist
  Future<List<Album>> getArtistAlbums(String artistId) async {
    await initialize();
    
    final artist = _artists.firstWhere(
      (a) => a.id == artistId,
      orElse: () => Artist(id: '', name: ''),
    );
    
    if (artist.id.isEmpty) return [];
    
    return _albums.where((a) => 
      a.artistName?.toLowerCase() == artist.name.toLowerCase()
    ).toList();
  }

  /// Get favorite tracks
  Future<List<Track>> getFavoriteTracks() async {
    await initialize();
    return _tracks.where((t) => t.isFavorite).toList();
  }

  /// Get the date of the last scan
  Future<DateTime?> getLastScanDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastScanKey);
    if (dateString != null) {
      return DateTime.tryParse(dateString);
    }
    return null;
  }
}

/// Represents a local music "server" configuration
class LocalMusicServer {
  final List<String> directories;

  LocalMusicServer({required this.directories});

  Map<String, dynamic> toJson() => {
    'directories': directories,
    'type': 'local',
  };

  factory LocalMusicServer.fromJson(Map<String, dynamic> json) {
    return LocalMusicServer(
      directories: List<String>.from(json['directories'] ?? []),
    );
  }
}
