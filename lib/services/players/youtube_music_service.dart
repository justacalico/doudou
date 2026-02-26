// YouTube Music provider - isolated module.
// All YT-specific code lives here. Do not import this file from lib/services/audio/
// or main.dart. Playback uses the existing audio pipeline (MediaServiceManager
// getStreamUrl/getStreamUrlAsync only).

import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../../models/jellyfin_models.dart';
import '../base_service.dart';

/// A single section on the YouTube Music home page (e.g. "Quick picks", "Playlists").
class YtHomeSection {
  final String title;
  final List<Track> tracks;
  final List<Playlist> playlists;

  YtHomeSection({
    required this.title,
    List<Track>? tracks,
    List<Playlist>? playlists,
  })  : tracks = tracks ?? const [],
        playlists = playlists ?? const [];

  bool get isTracks => tracks.isNotEmpty;
  bool get isPlaylists => playlists.isNotEmpty;
}

/// YouTube Music as a data-only provider. Supplies catalog (search) and
/// stream URLs. Playback uses the existing UnifiedAudioHandler/AppAudioPlayer.
class YoutubeMusicService implements BaseMediaService {
  YoutubeExplode? _yt;
  YoutubeExplode get _client => _yt ??= YoutubeExplode();

  // Short-lived cache for stream URLs (videoId -> url). TTL not enforced for simplicity.
  final Map<String, String> _streamUrlCache = {};

  bool _isUnsupportedMixPlaylist(String id, String title) {
    final normalized = id.toUpperCase();
    final t = title.toLowerCase();
    // Mix/radio playlists are unstable in current implementation.
    if (normalized.startsWith('RD')) return true;
    if (normalized.startsWith('VLRD')) return true;
    if (normalized == 'RDMM') return true;
    if (t.contains(' mix') || t.startsWith('mix ') || t.contains(' radio')) {
      return true;
    }
    return false;
  }

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

  /// Returns home page sections in the style of Harmony Music: Quick picks (tracks)
  /// and horizontal rows of playlists. Uses search to build sections without a full browse API.
  Future<List<YtHomeSection>> getHomeSections() async {
    final sections = <YtHomeSection>[];
    try {
      // Quick picks: mixed music search, take tracks
      final quick = await search('music', limit: 12);
      if (quick.tracks.isNotEmpty) {
        sections.add(YtHomeSection(title: 'Quick picks', tracks: quick.tracks));
      }
      // Community playlists row
      if (quick.playlists.isNotEmpty) {
        sections.add(YtHomeSection(
          title: 'Popular playlists',
          playlists: quick.playlists.take(10).toList(),
        ));
      }
      // Trending / charts-style row
      final trending = await search('trending music', limit: 12);
      if (trending.tracks.isNotEmpty && sections.length < 4) {
        sections.add(YtHomeSection(title: 'Trending', tracks: trending.tracks));
      }
    } catch (_) {
      // Return whatever we have
    }
    return sections;
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    for (final candidateId in _playlistIdCandidates(playlistId)) {
      final tracks = await _getPlaylistTracksSingle(candidateId);
      if (tracks.isNotEmpty) return tracks;
    }
    return [];
  }

  Future<List<Track>> _getPlaylistTracksSingle(String playlistId) async {
    try {
      final tracks = <Track>[];
      await for (final video in _client.playlists.getVideos(playlistId)) {
        tracks.add(Track(
          id: video.id.value,
          name: video.title,
          artistName: video.author,
          albumName: null,
          albumId: null,
          playlistItemId: null,
          duration: video.duration?.inMilliseconds,
          trackNumber: null,
          imageUrl: video.id.value,
          isFavorite: false,
          playCount: null,
        ));
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  List<String> _playlistIdCandidates(String rawId) {
    final candidates = <String>{};
    var id = rawId.trim();

    // Accept links by extracting ?list=
    if (id.startsWith('http://') || id.startsWith('https://')) {
      try {
        final uri = Uri.parse(id);
        final listParam = uri.queryParameters['list'];
        if (listParam != null && listParam.isNotEmpty) {
          id = listParam;
        }
      } catch (_) {}
    }

    if (id.isEmpty) return const [];

    candidates.add(id);

    // YT Music browse IDs often include "VL" prefix.
    if (id.startsWith('VL') && id.length > 2) {
      candidates.add(id.substring(2));
    } else {
      candidates.add('VL$id');
    }

    // Mix variants seen in the wild.
    if (id.startsWith('RDAMVM') && id.length > 6) {
      candidates.add('RD${id.substring(6)}');
    } else if (id.startsWith('RD') && !id.startsWith('RDAMVM')) {
      candidates.add('RDAMVM${id.substring(2)}');
    }

    return candidates.toList(growable: false);
  }

  /// Sync getStreamUrl returns cached URL or empty. Use getStreamUrlAsync for resolution.
  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    return _streamUrlCache[trackId] ?? '';
  }

  /// Resolves stream URL via youtube_explode_dart and caches it.
  /// Prefers a medium bitrate stream (~96–128 kbps) for faster initial buffer and quicker start.
  @override
  Future<String> getStreamUrlAsync(String trackId) async {
    final cached = _streamUrlCache[trackId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final manifest = await _client.videos.streamsClient.getManifest(trackId);
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) return '';

      // Prefer a stream in the 96-160 kbps range for faster start; fallback to highest.
      const int preferredMinBps = 96000;
      const int preferredMaxBps = 160000;
      final inRange = audioOnly.where((s) {
        final bps = s.bitrate.bitsPerSecond;
        return bps >= preferredMinBps && bps <= preferredMaxBps;
      }).toList();
      final list = inRange.isNotEmpty
          ? List<AudioOnlyStreamInfo>.from(inRange)
          : List<AudioOnlyStreamInfo>.from(audioOnly);
      list.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      final best = list.first;
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

  /// Parse YouTube duration string (e.g. "4:21", "1:05:30") to milliseconds.
  static int? _durationStringToMs(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.trim().split(':');
    if (parts.length == 1) {
      final sec = int.tryParse(parts[0]);
      return sec != null ? sec * 1000 : null;
    }
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final sec = int.tryParse(parts[1]);
      if (m != null && sec != null) return (m * 60 + sec) * 1000;
      return null;
    }
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final sec = int.tryParse(parts[2]);
      if (h != null && m != null && sec != null) {
        return (h * 3600 + m * 60 + sec) * 1000;
      }
      return null;
    }
    return null;
  }

  /// Get tracks for an artist (channel uploads when artist.id is channel id, else search by name).
  Future<List<Track>> getArtistTracks(Artist artist, {int limit = 100}) async {
    try {
      if (artist.id.isNotEmpty) {
        final videos = await _client.channels
            .getUploads(artist.id)
            .take(limit)
            .toList();
        return videos
            .map(
              (v) => Track(
                id: v.id.value,
                name: v.title,
                artistName: v.author,
                albumName: null,
                albumId: null,
                playlistItemId: null,
                duration: v.duration?.inMilliseconds,
                trackNumber: null,
                imageUrl: v.id.value,
                isFavorite: false,
                playCount: null,
              ),
            )
            .toList();
      }
      final results = await search(artist.name, limit: limit);
      return results.tracks;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    final maxTracks = limit ?? 25;
    final maxPlaylists = 12;
    final maxArtists = 12;
    try {
      final searchList = await _client.search.searchContent(query);
      final tracks = <Track>[];
      final playlists = <Playlist>[];
      final artists = <Artist>[];
      for (final r in searchList) {
        if (r is SearchVideo) {
          if (tracks.length >= maxTracks) continue;
          tracks.add(Track(
            id: r.id.value,
            name: r.title,
            artistName: r.author,
            albumName: null,
            albumId: null,
            playlistItemId: null,
            duration: _durationStringToMs(r.duration),
            trackNumber: null,
            imageUrl: r.id.value,
            isFavorite: false,
            playCount: null,
          ));
        } else if (r is SearchPlaylist) {
          if (playlists.length >= maxPlaylists) continue;
          if (_isUnsupportedMixPlaylist(r.id.value, r.title)) continue;
          final thumbUrl = r.thumbnails.isNotEmpty
              ? r.thumbnails.first.url.toString()
              : null;
          playlists.add(Playlist(
            id: r.id.value,
            name: r.title,
            imageUrl: thumbUrl,
            trackCount: r.videoCount,
          ));
        } else if (r is SearchChannel) {
          if (artists.length >= maxArtists) continue;
          final thumbUrl = r.thumbnails.isNotEmpty
              ? r.thumbnails.first.url.toString()
              : null;
          artists.add(Artist(
            id: r.id.value,
            name: r.name,
            imageUrl: thumbUrl,
          ));
        }
      }
      return SearchResults(
        tracks: tracks,
        playlists: playlists,
        artists: artists,
      );
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
