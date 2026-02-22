// YouTube Music provider - isolated module.
// All YT-specific code lives here. Do not import this file from lib/services/audio/
// or main.dart. Playback uses the existing audio pipeline (MediaServiceManager
// getStreamUrl/getStreamUrlAsync only).

import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../../models/jellyfin_models.dart';
import '../base_service.dart';

/// YouTube Music as a data-only provider. Supplies catalog (search) and
/// stream URLs. Playback uses the existing UnifiedAudioHandler/AppAudioPlayer.
class YoutubeMusicService implements BaseMediaService {
  YoutubeExplode? _yt;
  YoutubeExplode get _client => _yt ??= YoutubeExplode();

  // Short-lived cache for stream URLs (videoId -> url). TTL not enforced for simplicity.
  final Map<String, String> _streamUrlCache = {};

  @override
  ServerType get serverType => ServerType.youtubeMusic;

  @override
  dynamic get currentServer => _YoutubeMusicServer();

  @override
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    // No auth required for YouTube Music.
    return true;
  }

  @override
  void setServer(String serverUrl) {}

  @override
  Future<bool> validateCredentials() async => true;

  @override
  Future<List<Library>> getLibraries() async {
    return [
      Library(
        id: 'yt_music',
        name: 'YouTube Music',
        collectionType: 'music',
      ),
    ];
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    // YouTube Music doesn't map cleanly to albums in this minimal implementation.
    return [];
  }

  @override
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    return [];
  }

  @override
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    // No "all tracks" for YT; use search instead.
    return [];
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async => [];

  @override
  Future<List<Track>> getStarredTracks() async => [];

  @override
  Future<List<Album>> getStarredAlbums() async => [];

  @override
  Future<List<Artist>> getStarredArtists() async => [];

  @override
  Future<List<Playlist>> getPlaylists() async {
    return [];
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    return [];
  }

  /// Sync getStreamUrl returns cached URL or empty. Use getStreamUrlAsync for resolution.
  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    return _streamUrlCache[trackId] ?? '';
  }

  /// Resolves stream URL via youtube_explode_dart and caches it.
  Future<String> getStreamUrlAsync(String trackId) async {
    final cached = _streamUrlCache[trackId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final manifest = await _client.videos.streamsClient.getManifest(trackId);
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) return '';

      // Prefer highest bitrate (Harmony-style: prefer itag 251/140 for opus/mp4a).
      final sorted = List<AudioOnlyStreamInfo>.from(audioOnly)
        ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      final best = sorted.first;
      final url = best.url.toString();
      _streamUrlCache[trackId] = url;
      return url;
    } catch (_) {
      return '';
    }
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    final u = getStreamUrl(trackId);
    return u.isEmpty ? [] : [u];
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    final u = await getStreamUrlAsync(trackId);
    return u.isEmpty ? [] : [u];
  }

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    // Standard YouTube thumbnail; id is video id.
    return 'https://img.youtube.com/vi/$itemId/mqdefault.jpg';
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    final maxResults = limit ?? 20;
    try {
      final searchList = await _client.search.search(query);
      final tracks = <Track>[];
      for (final video in searchList) {
        if (tracks.length >= maxResults) break;
        final duration = video.duration;
        tracks.add(Track(
          id: video.id.value,
          name: video.title,
          artistName: video.author,
          albumName: null,
          albumId: null,
          playlistItemId: null,
          duration: duration != null ? duration.inMilliseconds : null,
          trackNumber: null,
          imageUrl: video.id.value,
          isFavorite: false,
          playCount: null,
        ));
      }
      return SearchResults(tracks: tracks);
    } catch (_) {
      return SearchResults();
    }
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    return ServerInfo(
      name: 'YouTube Music',
      version: '1',
      id: 'youtube_music',
      type: ServerType.youtubeMusic,
    );
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    return false;
  }

  @override
  void clearAuth() {
    _streamUrlCache.clear();
  }

  void close() {
    _yt?.close();
    _yt = null;
  }
}

class _YoutubeMusicServer {
  // Placeholder for currentServer when type is youtubeMusic.
}
