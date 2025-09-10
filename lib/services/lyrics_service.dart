import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LyricsLine {
  final Duration timestamp;
  final String text;
  
  LyricsLine({required this.timestamp, required this.text});
}

class LyricsResult {
  final String plainLyrics;
  final List<LyricsLine>? syncedLyrics; 
  final bool hasSyncedLyrics;
  
  LyricsResult({
    required this.plainLyrics,
    this.syncedLyrics,
    this.hasSyncedLyrics = false,
  });
}

class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  
  /// Fetches lyrics for a given track and artist
  /// Returns LyricsResult with both plain and synced lyrics if available
  static Future<LyricsResult?> fetchLyrics(String trackName, String artistName) async {
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
            final plainLyrics = result['plainLyrics']?.toString();
            final syncedLyrics = result['syncedLyrics']?.toString();
            
            if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
              return LyricsResult(
                plainLyrics: plainLyrics,
                syncedLyrics: syncedLyrics != null ? _parseSyncedLyrics(syncedLyrics) : null,
                hasSyncedLyrics: syncedLyrics != null && syncedLyrics.trim().isNotEmpty,
              );
            }
            if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
              return LyricsResult(
                plainLyrics: _cleanSyncedLyrics(syncedLyrics),
                syncedLyrics: _parseSyncedLyrics(syncedLyrics),
                hasSyncedLyrics: true,
              );
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
        final plainLyrics = data['plainLyrics']?.toString();
        final syncedLyrics = data['syncedLyrics']?.toString();
        
        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          return LyricsResult(
            plainLyrics: plainLyrics,
            syncedLyrics: syncedLyrics != null ? _parseSyncedLyrics(syncedLyrics) : null,
            hasSyncedLyrics: syncedLyrics != null && syncedLyrics.trim().isNotEmpty,
          );
        }
        if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
          return LyricsResult(
            plainLyrics: _cleanSyncedLyrics(syncedLyrics),
            syncedLyrics: _parseSyncedLyrics(syncedLyrics),
            hasSyncedLyrics: true,
          );
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
  
  /// Parses synced lyrics into timestamped lines
  static List<LyricsLine> _parseSyncedLyrics(String syncedLyrics) {
    final lines = <LyricsLine>[];
    final lrcPattern = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');
    
    for (final line in syncedLyrics.split('\n')) {
      final match = lrcPattern.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();
        
        if (text.isNotEmpty) {
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: centiseconds * 10,
          );
          
          lines.add(LyricsLine(timestamp: timestamp, text: text));
        }
      }
    }
    
    // Sort by timestamp
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
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
