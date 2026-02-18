// YouTube Music service using Harmony-Music's StreamProvider (anandnet/Harmony-Music).
// Ported from Harmony-Music lib/services/stream_service.dart – StreamProvider.fetch().
// Reference: https://github.com/anandnet/Harmony-Music/blob/main/lib/services/stream_service.dart
// This replaces our broken implementation with Harmony's working code.
// Catalog/search uses dart_ytmusic_api; streaming uses Harmony's StreamProvider (youtube_explode_dart only).

import 'dart:convert';

import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Local data (persisted in SharedPreferences, like SoundCloud)
  static const String _prefsFollowedArtistsKey = 'youtube_music_followed_artists';
  static const String _prefsFavoritesKey = 'youtube_music_favorites';
  static const String _prefsPlaylistsKey = 'youtube_music_playlists';
  static const String _prefsPlaylistTracksKey = 'youtube_music_playlist_tracks';
  List<Map<String, dynamic>> _localFollowedArtists = [];
  List<Map<String, dynamic>> _localFavorites = [];
  List<Playlist> _localPlaylists = [];
  final Map<String, List<Map<String, dynamic>>> _localPlaylistTracks = {};
  bool _localDataLoaded = false;

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
    // Like SoundCloud: artists = followed artists (show on home and library)
    return getFollowedArtists();
  }

  Future<void> _loadLocalData() async {
    if (_localDataLoaded) return;
    _localDataLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load followed artists
      final followedJson = prefs.getString(_prefsFollowedArtistsKey);
      if (followedJson != null) {
        final list = jsonDecode(followedJson) as List<dynamic>?;
        _localFollowedArtists = list?.cast<Map<String, dynamic>>() ?? [];
      }
      // Load favorites
      final favJson = prefs.getString(_prefsFavoritesKey);
      if (favJson != null) {
        final list = jsonDecode(favJson) as List<dynamic>?;
        _localFavorites = list?.cast<Map<String, dynamic>>() ?? [];
      }
      // Load playlists
      final playlistsJson = prefs.getString(_prefsPlaylistsKey);
      if (playlistsJson != null) {
        final list = jsonDecode(playlistsJson) as List<dynamic>?;
        _localPlaylists = (list ?? []).map((e) => _playlistFromJson(e as Map<String, dynamic>)).toList();
      }
      // Load playlist tracks
      final tracksJson = prefs.getString(_prefsPlaylistTracksKey);
      if (tracksJson != null) {
        final map = jsonDecode(tracksJson) as Map<String, dynamic>?;
        _localPlaylistTracks.clear();
        if (map != null) {
          for (final entry in map.entries) {
            final list = entry.value as List<dynamic>?;
            _localPlaylistTracks[entry.key] = list?.cast<Map<String, dynamic>>() ?? [];
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[YouTubeMusic] _loadLocalData failed: $e');
    }
  }

  Future<void> _saveFollowedArtists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsFollowedArtistsKey, jsonEncode(_localFollowedArtists));
    } catch (e) {
      if (kDebugMode) print('[YouTubeMusic] _saveFollowedArtists failed: $e');
    }
  }

  Future<void> _saveLocalFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsFavoritesKey, jsonEncode(_localFavorites));
    } catch (e) {
      if (kDebugMode) print('[YouTubeMusic] _saveLocalFavorites failed: $e');
    }
  }

  Future<void> _saveLocalPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsPlaylistsKey, jsonEncode(_localPlaylists.map(_playlistToJson).toList()));
      final tracksMap = <String, List<Map<String, dynamic>>>{};
      for (final e in _localPlaylistTracks.entries) {
        tracksMap[e.key] = e.value;
      }
      await prefs.setString(_prefsPlaylistTracksKey, jsonEncode(tracksMap));
    } catch (e) {
      if (kDebugMode) print('[YouTubeMusic] _saveLocalPlaylists failed: $e');
    }
  }

  static Map<String, dynamic> _playlistToJson(Playlist p) => {
        'id': p.id,
        'name': p.name,
        'imageUrl': p.imageUrl,
        'trackCount': p.trackCount,
      };

  static Playlist _playlistFromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        imageUrl: j['imageUrl'],
        trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
      );

  static Track _trackFromStoredJson(Map<String, dynamic> j) => Track(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        artistName: j['artistName'],
        albumName: j['albumName'],
        albumId: j['albumId'],
        duration: (j['duration'] as num?)?.toInt(),
        imageUrl: j['imageUrl'],
        isFavorite: j['isFavorite'] == true,
      );

  static Map<String, dynamic> _trackToStoredJson(Track t) => {
        'id': t.id,
        'name': t.name,
        'artistName': t.artistName,
        'albumName': t.albumName,
        'albumId': t.albumId,
        'duration': t.duration,
        'imageUrl': t.imageUrl,
        'isFavorite': t.isFavorite,
      };

  /// Follow an artist (like SoundCloud). They appear on home and in library.
  Future<bool> followArtist(Artist artist) async {
    await _loadLocalData();
    if (_localFollowedArtists.any((a) => (a['id'] as String?) == artist.id)) return true;
    _localFollowedArtists.add({
      'id': artist.id,
      'name': artist.name,
      'imageUrl': artist.imageUrl,
    });
    await _saveFollowedArtists();
    return true;
  }

  /// Unfollow an artist
  Future<bool> unfollowArtist(String artistId) async {
    await _loadLocalData();
    _localFollowedArtists.removeWhere((a) => (a['id'] as String?) == artistId);
    await _saveFollowedArtists();
    return true;
  }

  bool isFollowingArtist(String artistId) {
    return _localFollowedArtists.any((a) => (a['id'] as String?) == artistId);
  }

  Future<List<Artist>> getFollowedArtists() async {
    await _loadLocalData();
    return _localFollowedArtists
        .map((a) => Artist(
              id: a['id'] as String? ?? '',
              name: a['name'] as String? ?? 'Unknown Artist',
              imageUrl: a['imageUrl'] as String?,
            ))
        .toList();
  }

  @override
  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    await _loadLocalData(); // Ensure favorites are loaded for isFavorite flag
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
    // Like SoundCloud: return tracks from local storage
    await _loadLocalData();
    final list = _localPlaylistTracks[playlistId];
    if (list == null) return [];
    return list.map((j) {
      final t = _trackFromStoredJson(j);
      return Track(
        id: t.id,
        name: t.name,
        artistName: t.artistName,
        albumName: t.albumName,
        albumId: playlistId,
        duration: t.duration,
        imageUrl: t.imageUrl,
        isFavorite: t.isFavorite,
      );
    }).toList();
  }

  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    await _loadLocalData();
    final max = maxTracks ?? 500;
    final perArtist = (max / 10).ceil().clamp(5, 50);
    final seen = <String>{};
    final merged = <Track>[];
    // Add favorites (like SoundCloud)
    final favorites = await getStarredTracks();
    for (final t in favorites) {
      if (seen.contains(t.id)) continue;
      seen.add(t.id);
      merged.add(t);
    }
    // Add tracks from followed artists
    for (final a in _localFollowedArtists) {
      final id = a['id'] as String?;
      if (id == null || id.isEmpty) continue;
      try {
        final tracks = await getArtistTracks(id, artistName: a['name'] as String?);
        for (final t in tracks.take(perArtist)) {
          if (seen.contains(t.id)) continue;
          seen.add(t.id);
          merged.add(t);
        }
      } catch (_) {}
    }
    // Add tracks from playlists
    for (final entry in _localPlaylistTracks.entries) {
      for (final j in entry.value) {
        final t = _trackFromStoredJson(j);
        if (seen.contains(t.id)) continue;
        seen.add(t.id);
        merged.add(t);
      }
    }
    if (merged.length >= max) return merged.take(max).toList();
    // Fill with search results if needed
    final fromSearch = await getTracks(limit: max - merged.length);
    for (final t in fromSearch) {
      if (seen.contains(t.id)) continue;
      merged.add(t);
    }
    return merged.take(max).toList();
  }

  @override
  Future<List<Track>> getStarredTracks() async {
    await _loadLocalData();
    try {
      return _localFavorites.map(_trackFromStoredJson).toList();
    } catch (e) {
      if (kDebugMode) print('[YouTubeMusic] getStarredTracks failed: $e');
      return [];
    }
  }

  @override
  Future<List<Album>> getStarredAlbums() async => [];

  @override
  Future<List<Artist>> getStarredArtists() async => [];

  @override
  List<String> getAlternativeStreamUrls(String trackId) => [];

  @override
  Future<List<Playlist>> getPlaylists() async {
    // Like SoundCloud: return only local playlists
    await _loadLocalData();
    return List<Playlist>.from(_localPlaylists);
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
  // This method never caches URLs; callers must fetch fresh on each play (YT URLs expire quickly).
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
      print('[YouTubeMusic] getAlternativeStreamUrlsAsync: resolving videoId=$videoId (fresh fetch, no cache)');
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
          print('[YouTubeMusic] StreamProvider: returning ${urls.length} fresh URL(s), best=itag ${highest?.itag ?? "?"} (do not cache)');
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
    await _loadLocalData();
    // isFavorite is CURRENT status - we need to toggle it (remove if currently favorite, add if not)
    if (isFavorite) {
      // Remove from favorites
      _localFavorites.removeWhere((j) => (j['id'] ?? '').toString() == itemId);
      await _saveLocalFavorites();
      return true;
    }
    // Add to favorites: try to fetch track from API to store full snapshot
    if (!_isReady) {
      // If not ready, save minimal favorite locally
      if (_localFavorites.any((j) => (j['id'] ?? '').toString() == itemId)) return true;
      _localFavorites.add({
        'id': itemId,
        'name': 'Unknown',
        'artistName': 'Unknown Artist',
        'albumName': null,
        'albumId': null,
        'duration': null,
        'imageUrl': null,
        'isFavorite': true,
      });
      await _saveLocalFavorites();
      return true;
    }
    try {
      // Try to fetch track details from API
      final track = await _getTrackById(itemId);
      if (track != null) {
        if (_localFavorites.any((j) => (j['id'] ?? '').toString() == track.id)) return true;
        _localFavorites.add(_trackToStoredJson(track));
        await _saveLocalFavorites();
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[YouTubeMusic] toggleFavorite fetch track failed: $e, saving minimal favorite locally');
    }
    // Fallback: save minimal favorite locally
    if (_localFavorites.any((j) => (j['id'] ?? '').toString() == itemId)) return true;
    _localFavorites.add({
      'id': itemId,
      'name': 'Unknown',
      'artistName': 'Unknown Artist',
      'albumName': null,
      'albumId': null,
      'duration': null,
      'imageUrl': null,
      'isFavorite': true,
    });
    await _saveLocalFavorites();
    return true;
  }

  /// Try to fetch a track by ID (for favorites)
  Future<Track?> _getTrackById(String trackId) async {
    if (!_isReady) return null;
    try {
      // Try to get from video ID
      final video = await _ytMusic.getVideo(trackId);
      return _trackFromVideoDetailed(video);
    } catch (_) {
      // Try search as fallback
      try {
        final results = await _ytMusic.searchSongs(trackId);
        if (results.isNotEmpty) {
          return _trackFromSongDetailed(results.first);
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  void clearAuth() {
    _authenticated = false;
    _lastAuthError = null;
    _localFollowedArtists = [];
    _localFavorites = [];
    _localPlaylists = [];
    _localPlaylistTracks.clear();
    _localDataLoaded = false;
  }

  /// Create a local playlist (like SoundCloud)
  Future<Playlist?> createPlaylist(String name) async {
    await _loadLocalData();
    final id = 'ytm_local_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs()}';
    final playlist = Playlist(id: id, name: name, trackCount: 0);
    _localPlaylists.add(playlist);
    _localPlaylistTracks[id] = [];
    await _saveLocalPlaylists();
    return playlist;
  }

  /// Add track to local playlist (like SoundCloud)
  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    await _loadLocalData();
    if (!_localPlaylists.any((p) => p.id == playlistId)) return false;
    final list = _localPlaylistTracks[playlistId] ?? [];
    if (list.any((j) => (j['id'] ?? '').toString() == trackId)) return true;
    // Try to fetch track details
    Track? track;
    if (_isReady) {
      track = await _getTrackById(trackId);
    }
    if (track == null) {
      // Fallback: create minimal track entry
      track = Track(
        id: trackId,
        name: 'Unknown',
        artistName: 'Unknown Artist',
        albumName: null,
        albumId: playlistId,
        duration: null,
        imageUrl: null,
        isFavorite: false,
      );
    } else {
      // Update albumId to playlistId for playlist context
      track = Track(
        id: track.id,
        name: track.name,
        artistName: track.artistName,
        albumName: track.albumName,
        albumId: playlistId,
        duration: track.duration,
        imageUrl: track.imageUrl,
        isFavorite: track.isFavorite,
      );
    }
    list.add(_trackToStoredJson(track));
    _localPlaylistTracks[playlistId] = list;
    final idx = _localPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      final p = _localPlaylists[idx];
      _localPlaylists[idx] = Playlist(
        id: p.id,
        name: p.name,
        imageUrl: p.imageUrl ?? track.imageUrl,
        trackCount: list.length,
      );
    }
    await _saveLocalPlaylists();
    return true;
  }

  /// Remove track from local playlist (like SoundCloud)
  Future<bool> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _loadLocalData();
    final list = _localPlaylistTracks[playlistId];
    if (list == null) return false;
    final before = list.length;
    list.removeWhere((j) => (j['id'] ?? '').toString() == trackId);
    if (list.length == before) return false;
    final idx = _localPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      final p = _localPlaylists[idx];
      _localPlaylists[idx] = Playlist(
        id: p.id,
        name: p.name,
        imageUrl: list.isNotEmpty ? (list.first['imageUrl'] ?? p.imageUrl) : null,
        trackCount: list.length,
      );
    }
    await _saveLocalPlaylists();
    return true;
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

  /// Convert API duration to milliseconds. dart_ytmusic_api returns duration in seconds.
  static int? _durationMs(dynamic raw) {
    if (raw == null) return null;
    final v = raw is int ? raw : int.tryParse(raw.toString());
    if (v == null) return null;
    // Values > 360000 are likely already ms (e.g. 369000 = 6:09); else assume seconds.
    return v > 360000 ? v : v * 1000;
  }

  Track _trackFromSongDetailed(dynamic s) {
    final videoId = s.videoId as String? ?? '';
    final name = s.name as String? ?? 'Unknown';
    final artistName = s.artist?.name as String? ?? 'Unknown Artist';
    final duration = _durationMs(s.duration);
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
      isFavorite: _localFavorites.any((f) => (f['id'] ?? '').toString() == videoId),
    );
  }

  Track _trackFromVideoDetailed(dynamic v) {
    final videoId = v.videoId as String? ?? '';
    final name = v.name as String? ?? 'Unknown';
    final artistName = v.artist?.name as String? ?? 'Unknown Artist';
    final duration = _durationMs(v.duration);
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
      isFavorite: _localFavorites.any((f) => (f['id'] ?? '').toString() == videoId),
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
