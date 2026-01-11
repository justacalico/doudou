import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/jellyfin_models.dart';
import '../base_service.dart';
import '../album_art_service.dart';

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

  // Map from playlist ID to list of track IDs
  final Map<String, List<String>> _playlistTracks = {};

  // Album art service instance
  final AlbumArtService _albumArtService = AlbumArtService();

  // Whether to fetch online artwork during scan
  bool _fetchOnlineArtwork = true;

  // Supported audio formats
  static const List<String> supportedFormats = [
    '.mp3',
    '.flac',
    '.wav',
    '.ogg',
    '.m4a',
    '.aac',
    '.wma',
    '.opus',
    '.aiff',
    '.alac',
    '.ape',
    '.webm',
  ];

  // Cache keys
  static const String _directoriesKey = 'local_music_directories';
  static const String _cachedTracksKey = 'local_music_cached_tracks';
  static const String _cachedAlbumsKey = 'local_music_cached_albums';
  static const String _cachedArtistsKey = 'local_music_cached_artists';
  static const String _cachedPathsKey = 'local_music_cached_paths';
  static const String _lastScanKey = 'local_music_last_scan';
  static const String _fetchOnlineArtworkKey =
      'local_music_fetch_online_artwork';
  static const String _cachedPlaylistsKey = 'local_music_cached_playlists';
  static const String _playlistTracksKey = 'local_music_playlist_tracks';

  @override
  ServerType get serverType => ServerType.local;

  @override
  dynamic get currentServer => LocalMusicServer(directories: _musicDirectories);

  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  List<String> get musicDirectories => List.unmodifiable(_musicDirectories);
  bool get fetchOnlineArtwork => _fetchOnlineArtwork;
  AlbumArtService get albumArtService => _albumArtService;

  /// Set whether to fetch online artwork during scans
  Future<void> setFetchOnlineArtwork(bool enabled) async {
    _fetchOnlineArtwork = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fetchOnlineArtworkKey, enabled);
  }

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Load saved directories
    final savedDirs = prefs.getStringList(_directoriesKey);
    if (savedDirs != null) {
      _musicDirectories = savedDirs;
    }

    // Load online artwork preference
    _fetchOnlineArtwork = prefs.getBool(_fetchOnlineArtworkKey) ?? true;

    // Load cached data
    await _loadCachedData(prefs);

    _isInitialized = true;
  }

  /// Add a directory to scan for music
  Future<void> addDirectory(String directoryPath) async {
    if (!_musicDirectories.contains(directoryPath)) {
      final dir = Directory(directoryPath);
      if (await dir.exists()) {
        _musicDirectories.add(directoryPath);
        await _saveDirectories();
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
    _tracks.removeWhere(
      (track) => track.id.startsWith(_generatePathHash(directoryPath)),
    );

    _rebuildCollections();
    await _saveCachedData();
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
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File && _isAudioFile(entity.path)) {
              totalFiles++;
            }
          }
        }
      }

      // Second pass: process files
      for (final dirPath in _musicDirectories) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File && _isAudioFile(entity.path)) {
              processedFiles++;
              onProgress?.call(processedFiles, totalFiles);

              try {
                final track = await _createTrackFromFile(entity, dirPath);
                newTracks.add(track);
              } catch (_) {
                // File processing failed
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
    final trackNumberMatch = RegExp(
      r'^(\d+)[\s._-]+(.+)$',
    ).firstMatch(fileName);
    if (trackNumberMatch != null) {
      trackNumber = int.tryParse(trackNumberMatch.group(1)!);
      trackName = trackNumberMatch.group(2)!.trim();
    }

    // Try to extract artist from "Artist - Track" format
    final artistTrackMatch = RegExp(
      r'^([^-]+)\s*-\s*(.+)$',
    ).firstMatch(trackName);
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
      if (potentialArtist.isNotEmpty &&
          !_musicDirectories.contains(grandParentDir)) {
        artistName ??= potentialArtist;
      }
    }

    // Generate album ID based on album folder path
    final albumId = _generatePathHash(parentDir);

    // Store the file path for later retrieval
    _trackIdToPath[trackId] = filePath;

    // Get album art from multiple sources via AlbumArtService
    String? imageUrl = await _albumArtService.getAlbumArt(
      filePath: filePath,
      albumName: albumName,
      artistName: artistName ?? 'Unknown Artist',
      trackName: trackName,
      checkEmbedded: true,
      checkLocal: true,
      checkOnline: _fetchOnlineArtwork,
    );

    // Fall back to simple local art finder if service returns null
    imageUrl ??= _findAlbumArt(parentDir);

    return Track(
      id: trackId,
      name: trackName,
      albumName: albumName,
      artistName: artistName ?? 'Unknown Artist',
      albumId: albumId,
      duration: null, // Would need metadata extraction for this
      trackNumber: trackNumber,
      imageUrl: imageUrl,
      isFavorite: false,
    );
  }

  /// Find album art in a directory
  String? _findAlbumArt(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;

    const artFileNames = [
      'cover.jpg',
      'cover.png',
      'cover.jpeg',
      'folder.jpg',
      'folder.png',
      'folder.jpeg',
      'album.jpg',
      'album.png',
      'album.jpeg',
      'front.jpg',
      'front.png',
      'front.jpeg',
      'art.jpg',
      'art.png',
      'art.jpeg',
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
        artistsMap[artistId] = Artist(id: artistId, name: artistName);
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

    // Save tracks as JSON (using local-specific format to preserve imageUrl)
    final tracksJson = _tracks.map((t) => _trackToLocalJson(t)).toList();
    await prefs.setString(_cachedTracksKey, jsonEncode(tracksJson));

    // Save albums as JSON (using local-specific format to preserve imageUrl)
    final albumsJson = _albums.map((a) => _albumToLocalJson(a)).toList();
    await prefs.setString(_cachedAlbumsKey, jsonEncode(albumsJson));

    // Save artists as JSON (using local-specific format to preserve imageUrl)
    final artistsJson = _artists.map((a) => _artistToLocalJson(a)).toList();
    await prefs.setString(_cachedArtistsKey, jsonEncode(artistsJson));

    // Save track ID to path mapping
    await prefs.setString(_cachedPathsKey, jsonEncode(_trackIdToPath));
  }

  /// Load cached data from preferences
  Future<void> _loadCachedData(SharedPreferences prefs) async {
    try {
      // Load tracks (using local-specific format)
      final tracksString = prefs.getString(_cachedTracksKey);
      if (tracksString != null) {
        final tracksList = jsonDecode(tracksString) as List;
        _tracks = tracksList.map((json) => _trackFromLocalJson(json)).toList();
      }

      // Load albums (using local-specific format)
      final albumsString = prefs.getString(_cachedAlbumsKey);
      if (albumsString != null) {
        final albumsList = jsonDecode(albumsString) as List;
        _albums = albumsList.map((json) => _albumFromLocalJson(json)).toList();
      }

      // Load artists (using local-specific format)
      final artistsString = prefs.getString(_cachedArtistsKey);
      if (artistsString != null) {
        final artistsList = jsonDecode(artistsString) as List;
        _artists = artistsList
            .map((json) => _artistFromLocalJson(json))
            .toList();
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

      await _loadPlaylistData(prefs);
    } catch (_) {
      // Clear corrupted cache
      _tracks = [];
      _albums = [];
      _artists = [];
      _trackIdToPath.clear();
    }
  }

  // ==================== Local-specific JSON serialization ====================

  /// Convert Track to local JSON format (preserves imageUrl as-is)
  Map<String, dynamic> _trackToLocalJson(Track track) {
    return {
      'id': track.id,
      'name': track.name,
      'albumName': track.albumName,
      'artistName': track.artistName,
      'albumId': track.albumId,
      'duration': track.duration,
      'trackNumber': track.trackNumber,
      'imageUrl': track.imageUrl,
      'isFavorite': track.isFavorite,
      'playCount': track.playCount,
    };
  }

  /// Create Track from local JSON format
  Track _trackFromLocalJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] ?? json['Id'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
      albumName: json['albumName'] ?? json['Album'],
      artistName:
          json['artistName'] ??
          (json['Artists'] is List
              ? json['Artists']?.join(', ')
              : json['Artists']),
      albumId: json['albumId'] ?? json['AlbumId'],
      duration:
          json['duration'] ??
          (json['RunTimeTicks'] != null
              ? (json['RunTimeTicks'] / 10000).round()
              : null),
      trackNumber: json['trackNumber'] ?? json['IndexNumber'],
      imageUrl: json['imageUrl'],
      isFavorite:
          json['isFavorite'] ?? json['UserData']?['IsFavorite'] ?? false,
      playCount: json['playCount'] ?? json['UserData']?['PlayCount'],
    );
  }

  /// Convert Album to local JSON format (preserves imageUrl as-is)
  Map<String, dynamic> _albumToLocalJson(Album album) {
    return {
      'id': album.id,
      'name': album.name,
      'artistName': album.artistName,
      'imageUrl': album.imageUrl,
      'year': album.year,
      'isFavorite': album.isFavorite,
    };
  }

  /// Create Album from local JSON format
  Album _albumFromLocalJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] ?? json['Id'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
      artistName: json['artistName'] ?? json['AlbumArtist'],
      imageUrl: json['imageUrl'],
      year: json['year'] ?? json['ProductionYear'],
      isFavorite:
          json['isFavorite'] ?? json['UserData']?['IsFavorite'] ?? false,
    );
  }

  /// Convert Artist to local JSON format (preserves imageUrl as-is)
  Map<String, dynamic> _artistToLocalJson(Artist artist) {
    return {'id': artist.id, 'name': artist.name, 'imageUrl': artist.imageUrl};
  }

  /// Create Artist from local JSON format
  Artist _artistFromLocalJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? json['Id'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }

  // ==================== BaseMediaService Implementation ====================

  @override
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
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
    return _musicDirectories
        .map(
          (dirPath) => Library(
            id: _generatePathHash(dirPath),
            name: path.basename(dirPath),
            collectionType: 'music',
          ),
        )
        .toList();
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
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
          return _tracks.any(
            (track) =>
                track.albumId == album.id &&
                track.id.startsWith(
                  'local_',
                ), // All local tracks start with local_
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
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
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
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    await initialize();

    var tracks = _tracks;

    // Filter by album (parentId)
    if (parentId != null) {
      tracks = tracks.where((t) => t.albumId == parentId).toList();
      // Sort by track number
      tracks.sort(
        (a, b) => (a.trackNumber ?? 999).compareTo(b.trackNumber ?? 999),
      );
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
    await initialize();

    final trackIds = _playlistTracks[playlistId];
    if (trackIds == null || trackIds.isEmpty) {
      return [];
    }

    // Return tracks in playlist order
    final playlistTracks = <Track>[];
    for (final trackId in trackIds) {
      final track = _tracks.firstWhere(
        (t) => t.id == trackId,
        orElse: () => Track(id: '', name: ''),
      );
      if (track.id.isNotEmpty) {
        playlistTracks.add(track);
      }
    }

    return playlistTracks;
  }

  /// Create a new playlist
  Future<Playlist> createPlaylist(String name) async {
    await initialize();

    final playlistId = _generatePathHash(
      'playlist_${DateTime.now().millisecondsSinceEpoch}_$name',
    );

    final playlist = Playlist(id: playlistId, name: name, trackCount: 0);

    _playlists.add(playlist);
    _playlistTracks[playlistId] = [];

    await _savePlaylistData();

    return playlist;
  }

  /// Delete a playlist
  Future<bool> deletePlaylist(String playlistId) async {
    await initialize();

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return false;

    _playlists.removeAt(index);
    _playlistTracks.remove(playlistId);

    await _savePlaylistData();

    return true;
  }

  /// Rename a playlist
  Future<bool> renamePlaylist(String playlistId, String newName) async {
    await initialize();

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return false;

    final oldPlaylist = _playlists[index];
    _playlists[index] = Playlist(
      id: oldPlaylist.id,
      name: newName,
      imageUrl: oldPlaylist.imageUrl,
      trackCount: oldPlaylist.trackCount,
    );

    await _savePlaylistData();

    return true;
  }

  /// Add a track to a playlist
  Future<bool> addTrackToPlaylist(String playlistId, String trackId) async {
    await initialize();

    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex < 0) return false;

    // Verify track exists
    final trackExists = _tracks.any((t) => t.id == trackId);
    if (!trackExists) return false;

    // Add track if not already in playlist
    final trackList = _playlistTracks[playlistId] ?? [];
    if (!trackList.contains(trackId)) {
      trackList.add(trackId);
      _playlistTracks[playlistId] = trackList;

      // Update playlist track count and image
      final playlist = _playlists[playlistIndex];
      final track = _tracks.firstWhere((t) => t.id == trackId);
      _playlists[playlistIndex] = Playlist(
        id: playlist.id,
        name: playlist.name,
        imageUrl: playlist.imageUrl ?? track.imageUrl,
        trackCount: trackList.length,
      );

      await _savePlaylistData();
    }

    return true;
  }

  /// Add multiple tracks to a playlist
  Future<int> addTracksToPlaylist(
    String playlistId,
    List<String> trackIds,
  ) async {
    int addedCount = 0;
    for (final trackId in trackIds) {
      if (await addTrackToPlaylist(playlistId, trackId)) {
        addedCount++;
      }
    }
    return addedCount;
  }

  /// Remove a track from a playlist
  Future<bool> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    await initialize();

    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex < 0) return false;

    final trackList = _playlistTracks[playlistId];
    if (trackList == null || !trackList.contains(trackId)) return false;

    trackList.remove(trackId);

    // Update playlist track count and possibly image
    final playlist = _playlists[playlistIndex];
    String? newImageUrl = playlist.imageUrl;

    // If we removed the track that provided the image, get a new one
    if (trackList.isNotEmpty) {
      final firstTrack = _tracks.firstWhere(
        (t) => t.id == trackList.first,
        orElse: () => Track(id: '', name: ''),
      );
      newImageUrl = firstTrack.imageUrl;
    } else {
      newImageUrl = null;
    }

    _playlists[playlistIndex] = Playlist(
      id: playlist.id,
      name: playlist.name,
      imageUrl: newImageUrl,
      trackCount: trackList.length,
    );

    await _savePlaylistData();

    return true;
  }

  /// Reorder tracks in a playlist
  Future<bool> reorderPlaylistTrack(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    await initialize();

    final trackList = _playlistTracks[playlistId];
    if (trackList == null) return false;

    if (oldIndex < 0 ||
        oldIndex >= trackList.length ||
        newIndex < 0 ||
        newIndex >= trackList.length) {
      return false;
    }

    final trackId = trackList.removeAt(oldIndex);
    trackList.insert(newIndex, trackId);

    await _savePlaylistData();

    return true;
  }

  /// Clear all tracks from a playlist
  Future<bool> clearPlaylist(String playlistId) async {
    await initialize();

    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex < 0) return false;

    _playlistTracks[playlistId] = [];

    final playlist = _playlists[playlistIndex];
    _playlists[playlistIndex] = Playlist(
      id: playlist.id,
      name: playlist.name,
      imageUrl: null,
      trackCount: 0,
    );

    await _savePlaylistData();

    return true;
  }

  /// Save playlist data to preferences
  Future<void> _savePlaylistData() async {
    final prefs = await SharedPreferences.getInstance();

    // Save playlists
    final playlistsJson = _playlists
        .map((p) => _playlistToLocalJson(p))
        .toList();
    await prefs.setString(_cachedPlaylistsKey, jsonEncode(playlistsJson));

    // Save playlist tracks mapping
    await prefs.setString(_playlistTracksKey, jsonEncode(_playlistTracks));
  }

  /// Load playlist data from preferences
  Future<void> _loadPlaylistData(SharedPreferences prefs) async {
    try {
      // Load playlists
      final playlistsString = prefs.getString(_cachedPlaylistsKey);
      if (playlistsString != null) {
        final playlistsList = jsonDecode(playlistsString) as List;
        _playlists.clear();
        _playlists.addAll(
          playlistsList.map((json) => _playlistFromLocalJson(json)),
        );
      }

      // Load playlist tracks mapping
      final tracksString = prefs.getString(_playlistTracksKey);
      if (tracksString != null) {
        final tracksMap = jsonDecode(tracksString) as Map<String, dynamic>;
        _playlistTracks.clear();
        tracksMap.forEach((key, value) {
          _playlistTracks[key] = List<String>.from(value as List);
        });
      }
    } catch (e) {
      // Error loading playlist data
      _playlists.clear();
      _playlistTracks.clear();
    }
  }

  /// Convert Playlist to local JSON format
  Map<String, dynamic> _playlistToLocalJson(Playlist playlist) {
    return {
      'id': playlist.id,
      'name': playlist.name,
      'imageUrl': playlist.imageUrl,
      'trackCount': playlist.trackCount,
    };
  }

  /// Create Playlist from local JSON format
  Playlist _playlistFromLocalJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'],
      trackCount: json['trackCount'] ?? 0,
    );
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
    } catch (_) {
      // Error searching for file
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
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
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
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    await initialize();

    final queryLower = query.toLowerCase();

    final matchingAlbums = _albums
        .where(
          (a) =>
              a.name.toLowerCase().contains(queryLower) ||
              (a.artistName?.toLowerCase().contains(queryLower) ?? false),
        )
        .take(limit ?? 20)
        .toList();

    final matchingArtists = _artists
        .where((a) => a.name.toLowerCase().contains(queryLower))
        .take(limit ?? 20)
        .toList();

    final matchingTracks = _tracks
        .where(
          (t) =>
              t.name.toLowerCase().contains(queryLower) ||
              (t.artistName?.toLowerCase().contains(queryLower) ?? false) ||
              (t.albumName?.toLowerCase().contains(queryLower) ?? false),
        )
        .take(limit ?? 50)
        .toList();

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
    // isFavorite is the CURRENT status - we need to toggle it
    final newFavoriteStatus = !isFavorite;

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
        isFavorite: newFavoriteStatus,
        playCount: track.playCount,
      );
      await _saveCachedData();

      return true;
    }

    return false;
  }

  @override
  void clearAuth() {
    // Clear all in-memory data
    _musicDirectories.clear();
    _albums.clear();
    _artists.clear();
    _tracks.clear();
    _playlists.clear();
    _trackIdToPath.clear();
    _playlistTracks.clear();
    _isInitialized = false;

    // Clear persisted data asynchronously
    _clearPersistedData();
  }

  /// Clear all persisted data from SharedPreferences
  Future<void> _clearPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_directoriesKey);
      await prefs.remove(_cachedTracksKey);
      await prefs.remove(_cachedAlbumsKey);
      await prefs.remove(_cachedArtistsKey);
      await prefs.remove(_cachedPathsKey);
      await prefs.remove(_lastScanKey);
      await prefs.remove(_fetchOnlineArtworkKey);
      await prefs.remove(_cachedPlaylistsKey);
      await prefs.remove(_playlistTracksKey);

      // Also clear artwork cache
      await _albumArtService.clearCachedFiles();
    } catch (_) {
      // Error clearing persisted data
    }
  }

  /// Full logout - clears all data and waits for completion
  Future<void> fullLogout() async {
    clearAuth();
    await _clearPersistedData();
  }

  /// Get tracks for a specific artist
  Future<List<Track>> getArtistTracks(String artistId) async {
    await initialize();

    final artist = _artists.firstWhere(
      (a) => a.id == artistId,
      orElse: () => Artist(id: '', name: ''),
    );

    if (artist.id.isEmpty) return [];

    return _tracks
        .where((t) => t.artistName?.toLowerCase() == artist.name.toLowerCase())
        .toList();
  }

  /// Get albums for a specific artist
  Future<List<Album>> getArtistAlbums(String artistId) async {
    await initialize();

    final artist = _artists.firstWhere(
      (a) => a.id == artistId,
      orElse: () => Artist(id: '', name: ''),
    );

    if (artist.id.isEmpty) return [];

    return _albums
        .where((a) => a.artistName?.toLowerCase() == artist.name.toLowerCase())
        .toList();
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

  /// Refresh artwork for a specific track by fetching from online sources
  Future<String?> refreshTrackArtwork(String trackId) async {
    final trackIndex = _tracks.indexWhere((t) => t.id == trackId);
    if (trackIndex < 0) return null;

    final track = _tracks[trackIndex];
    final filePath = _trackIdToPath[trackId];
    if (filePath == null) return null;

    // Clear any cached artwork for this track
    _albumArtService.clearCache();

    // Fetch new artwork with online lookup enabled
    final newArtwork = await _albumArtService.getAlbumArt(
      filePath: filePath,
      albumName: track.albumName,
      artistName: track.artistName,
      trackName: track.name,
      checkEmbedded: true,
      checkLocal: true,
      checkOnline: true,
    );

    if (newArtwork != null) {
      // Update the track with new artwork
      _tracks[trackIndex] = Track(
        id: track.id,
        name: track.name,
        albumName: track.albumName,
        artistName: track.artistName,
        albumId: track.albumId,
        duration: track.duration,
        trackNumber: track.trackNumber,
        imageUrl: newArtwork,
        isFavorite: track.isFavorite,
        playCount: track.playCount,
      );

      // Update album artwork if this track's album matches
      final albumIndex = _albums.indexWhere((a) => a.id == track.albumId);
      if (albumIndex >= 0) {
        final album = _albums[albumIndex];
        _albums[albumIndex] = Album(
          id: album.id,
          name: album.name,
          artistName: album.artistName,
          imageUrl: newArtwork,
          year: album.year,
        );
      }

      await _saveCachedData();
    }

    return newArtwork;
  }

  /// Refresh artwork for all tracks in an album
  Future<String?> refreshAlbumArtwork(String albumId) async {
    final albumTracks = _tracks.where((t) => t.albumId == albumId).toList();
    if (albumTracks.isEmpty) return null;

    // Try to get artwork from the first track
    final firstTrack = albumTracks.first;
    return refreshTrackArtwork(firstTrack.id);
  }

  /// Search for artwork online and return available options
  Future<List<AlbumArtResult>> searchArtwork({
    required String albumName,
    required String artistName,
    int maxResults = 5,
  }) async {
    return _albumArtService.searchOnlineArtwork(
      albumName: albumName,
      artistName: artistName,
      maxResults: maxResults,
    );
  }

  /// Clear artwork cache
  Future<void> clearArtworkCache() async {
    await _albumArtService.clearCachedFiles();
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    // Local music service already has all tracks in memory
    if (maxTracks != null && _tracks.length > maxTracks) {
      return _tracks.take(maxTracks).toList();
    }
    return _tracks;
  }

  @override
  Future<List<Track>> getStarredTracks() async {
    // Return all favorited local tracks
    return _tracks.where((t) => t.isFavorite).toList();
  }

  @override
  Future<List<Album>> getStarredAlbums() async {
    // Return albums that have favorited tracks (or favorites feature for albums)
    return _albums.where((a) => a.isFavorite).toList();
  }

  @override
  Future<List<Artist>> getStarredArtists() async {
    // Return empty - local service doesn't support artist favorites yet
    return [];
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
