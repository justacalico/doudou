import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  
  /// Fetches lyrics for a given track and artist
  /// Returns null if no lyrics are found
  static Future<String?> fetchLyrics(String trackName, String artistName) async {
    try {
      // Clean up the track and artist names for better API matching
      final cleanTrack = _cleanString(trackName);
      final cleanArtist = _cleanString(artistName);
      
      // Try the search endpoint first
      final searchUrl = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {
        'track_name': cleanTrack,
        'artist_name': cleanArtist,
      });
      
      final response = await http.get(searchUrl).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isNotEmpty) {
          // Get the first result that has lyrics
          for (final result in results) {
            if (result['plainLyrics'] != null && 
                result['plainLyrics'].toString().trim().isNotEmpty) {
              return result['plainLyrics'].toString();
            }
            if (result['syncedLyrics'] != null && 
                result['syncedLyrics'].toString().trim().isNotEmpty) {
              // For synced lyrics, remove the timing information
              return _cleanSyncedLyrics(result['syncedLyrics'].toString());
            }
          }
        }
      }
      
      // If search fails, try the get endpoint with exact match
      final getUrl = Uri.parse('$_baseUrl/get')
          .replace(queryParameters: {
        'track_name': cleanTrack,
        'artist_name': cleanArtist,
      });
      
      final getResponse = await http.get(getUrl).timeout(
        const Duration(seconds: 10),
      );
      
      if (getResponse.statusCode == 200) {
        final data = json.decode(getResponse.body);
        
        if (data['plainLyrics'] != null && 
            data['plainLyrics'].toString().trim().isNotEmpty) {
          return data['plainLyrics'].toString();
        }
        if (data['syncedLyrics'] != null && 
            data['syncedLyrics'].toString().trim().isNotEmpty) {
          return _cleanSyncedLyrics(data['syncedLyrics'].toString());
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching lyrics: $e');
      }
      return null;
    }
  }
  
  /// Cleans up synced lyrics by removing timing information
  static String _cleanSyncedLyrics(String syncedLyrics) {
    // Remove timing tags like [00:12.34] from synced lyrics
    return syncedLyrics
        .replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2}\]'), '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .join('\n')
        .trim();
  }
  
  /// Cleans up strings for better API matching
  static String _cleanString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }
}
