import 'dart:convert';
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

  /// In-memory cache: normalized "artist|track" -> result. Successes only so repeat views are instant.
  static final Map<String, LyricsResult> _cache = {};

  static const Duration _timeout = Duration(seconds: 4);

  /// Fetches lyrics for a given track and artist.
  /// Uses cache for repeat requests; tries get (exact) before search; shorter timeouts for faster failure.
  static Future<LyricsResult?> fetchLyrics(
    String trackName,
    String artistName,
  ) async {
    final cleanTrack = _cleanString(trackName);
    final cleanArtist = _cleanString(artistName);
    final cacheKey = '$cleanArtist|$cleanTrack';

    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      // Try get endpoint first (exact match, usually faster)
      final result = await _tryGet(cleanTrack, cleanArtist);
      if (result != null) {
        _cache[cacheKey] = result;
        return result;
      }

      // Fallback to search
      final searchResult = await _trySearch(cleanTrack, cleanArtist);
      if (searchResult != null) {
        _cache[cacheKey] = searchResult;
        return searchResult;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<LyricsResult?> _tryGet(String cleanTrack, String cleanArtist) async {
    final url = Uri.parse('$_baseUrl/get').replace(
      queryParameters: {'track_name': cleanTrack, 'artist_name': cleanArtist},
    );
    final response = await http.get(url).timeout(_timeout);
    if (response.statusCode != 200) return null;
    return _parseGetResponse(response.body);
  }

  static LyricsResult? _parseGetResponse(String body) {
    final data = json.decode(body) as Map<String, dynamic>?;
    if (data == null) return null;
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
    return null;
  }

  static Future<LyricsResult?> _trySearch(String cleanTrack, String cleanArtist) async {
    final url = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {'track_name': cleanTrack, 'artist_name': cleanArtist},
    );
    final response = await http.get(url).timeout(_timeout);
    if (response.statusCode != 200) return null;
    return _parseSearchResponse(response.body);
  }

  static LyricsResult? _parseSearchResponse(String body) {
    final list = json.decode(body);
    if (list is! List || list.isEmpty) return null;
    for (final result in list) {
      if (result is! Map<String, dynamic>) continue;
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
    return null;
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
