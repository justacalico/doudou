// YouTube Music service using Harmony-Music's StreamProvider (anandnet/Harmony-Music).
// Ported from Harmony-Music lib/services/stream_service.dart – StreamProvider.fetch().
// Reference: https://github.com/anandnet/Harmony-Music/blob/main/lib/services/stream_service.dart
// This replaces our broken implementation with Harmony's working code.
// Catalog/search uses dart_ytmusic_api; streaming uses Harmony's StreamProvider (youtube_explode_dart only).

import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:flutter/foundation.dart';

import '../../models/jellyfin_models.dart';
import '../base_service.dart';
import 'harmony_stream_provider.dart';

/// YouTube Music service using Harmony-Music's StreamProvider for streaming.
/// Ported from Harmony-Music lib/services/stream_service.dart.
/// Does not work on web (dart_ytmusic_api does not work on web).
class YouTubeMusicService implements BaseMediaService {
  static const String _serverUrl = 'https://music.youtube.com';

  final YTMusic _ytMusic = YTMusic();
  bool _authenticated = false;
  String? _lastAuthError;

  @override
  ServerType get serverType => ServerType.youtubeMusic;

  String? get lastAuthError => _lastAuthError;

  @override
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    if (kIsWeb) {
      _lastAuthError = 'YouTube Music is not available on web.';
      return false;
    }
    _lastAuthError = null;
    final cookies = credential.trim();
    try {
      if (cookies.isEmpty) {
        // No login: initialize without cookies (Harmony-Music style; no auth required).
        // Reference: Harmony-Music lib/services/stream_service.dart – StreamProvider.fetch() works without auth.
        await _ytMusic.initialize();
      } else {
        await _ytMusic.initialize(
          cookies: cookies,
          gl: 'US',
          hl: 'en',
        );
      }
      _authenticated = true;
      return true;
    } catch (e) {
      _lastAuthError = e.toString();
      if (kDebugMode) {
        print('[YouTubeMusic] authenticate failed: $e');
      }
      return false;
    }
  }

  @override
  void setServer(String serverUrl) {
    // No-op; we use fixed music.youtube.com
  }

  @override
  Future<bool> validateCredentials() async {
    if (kIsWeb || !_authenticated) return false;
    try {
      await _ytMusic.getHomeSections();
      return true;
    } catch (_) {
      // Without cookies, home sections may fail; still consider "valid" for no-login mode.
      return true;
    }
  }

  /// Ready when not on web and service is connected (with or without cookies).
  bool get _isReady => !kIsWeb && _authenticated;

  @override
  dynamic get currentServer => {
        'url': _serverUrl,
        'authenticated': _authenticated,
      };

  @override
  Future<List<Library>> getLibraries() async {
    return [
      Library(
        id: 'youtube_music',
        name: 'YouTube Music',
        collectionType: 'music',
        imageUrl: null,
      ),
    ];
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    if (!_isReady) return [];
    try {
      final results = await _ytMusic.searchAlbums('album');
      final list = results.take(limit ?? 50).map((a) => _albumFromDetailed(a)).toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    if (!_isReady) return [];
    try {
      final results = await _ytMusic.searchArtists('artist');
      return results.take(limit ?? 50).map((a) => _artistFromDetailed(a)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    if (!_isReady) return [];
    if (parentId != null && parentId.isNotEmpty) {
      try {
        final album = await _ytMusic.getAlbum(parentId);
        if (album.songs.isNotEmpty) {
          return album.songs.map((s) => _trackFromSongDetailed(s)).toList();
        }
      } catch (_) {}
      return getPlaylistTracks(parentId);
    }
    try {
      final results = await _ytMusic.searchSongs('music');
      return results.take(limit ?? 50).map((s) => _trackFromSongDetailed(s)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    if (!_isReady) return [];
    try {
      final videos = await _ytMusic.getPlaylistVideos(playlistId);
      return videos.map((v) => _trackFromVideoDetailed(v)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    return getTracks(limit: maxTracks ?? 10000);
  }

  @override
  Future<List<Track>> getStarredTracks() async => [];

  @override
  Future<List<Album>> getStarredAlbums() async => [];

  @override
  Future<List<Artist>> getStarredArtists() async => [];

  @override
  List<String> getAlternativeStreamUrls(String trackId) => [];

  @override
  Future<List<Playlist>> getPlaylists() async {
    if (!_isReady) return [];
    try {
      final fromHome = await _getPlaylistsFromHomeSections();
      if (fromHome.isNotEmpty) return fromHome;
      final results = await _ytMusic.searchPlaylists('playlist');
      return results.take(50).map((p) => _playlistFromDetailed(p)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Home sections (recommendations, quick picks, etc.) for the logged-in user.
  Future<List<YTMHomeSection>> getHomeSectionsForApp() async {
    if (!_isReady) return [];
    try {
      final sections = await _ytMusic.getHomeSections();
      return sections
          .map((s) => _sectionFromApiSection(s))
          .where((s) => !s.isEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('[YouTubeMusic] getHomeSectionsForApp failed: $e');
      }
      return [];
    }
  }

  bool _hasAlbumId(dynamic item) {
    try {
      return (item.albumId as String? ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _hasPlaylistId(dynamic item) {
    try {
      return (item.playlistId as String? ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _hasVideoId(dynamic item) {
    try {
      return (item.videoId as String? ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  YTMHomeSection _sectionFromApiSection(dynamic section) {
    final title = (section.title as String?) ?? '';
    final contents = section.contents as List<dynamic>? ?? [];
    final albums = <Album>[];
    final playlists = <Playlist>[];
    final tracks = <Track>[];
    for (final item in contents) {
      try {
        if (_hasAlbumId(item)) {
          albums.add(_albumFromDetailed(item));
        } else if (_hasPlaylistId(item)) {
          playlists.add(_playlistFromDetailed(item));
        } else if (_hasVideoId(item)) {
          tracks.add(_trackFromSongDetailed(item));
        }
      } catch (_) {}
    }
    return YTMHomeSection(title: title, albums: albums, playlists: playlists, tracks: tracks);
  }

  Future<List<Playlist>> _getPlaylistsFromHomeSections() async {
    try {
      final sections = await _ytMusic.getHomeSections();
      final seen = <String>{};
      final list = <Playlist>[];
      for (final section in sections) {
        final contents = section.contents as List<dynamic>? ?? [];
        for (final item in contents) {
          if (!_hasPlaylistId(item)) continue;
          final p = _playlistFromDetailed(item);
          if (seen.add(p.id)) list.add(p);
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    return '';
  }

  /// Harmony-Music uses AudioSource.uri() WITHOUT headers – just_audio handles googlevideo.com natively.
  /// Reference: Harmony-Music lib/services/audio_handler.dart – AudioSource.uri(Uri.tryParse(url)!) with no headers.
  /// MPV's user-agent is set via mpv.conf (PlatformAudioConfig), so no headers needed in AudioSource.
  static Map<String, String>? getStreamHeaders(String url) {
    // No headers – Harmony-style (just_audio + MPV handle googlevideo.com natively)
    return null;
  }

  // ---------------------------------------------------------------------------
  // Stream URL resolution – Harmony-Music StreamProvider.fetch() ONLY.
  // Reference: Harmony-Music lib/services/stream_service.dart – StreamProvider.fetch(videoId).
  // Harmony uses ONLY youtube_explode_dart; no Piped, no Invidious, no InnerTube.
  // ---------------------------------------------------------------------------

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(
    String trackId, {
    bool requireAuth = true,
  }) async {
    if (requireAuth && (kIsWeb || !_authenticated)) return [];
    final videoId = _normalizeVideoId(trackId);
    if (videoId.isEmpty) {
      if (kDebugMode) {
        print('[YouTubeMusic] getAlternativeStreamUrlsAsync: empty videoId for trackId=$trackId');
      }
      return [];
    }

    if (kDebugMode) {
      print('[YouTubeMusic] getAlternativeStreamUrlsAsync: resolving videoId=$videoId using Harmony StreamProvider');
    }

    // Use Harmony-Music's StreamProvider.fetch() – their working method.
    // Reference: Harmony-Music lib/services/stream_service.dart – StreamProvider.fetch(videoId).
    try {
      final streamInfo = await HarmonyStreamProvider.fetch(videoId);
      if (!streamInfo.playable) {
        if (kDebugMode) {
          print('[YouTubeMusic] StreamProvider: not playable: ${streamInfo.statusMSG}');
        }
        return [];
      }

      // Harmony uses highestQualityAudio (itag 251/140) as primary, then fallbacks.
      // Reference: Harmony-Music lib/services/stream_service.dart – highestQualityAudio getter.
      final urls = <String>[];
      final highest = streamInfo.highestQualityAudio;
      if (highest != null) {
        urls.add(highest.url);
      }
      // Add all other audio formats as fallbacks (Harmony's audioFormats list).
      if (streamInfo.audioFormats != null) {
        for (final audio in streamInfo.audioFormats!) {
          if (audio.url != highest?.url && !urls.contains(audio.url)) {
            urls.add(audio.url);
          }
        }
      }

      if (urls.isNotEmpty) {
        if (kDebugMode) {
          print('[YouTubeMusic] StreamProvider: ${urls.length} URL(s), best=itag ${highest?.itag ?? "?"}');
        }
        return urls;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[YouTubeMusic] StreamProvider.fetch failed: $e');
      }
    }

    if (kDebugMode) {
      print('[YouTubeMusic] StreamProvider: no URLs for videoId=$videoId');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _normalizeVideoId(String trackId) {
    if (trackId.startsWith('youtube:') || trackId.startsWith('yt:')) {
      return trackId.replaceFirst(RegExp(r'^youtube:|^yt:'), '');
    }
    return trackId;
  }

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    if (itemId.isEmpty) return '';
    if (itemId.startsWith('http://') || itemId.startsWith('https://')) {
      return itemId;
    }
    return '';
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    if (!_isReady) return SearchResults();
    final limitVal = (limit ?? 25).clamp(1, 50);
    try {
      final tracks = <Track>[];
      final albums = <Album>[];
      final artists = <Artist>[];
      final playlists = <Playlist>[];

      if (includeItemTypes == null ||
          includeItemTypes.isEmpty ||
          includeItemTypes.contains('Audio') ||
          includeItemTypes.contains('Song')) {
        final songs = await _ytMusic.searchSongs(query);
        for (final s in songs.take(limitVal)) {
          tracks.add(_trackFromSongDetailed(s));
        }
      }
      if (includeItemTypes == null ||
          includeItemTypes.isEmpty ||
          includeItemTypes.contains('Album')) {
        final albumsRes = await _ytMusic.searchAlbums(query);
        for (final a in albumsRes.take(limitVal)) {
          albums.add(_albumFromDetailed(a));
        }
      }
      if (includeItemTypes == null ||
          includeItemTypes.isEmpty ||
          includeItemTypes.contains('Artist')) {
        final artistsRes = await _ytMusic.searchArtists(query);
        for (final a in artistsRes.take(limitVal)) {
          artists.add(_artistFromDetailed(a));
        }
      }
      if (includeItemTypes == null ||
          includeItemTypes.isEmpty ||
          includeItemTypes.contains('Playlist')) {
        final playlistsRes = await _ytMusic.searchPlaylists(query);
        for (final p in playlistsRes.take(limitVal)) {
          playlists.add(_playlistFromDetailed(p));
        }
      }

      return SearchResults(
        tracks: tracks,
        albums: albums,
        artists: artists,
        playlists: playlists,
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
    _authenticated = false;
    _lastAuthError = null;
  }

  Future<List<Track>> getArtistTracks(String artistId, {String? artistName}) async {
    if (!_isReady) return [];
    try {
      final songs = await _ytMusic.getArtistSongs(artistId);
      return songs.map((s) => _trackFromSongDetailed(s)).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Mapping from dart_ytmusic_api types to jellyfin_models ---

  static String _thumbUrl(dynamic thumbnails) {
    if (thumbnails == null || thumbnails is! List || thumbnails.isEmpty) return '';
    try {
      final last = thumbnails.last;
      if (last is Map && last['url'] != null) return last['url'] as String;
      final url = (last as dynamic).url;
      if (url is String) return url;
    } catch (_) {}
    return '';
  }

  Track _trackFromSongDetailed(dynamic s) {
    final videoId = s.videoId as String? ?? '';
    final name = s.name as String? ?? 'Unknown';
    final artistName = s.artist?.name as String? ?? 'Unknown Artist';
    final duration = s.duration as int?;
    final thumbnails = s.thumbnails;
    final imageUrl = _thumbUrl(thumbnails);
    return Track(
      id: videoId,
      name: name,
      artistName: artistName,
      albumName: s.album?.name,
      albumId: null,
      duration: duration,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      isFavorite: false,
    );
  }

  Track _trackFromVideoDetailed(dynamic v) {
    final videoId = v.videoId as String? ?? '';
    final name = v.name as String? ?? 'Unknown';
    final artistName = v.artist?.name as String? ?? 'Unknown Artist';
    final duration = v.duration as int?;
    final thumbnails = v.thumbnails;
    final imageUrl = _thumbUrl(thumbnails);
    return Track(
      id: videoId,
      name: name,
      artistName: artistName,
      albumName: null,
      albumId: null,
      duration: duration,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      isFavorite: false,
    );
  }

  Album _albumFromDetailed(dynamic a) {
    final albumId = a.albumId as String? ?? '';
    final name = a.name as String? ?? 'Unknown';
    final artistName = a.artist?.name as String?;
    final thumbnails = a.thumbnails;
    final imageUrl = _thumbUrl(thumbnails);
    return Album(
      id: albumId,
      name: name,
      artistName: artistName,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      year: a.year as int?,
      isFavorite: false,
    );
  }

  Artist _artistFromDetailed(dynamic a) {
    final artistId = a.artistId as String? ?? '';
    final name = a.name as String? ?? 'Unknown';
    final thumbnails = a.thumbnails;
    final imageUrl = _thumbUrl(thumbnails);
    return Artist(
      id: artistId,
      name: name,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
    );
  }

  Playlist _playlistFromDetailed(dynamic p) {
    final playlistId = p.playlistId as String? ?? '';
    final name = p.name as String? ?? 'Unknown';
    final thumbnails = p.thumbnails;
    final imageUrl = _thumbUrl(thumbnails);
    return Playlist(
      id: playlistId,
      name: name,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      trackCount: 0,
    );
  }
}
