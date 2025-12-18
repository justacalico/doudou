import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:audiotags/audiotags.dart';

/// Service for fetching album art from multiple sources
/// Priority:
/// 1. Embedded metadata in audio files
/// 2. Local image files in the same directory
/// 3. Cover Art Archive (via MusicBrainz)
/// 4. Last.fm (if MusicBrainz fails)
class AlbumArtService {
  static final AlbumArtService _instance = AlbumArtService._internal();
  factory AlbumArtService() => _instance;
  AlbumArtService._internal();

  // Cache for fetched artwork URLs
  final Map<String, String?> _artworkCache = {};
  
  // In-memory cache for embedded artwork bytes
  final Map<String, Uint8List?> _embeddedArtCache = {};
  
  // Rate limiting for MusicBrainz API (1 request per second)
  DateTime? _lastMusicBrainzRequest;
  
  // User agent for API requests (required by MusicBrainz)
  static const String _userAgent = 'Doudou/10.0.0 (https://github.com/doudou-music)';
  
  // API endpoints
  static const String _musicBrainzBaseUrl = 'https://musicbrainz.org/ws/2';
  static const String _coverArtArchiveUrl = 'https://coverartarchive.org';
  static const String _lastFmBaseUrl = 'https://ws.audioscrobbler.com/2.0';
  
  // Last.fm API key (public key for album art lookup)
  // Note: For production, consider getting your own API key
  static const String _lastFmApiKey = ''; // Empty means Last.fm won't be used
  
  /// Get album art for a track from all sources
  /// Returns the local file path to the artwork, or null if not found
  Future<String?> getAlbumArt({
    required String filePath,
    String? albumName,
    String? artistName,
    String? trackName,
    bool checkEmbedded = true,
    bool checkLocal = true,
    bool checkOnline = true,
  }) async {
    // Generate cache key
    final cacheKey = _generateCacheKey(filePath, albumName, artistName);
    
    // Check memory cache first
    if (_artworkCache.containsKey(cacheKey)) {
      return _artworkCache[cacheKey];
    }
    
    String? artworkPath;
    
    // 1. Check embedded metadata
    if (checkEmbedded) {
      artworkPath = await _getEmbeddedArtwork(filePath);
      if (artworkPath != null) {
        _artworkCache[cacheKey] = artworkPath;
        return artworkPath;
      }
    }
    
    // 2. Check local image files
    if (checkLocal) {
      artworkPath = _findLocalArtwork(path.dirname(filePath));
      if (artworkPath != null) {
        _artworkCache[cacheKey] = artworkPath;
        return artworkPath;
      }
    }
    
    // 3. Try online sources (only if we have artist/album info)
    if (checkOnline && albumName != null && artistName != null) {
      artworkPath = await _fetchOnlineArtwork(
        albumName: albumName,
        artistName: artistName,
        saveDirectory: path.dirname(filePath),
      );
      if (artworkPath != null) {
        _artworkCache[cacheKey] = artworkPath;
        return artworkPath;
      }
    }
    
    // Cache the null result to avoid repeated lookups
    _artworkCache[cacheKey] = null;
    return null;
  }
  
  /// Get embedded artwork bytes directly (for tracks without saving to file)
  Future<Uint8List?> getEmbeddedArtworkBytes(String filePath) async {
    if (_embeddedArtCache.containsKey(filePath)) {
      return _embeddedArtCache[filePath];
    }
    
    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null && tag.pictures.isNotEmpty) {
        final picture = tag.pictures.first;
        _embeddedArtCache[filePath] = picture.bytes;
        return picture.bytes;
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlbumArtService: Error reading embedded artwork from $filePath: $e');
      }
    }
    
    _embeddedArtCache[filePath] = null;
    return null;
  }
  
  /// Extract embedded artwork and save to a file
  Future<String?> _getEmbeddedArtwork(String filePath) async {
    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null && tag.pictures.isNotEmpty) {
        final picture = tag.pictures.first;
        
        // Determine file extension based on mime type
        String extension = '.jpg';
        if (picture.mimeType != null) {
          final mimeStr = picture.mimeType.toString().toLowerCase();
          if (mimeStr.contains('png')) {
            extension = '.png';
          } else if (mimeStr.contains('webp')) {
            extension = '.webp';
          }
        }
        
        // Save to cache directory
        final cacheDir = await _getArtworkCacheDirectory();
        final hash = md5.convert(utf8.encode(filePath)).toString();
        final artworkFile = File(path.join(cacheDir.path, 'embedded_$hash$extension'));
        
        if (!await artworkFile.exists()) {
          await artworkFile.writeAsBytes(picture.bytes);
          if (kDebugMode) {
            print('AlbumArtService: Extracted embedded artwork to ${artworkFile.path}');
          }
        }
        
        return artworkFile.path;
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlbumArtService: Error reading embedded artwork from $filePath: $e');
      }
    }
    
    return null;
  }
  
  /// Find local artwork in the same directory as the audio file
  String? _findLocalArtwork(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;
    
    const artFileNames = [
      'cover.jpg', 'cover.png', 'cover.jpeg', 'cover.webp',
      'folder.jpg', 'folder.png', 'folder.jpeg', 'folder.webp',
      'album.jpg', 'album.png', 'album.jpeg', 'album.webp',
      'front.jpg', 'front.png', 'front.jpeg', 'front.webp',
      'art.jpg', 'art.png', 'art.jpeg', 'art.webp',
      'artwork.jpg', 'artwork.png', 'artwork.jpeg', 'artwork.webp',
    ];
    
    // Check for common artwork filenames first
    for (final artName in artFileNames) {
      final artFile = File(path.join(dirPath, artName));
      if (artFile.existsSync()) {
        return artFile.path;
      }
    }
    
    // Look for any image file if no standard name found
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
  
  /// Fetch artwork from online sources
  Future<String?> _fetchOnlineArtwork({
    required String albumName,
    required String artistName,
    required String saveDirectory,
  }) async {
    // Clean up artist/album names
    final cleanAlbum = _cleanSearchTerm(albumName);
    final cleanArtist = _cleanSearchTerm(artistName);
    
    if (cleanAlbum.isEmpty || cleanArtist.isEmpty) return null;
    
    // Try Cover Art Archive first (via MusicBrainz)
    String? artworkUrl = await _fetchFromCoverArtArchive(cleanAlbum, cleanArtist);
    
    // Try Last.fm as fallback
    if (artworkUrl == null && _lastFmApiKey.isNotEmpty) {
      artworkUrl = await _fetchFromLastFm(cleanAlbum, cleanArtist);
    }
    
    // Download and save the artwork
    if (artworkUrl != null) {
      return await _downloadAndSaveArtwork(
        url: artworkUrl,
        albumName: cleanAlbum,
        artistName: cleanArtist,
        saveDirectory: saveDirectory,
      );
    }
    
    return null;
  }
  
  /// Fetch cover art URL from Cover Art Archive via MusicBrainz
  Future<String?> _fetchFromCoverArtArchive(String albumName, String artistName) async {
    try {
      // Rate limit: 1 request per second
      await _respectRateLimit();
      
      // Search MusicBrainz for the release
      final searchQuery = Uri.encodeQueryComponent('release:"$albumName" AND artist:"$artistName"');
      final searchUrl = '$_musicBrainzBaseUrl/release/?query=$searchQuery&limit=1&fmt=json';
      
      final searchResponse = await http.get(
        Uri.parse(searchUrl),
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );
      
      if (searchResponse.statusCode != 200) {
        if (kDebugMode) {
          print('AlbumArtService: MusicBrainz search failed with ${searchResponse.statusCode}');
        }
        return null;
      }
      
      final searchData = jsonDecode(searchResponse.body);
      final releases = searchData['releases'] as List?;
      
      if (releases == null || releases.isEmpty) {
        if (kDebugMode) {
          print('AlbumArtService: No MusicBrainz release found for "$albumName" by "$artistName"');
        }
        return null;
      }
      
      final releaseId = releases[0]['id'] as String?;
      if (releaseId == null) return null;
      
      // Fetch cover art from Cover Art Archive
      await _respectRateLimit();
      
      final coverArtUrl = '$_coverArtArchiveUrl/release/$releaseId';
      final coverResponse = await http.get(
        Uri.parse(coverArtUrl),
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );
      
      if (coverResponse.statusCode == 200) {
        final coverData = jsonDecode(coverResponse.body);
        final images = coverData['images'] as List?;
        
        if (images != null && images.isNotEmpty) {
          // Find the front cover
          for (final image in images) {
            if (image['front'] == true) {
              // Return 500px thumbnail for better performance
              final thumbnails = image['thumbnails'] as Map?;
              if (thumbnails != null) {
                return thumbnails['500'] ?? thumbnails['large'] ?? image['image'];
              }
              return image['image'] as String?;
            }
          }
          // If no front cover, return the first image
          final firstImage = images[0];
          final thumbnails = firstImage['thumbnails'] as Map?;
          if (thumbnails != null) {
            return thumbnails['500'] ?? thumbnails['large'] ?? firstImage['image'];
          }
          return firstImage['image'] as String?;
        }
      } else if (coverResponse.statusCode == 307) {
        // Follow redirect for direct front cover
        final frontUrl = '$_coverArtArchiveUrl/release/$releaseId/front-500';
        return frontUrl;
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlbumArtService: Error fetching from Cover Art Archive: $e');
      }
    }
    
    return null;
  }
  
  /// Fetch cover art URL from Last.fm
  Future<String?> _fetchFromLastFm(String albumName, String artistName) async {
    if (_lastFmApiKey.isEmpty) return null;
    
    try {
      final url = '$_lastFmBaseUrl/?method=album.getinfo'
          '&api_key=$_lastFmApiKey'
          '&artist=${Uri.encodeQueryComponent(artistName)}'
          '&album=${Uri.encodeQueryComponent(albumName)}'
          '&format=json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final album = data['album'];
        if (album != null) {
          final images = album['image'] as List?;
          if (images != null && images.isNotEmpty) {
            // Get the largest image (last in the list)
            for (final image in images.reversed) {
              final url = image['#text'] as String?;
              if (url != null && url.isNotEmpty) {
                return url;
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlbumArtService: Error fetching from Last.fm: $e');
      }
    }
    
    return null;
  }
  
  /// Download artwork from URL and save to local file
  Future<String?> _downloadAndSaveArtwork({
    required String url,
    required String albumName,
    required String artistName,
    required String saveDirectory,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      
      if (response.statusCode == 200) {
        // Determine file extension from content type or URL
        String extension = '.jpg';
        final contentType = response.headers['content-type'];
        if (contentType != null) {
          if (contentType.contains('png')) {
            extension = '.png';
          } else if (contentType.contains('webp')) {
            extension = '.webp';
          }
        } else if (url.toLowerCase().contains('.png')) {
          extension = '.png';
        } else if (url.toLowerCase().contains('.webp')) {
          extension = '.webp';
        }
        
        // Save to album directory as cover.jpg/png
        final coverFile = File(path.join(saveDirectory, 'cover$extension'));
        
        // Only save if directory is writable
        try {
          await coverFile.writeAsBytes(response.bodyBytes);
          if (kDebugMode) {
            print('AlbumArtService: Downloaded artwork to ${coverFile.path}');
          }
          return coverFile.path;
        } catch (e) {
          // If we can't write to album directory, save to cache
          final cacheDir = await _getArtworkCacheDirectory();
          final hash = md5.convert(utf8.encode('$artistName-$albumName')).toString();
          final cacheFile = File(path.join(cacheDir.path, 'online_$hash$extension'));
          await cacheFile.writeAsBytes(response.bodyBytes);
          if (kDebugMode) {
            print('AlbumArtService: Downloaded artwork to cache ${cacheFile.path}');
          }
          return cacheFile.path;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlbumArtService: Error downloading artwork from $url: $e');
      }
    }
    
    return null;
  }
  
  /// Get or create the artwork cache directory
  Future<Directory> _getArtworkCacheDirectory() async {
    final appDir = await getApplicationCacheDirectory();
    final cacheDir = Directory(path.join(appDir.path, 'album_art_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }
  
  /// Clean search terms for API queries
  String _cleanSearchTerm(String term) {
    return term
        .replaceAll(RegExp(r'\[.*?\]'), '') // Remove brackets and contents
        .replaceAll(RegExp(r'\(.*?\)'), '') // Remove parentheses and contents
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special characters
        .trim();
  }
  
  /// Generate a cache key for the artwork
  String _generateCacheKey(String filePath, String? albumName, String? artistName) {
    final key = '$filePath-${albumName ?? ''}-${artistName ?? ''}';
    return md5.convert(utf8.encode(key)).toString();
  }
  
  /// Respect MusicBrainz rate limit (1 request per second)
  Future<void> _respectRateLimit() async {
    if (_lastMusicBrainzRequest != null) {
      final elapsed = DateTime.now().difference(_lastMusicBrainzRequest!);
      if (elapsed.inMilliseconds < 1100) {
        await Future.delayed(Duration(milliseconds: 1100 - elapsed.inMilliseconds));
      }
    }
    _lastMusicBrainzRequest = DateTime.now();
  }
  
  /// Clear the in-memory caches
  void clearCache() {
    _artworkCache.clear();
    _embeddedArtCache.clear();
  }
  
  /// Delete all cached artwork files
  Future<void> clearCachedFiles() async {
    try {
      final cacheDir = await _getArtworkCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      clearCache();
    } catch (e) {
      if (kDebugMode) {
        print('AlbumArtService: Error clearing cache: $e');
      }
    }
  }
  
  /// Batch fetch artwork for multiple tracks (respects rate limits)
  Future<Map<String, String?>> batchGetAlbumArt(List<AlbumArtRequest> requests) async {
    final results = <String, String?>{};
    
    for (final request in requests) {
      final artwork = await getAlbumArt(
        filePath: request.filePath,
        albumName: request.albumName,
        artistName: request.artistName,
        trackName: request.trackName,
        checkOnline: request.checkOnline,
      );
      results[request.filePath] = artwork;
    }
    
    return results;
  }
  
  /// Search for album art online only (useful for manual artwork search)
  Future<List<AlbumArtResult>> searchOnlineArtwork({
    required String albumName,
    required String artistName,
    int maxResults = 5,
  }) async {
    final results = <AlbumArtResult>[];
    
    try {
      // Search MusicBrainz for multiple releases
      await _respectRateLimit();
      
      final cleanAlbum = _cleanSearchTerm(albumName);
      final cleanArtist = _cleanSearchTerm(artistName);
      
      final searchQuery = Uri.encodeQueryComponent('release:"$cleanAlbum" AND artist:"$cleanArtist"');
      final searchUrl = '$_musicBrainzBaseUrl/release/?query=$searchQuery&limit=$maxResults&fmt=json';
      
      final searchResponse = await http.get(
        Uri.parse(searchUrl),
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );
      
      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);
        final releases = searchData['releases'] as List? ?? [];
        
        for (final release in releases) {
          final releaseId = release['id'] as String?;
          if (releaseId == null) continue;
          
          await _respectRateLimit();
          
          final coverArtUrl = '$_coverArtArchiveUrl/release/$releaseId';
          final coverResponse = await http.get(
            Uri.parse(coverArtUrl),
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          );
          
          if (coverResponse.statusCode == 200) {
            final coverData = jsonDecode(coverResponse.body);
            final images = coverData['images'] as List?;
            
            if (images != null && images.isNotEmpty) {
              for (final image in images) {
                if (image['front'] == true) {
                  final thumbnails = image['thumbnails'] as Map?;
                  results.add(AlbumArtResult(
                    releaseId: releaseId,
                    releaseName: release['title'] ?? albumName,
                    artistName: (release['artist-credit'] as List?)?.firstOrNull?['name'] ?? artistName,
                    thumbnailUrl: thumbnails?['250'] ?? thumbnails?['small'],
                    fullUrl: thumbnails?['1200'] ?? image['image'],
                    source: 'Cover Art Archive',
                  ));
                  break;
                }
              }
            }
          }
          
          if (results.length >= maxResults) break;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlbumArtService: Error searching online artwork: $e');
      }
    }
    
    return results;
  }
}

/// Request class for batch artwork fetching
class AlbumArtRequest {
  final String filePath;
  final String? albumName;
  final String? artistName;
  final String? trackName;
  final bool checkOnline;
  
  AlbumArtRequest({
    required this.filePath,
    this.albumName,
    this.artistName,
    this.trackName,
    this.checkOnline = true,
  });
}

/// Result class for online artwork search
class AlbumArtResult {
  final String releaseId;
  final String releaseName;
  final String artistName;
  final String? thumbnailUrl;
  final String? fullUrl;
  final String source;
  
  AlbumArtResult({
    required this.releaseId,
    required this.releaseName,
    required this.artistName,
    this.thumbnailUrl,
    this.fullUrl,
    required this.source,
  });
}
