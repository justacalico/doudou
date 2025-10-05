import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DesktopLyricsLine {
  final Duration time;
  final String text;

  DesktopLyricsLine({required this.time, required this.text});

  factory DesktopLyricsLine.fromLrc(String line) {
    // Parse LRC format: [mm:ss.xx]lyrics text
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');
    final match = timeRegex.firstMatch(line);
    
    if (match != null) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final centiseconds = int.parse(match.group(3)!);
      final text = match.group(4)!.trim();
      
      final duration = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: centiseconds * 10,
      );
      
      return DesktopLyricsLine(time: duration, text: text);
    }
    
    // Handle alternative format [mm:ss]lyrics text (without centiseconds)
    final altTimeRegex = RegExp(r'\[(\d{2}):(\d{2})\](.*)');
    final altMatch = altTimeRegex.firstMatch(line);
    
    if (altMatch != null) {
      final minutes = int.parse(altMatch.group(1)!);
      final seconds = int.parse(altMatch.group(2)!);
      final text = altMatch.group(3)!.trim();
      
      final duration = Duration(
        minutes: minutes,
        seconds: seconds,
      );
      
      return DesktopLyricsLine(time: duration, text: text);
    }
    
    // If parsing fails, return empty line
    return DesktopLyricsLine(time: Duration.zero, text: '');
  }
}

class DesktopLyrics {
  final List<DesktopLyricsLine> syncedLines;
  final String? plainText;
  final bool isTimeSynced;
  final String source;

  DesktopLyrics({
    required this.syncedLines,
    this.plainText,
    required this.isTimeSynced,
    this.source = 'LRCLib',
  });

  factory DesktopLyrics.fromLrc(String lrcContent, {String source = 'LRCLib'}) {
    final lines = <DesktopLyricsLine>[];
    final lrcLines = lrcContent.split('\n');
    
    for (final line in lrcLines) {
      if (line.trim().isNotEmpty && line.contains('[') && line.contains(']')) {
        final lyricLine = DesktopLyricsLine.fromLrc(line);
        if (lyricLine.text.isNotEmpty && lyricLine.text != '') {
          lines.add(lyricLine);
        }
      }
    }
    
    // Sort by time
    lines.sort((a, b) => a.time.compareTo(b.time));
    
    return DesktopLyrics(
      syncedLines: lines,
      isTimeSynced: lines.isNotEmpty,
      source: source,
    );
  }

  factory DesktopLyrics.fromPlainText(String plainText, {String source = 'LRCLib'}) {
    return DesktopLyrics(
      syncedLines: [],
      plainText: plainText,
      isTimeSynced: false,
      source: source,
    );
  }

  // Get the current line index based on playback position
  int getCurrentLineIndex(Duration position) {
    if (syncedLines.isEmpty) return -1;
    
    for (int i = syncedLines.length - 1; i >= 0; i--) {
      if (position >= syncedLines[i].time) {
        return i;
      }
    }
    
    return -1; // Before first line
  }
}

class DesktopLyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  static const Duration _requestTimeout = Duration(seconds: 15);
  
  // Simple cache for lyrics to avoid repeated API calls
  static final Map<String, DesktopLyrics?> _cache = {};
  static const int _maxCacheSize = 50;

  /// Search for lyrics with improved error handling and caching
  static Future<DesktopLyrics?> fetchLyrics({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    // Create cache key
    final cacheKey = _createCacheKey(trackName, artistName, albumName);
    
    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      if (kDebugMode) {
        print('DesktopLyricsService: Cache hit for $cacheKey');
      }
      return _cache[cacheKey];
    }

    try {
      // Clean up search parameters
      final cleanTrack = _cleanSearchString(trackName);
      final cleanArtist = _cleanSearchString(artistName);
      
      if (cleanTrack.isEmpty || cleanArtist.isEmpty) {
        if (kDebugMode) {
          print('DesktopLyricsService: Invalid search parameters');
        }
        return null;
      }

      // Build search parameters
      final queryParams = <String, String>{
        'track_name': cleanTrack,
        'artist_name': cleanArtist,
      };
      
      if (albumName != null && albumName.isNotEmpty) {
        queryParams['album_name'] = _cleanSearchString(albumName);
      }
      
      if (durationSeconds != null && durationSeconds > 0) {
        queryParams['duration'] = durationSeconds.toString();
      }

      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: queryParams);

      if (kDebugMode) {
        print('DesktopLyricsService: Searching lyrics: $uri');
      }

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Doudou/1.0.0 (Desktop Music Player)',
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip, deflate',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isNotEmpty) {
          // Find the best match
          final bestMatch = _findBestMatch(results, cleanTrack, cleanArtist);
          
          if (bestMatch != null) {
            final lyrics = _extractLyricsFromResult(bestMatch);
            _addToCache(cacheKey, lyrics);
            
            if (kDebugMode) {
              print('DesktopLyricsService: Found lyrics - Synced: ${lyrics?.isTimeSynced ?? false}');
            }
            
            return lyrics;
          }
        }
      } else {
        if (kDebugMode) {
          print('DesktopLyricsService: API error ${response.statusCode}: ${response.reasonPhrase}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DesktopLyricsService: Error fetching lyrics: $e');
      }
    }

    // Cache null result to avoid repeated failed requests
    _addToCache(cacheKey, null);
    return null;
  }

  /// Extract lyrics from API result with proper error handling
  static DesktopLyrics? _extractLyricsFromResult(Map<String, dynamic> result) {
    try {
      final syncedLyrics = result['syncedLyrics']?.toString();
      final plainLyrics = result['plainLyrics']?.toString();
      
      // Prefer synced lyrics if available and valid
      if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
        final lyrics = DesktopLyrics.fromLrc(syncedLyrics);
        if (lyrics.syncedLines.isNotEmpty) {
          return lyrics;
        }
      }
      
      // Fall back to plain lyrics
      if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
        return DesktopLyrics.fromPlainText(plainLyrics);
      }
    } catch (e) {
      if (kDebugMode) {
        print('DesktopLyricsService: Error extracting lyrics: $e');
      }
    }
    
    return null;
  }

  /// Find the best matching result from search results
  static Map<String, dynamic>? _findBestMatch(
    List<dynamic> results,
    String cleanTrack,
    String cleanArtist,
  ) {
    if (results.isEmpty) return null;
    
    // Score each result based on similarity
    Map<String, dynamic>? bestMatch;
    double bestScore = 0.0;
    
    for (final result in results) {
      try {
        final resultTrack = _cleanSearchString(result['trackName']?.toString() ?? '');
        final resultArtist = _cleanSearchString(result['artistName']?.toString() ?? '');
        
        // Simple similarity scoring
        double score = 0.0;
        
        // Track name similarity (weighted more heavily)
        if (resultTrack.contains(cleanTrack) || cleanTrack.contains(resultTrack)) {
          score += 0.6;
        } else if (_calculateSimilarity(cleanTrack, resultTrack) > 0.7) {
          score += 0.4;
        }
        
        // Artist name similarity
        if (resultArtist.contains(cleanArtist) || cleanArtist.contains(resultArtist)) {
          score += 0.4;
        } else if (_calculateSimilarity(cleanArtist, resultArtist) > 0.7) {
          score += 0.2;
        }
        
        // Prefer results with synced lyrics
        final syncedLyrics = result['syncedLyrics']?.toString();
        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          score += 0.1;
        }
        
        if (score > bestScore) {
          bestScore = score;
          bestMatch = result;
        }
      } catch (e) {
        // Skip invalid results
        continue;
      }
    }
    
    // Only return if we have a reasonable match
    return bestScore > 0.5 ? bestMatch : results.first;
  }

  /// Simple string similarity calculation
  static double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    
    if (longer.isEmpty) return 1.0;
    
    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  /// Calculate Levenshtein distance
  static int _levenshteinDistance(String a, String b) {
    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Clean search strings for better matching
  static String _cleanSearchString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '') // Remove content in parentheses
        .replaceAll(RegExp(r'\s*\[.*?\]\s*'), '') // Remove content in brackets
        .replaceAll(RegExp(r'\s*-\s*.*$'), '') // Remove everything after dash
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .trim();
  }

  /// Create cache key
  static String _createCacheKey(String track, String artist, String? album) {
    final key = '${_cleanSearchString(artist)}_${_cleanSearchString(track)}';
    return album != null ? '${key}_${_cleanSearchString(album)}' : key;
  }

  /// Add to cache with size management
  static void _addToCache(String key, DesktopLyrics? lyrics) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final keysToRemove = _cache.keys.take(_cache.length - _maxCacheSize + 1);
      for (final keyToRemove in keysToRemove) {
        _cache.remove(keyToRemove);
      }
    }
    _cache[key] = lyrics;
  }

  /// Clear the cache
  static void clearCache() {
    _cache.clear();
    if (kDebugMode) {
      print('DesktopLyricsService: Cache cleared');
    }
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
    };
  }
}