// YouTube Music backend reference: OpenTune (Arturo254/OpenTune) innertube/ only.
// No-login streaming approach referenced from Harmony-Music (anandnet/Harmony-Music)
// lib/services/stream_service.dart — fetch streams via youtube_explode_dart without auth.
// We use dart_ytmusic_api for catalog; stream URLs use Harmony-Music stack (youtube_explode_dart first,
// then Piped, Invidious, InnerTube). Auth is optional (cookie-based when set).
// Disabled on web (dart_ytmusic_api does not work on web).

import 'dart:convert';

import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../../models/jellyfin_models.dart';
import '../base_service.dart';
import 'innertube_client.dart';

/// YouTube Music service using dart_ytmusic_api (catalog) and InnerTube (streams).
/// Does not work on web — authenticate() returns false when kIsWeb.
class YouTubeMusicService implements BaseMediaService {
  static const String _serverUrl = 'https://music.youtube.com';

  final YTMusic _ytMusic = YTMusic();
  late final InnerTubeClient _innerTube = InnerTubeClient();
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
        // No login: initialize without cookies (Harmony-Music-style; no auth required).
        // Reference: Harmony-Music lib/services/stream_service.dart — streams via youtube_explode without auth.
        await _ytMusic.initialize();
        _innerTube.cookie = null;
      } else {
        await _ytMusic.initialize(
          cookies: cookies,
          gl: 'US',
          hl: 'en',
        );
        _innerTube.cookie = cookies;
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

  /// HTTP headers for googlevideo.com (403 without browser-like User-Agent).
  static const Map<String, String> _streamHttpHeaders = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'https://www.youtube.com',
    'Referer': 'https://www.youtube.com/',
  };

  static Map<String, String>? getStreamHeaders(String url) {
    if (url.contains('googlevideo.com')) return Map.unmodifiable(_streamHttpHeaders);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Piped API instances – proxied stream URLs, no custom headers needed.
  // Tested Feb 2026: most public instances are down (502/521/DNS fail).
  // Keep a small list; user can set custom instance in Settings.
  // ---------------------------------------------------------------------------

  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',   // official, CDN
    'https://pipedapi.leptons.xyz',
    'https://pipedapi.tokhmi.xyz',
    'https://pipedapi.adminforge.de',
  ];

  // ---------------------------------------------------------------------------
  // Invidious API instances – local=true proxies streams through the instance.
  // ---------------------------------------------------------------------------

  static const List<String> _invidiousInstances = [
    'https://inv.nadeko.net',
    'https://yewtu.be',
    'https://vid.puffyan.us',
    'https://invidious.nerdvpn.de',
  ];

  static const String _prefKeyInvidiousInstance = 'youtube_music_invidious_instance';
  static const String _prefKeyPipedInstance = 'youtube_music_piped_instance';

  // ---------------------------------------------------------------------------
  // Stream URL resolution – prefer PROXIED URLs first (Piped, Invidious) so desktop
  // MPV can open them without googlevideo.com (which fails with "Failed to open").
  // Then yt_explode (Harmony-Music stream_service.dart), then InnerTube.
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
      print('[YouTubeMusic] getAlternativeStreamUrlsAsync: resolving videoId=$videoId');
    }

    // ── 1) Piped – proxied URLs (no googlevideo.com), no custom headers; works with MPV on desktop ──
    try {
      final piped = await _getPipedStreamUrls(videoId);
      if (piped.isNotEmpty) {
        if (kDebugMode) {
          print('[YouTubeMusic] Piped: ${piped.length} URL(s) (proxied, MPV-friendly)');
        }
        return piped;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[YouTubeMusic] Piped all failed: $e');
      }
    }

    // ── 2) Invidious with local=true – proxied through instance ──
    try {
      final invidious = await _getInvidiousStreamUrls(videoId);
      if (invidious.isNotEmpty) {
        if (kDebugMode) {
          print('[YouTubeMusic] Invidious: ${invidious.length} URL(s) (proxied, MPV-friendly)');
        }
        return invidious;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[YouTubeMusic] Invidious all failed: $e');
      }
    }

    // ── 3) youtube_explode_dart (Harmony-Music lib/services/stream_service.dart – StreamProvider.fetch)
    final ytExplodeUrls = await _getYoutubeExplodeStreamUrls(videoId);
    if (ytExplodeUrls.isNotEmpty) return ytExplodeUrls;

    // ── 4) InnerTube direct (googlevideo.com; may fail on desktop MPV) ──
    try {
      final streams = await _innerTube.getStreamUrls(videoId);
      if (streams.isNotEmpty) {
        final urls = streams.map((s) => s.url).toList();
        if (kDebugMode) {
          final best = streams.first;
          print('[YouTubeMusic] InnerTube: ${urls.length} stream(s), '
              'best=${best.quality} ${best.codec} ${best.bitrate}bps '
              'client=${best.clientName}');
        }
        return urls;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[YouTubeMusic] InnerTube failed: $e');
      }
    }

    if (kDebugMode) {
      print('[YouTubeMusic] ALL methods failed for videoId=$videoId');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // youtube_explode_dart – Harmony-Music streaming stack (primary).
  // Reference: Harmony-Music lib/services/stream_service.dart – StreamProvider.fetch(),
  // highestQualityAudio = itag 251 (opus) or 140 (mp4a); fallback lowQualityAudio itag 249/139.
  // ---------------------------------------------------------------------------

  /// Preferred itags for best audio (Harmony-Music stream_service.dart: highestQualityAudio).
  static const List<int> _preferredItags = [251, 140]; // opus, mp4a
  static const List<int> _fallbackItags = [250, 139]; // lower opus/mp4a

  Future<List<String>> _getYoutubeExplodeStreamUrls(String videoId) async {
    final clientConfigs = <List<YoutubeApiClient>?>[
      null,
      [YoutubeApiClient.tv],
      [YoutubeApiClient.androidVr],
      [YoutubeApiClient.ios],
      [YoutubeApiClient.safari],
    ];
    const clientNames = ['default', 'tv', 'androidVr', 'ios', 'safari'];

    for (var i = 0; i < clientConfigs.length; i++) {
      final ytClients = clientConfigs[i];
      final clientName = clientNames[i];
      final yt = YoutubeExplode();
      try {
        final manifest = ytClients == null
            ? await yt.videos.streams
                .getManifest(videoId)
                .timeout(const Duration(seconds: 20))
            : await yt.videos.streams
                .getManifest(videoId, ytClients: ytClients)
                .timeout(const Duration(seconds: 20));

        final urls = _pickAudioUrlsFromManifest(manifest);
        if (urls.isNotEmpty) {
          if (kDebugMode) {
            print('[YouTubeMusic] yt_explode: SUCCESS client=$clientName urls=${urls.length}');
          }
          return urls;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[YouTubeMusic] yt_explode client=$clientName failed: $e');
        }
      } finally {
        yt.close();
      }
    }
    return [];
  }

  /// Pick audio stream URLs from manifest (Harmony-Music style: prefer itag 251/140, then by bitrate).
  /// Typed comparators avoid '(dynamic, dynamic) => dynamic' not a subtype of '((AudioOnlyStreamInfo, AudioOnlyStreamInfo) => int)'.
  List<String> _pickAudioUrlsFromManifest(StreamManifest manifest) {
    final audioOnly = manifest.audioOnly;
    final muxed = manifest.muxed;
    final audio = manifest.audio;

    int compareAudioOnly(AudioOnlyStreamInfo a, AudioOnlyStreamInfo b) =>
        b.bitrate.compareTo(a.bitrate);

    // Prefer audio-only, with Harmony's itag preference (251 opus, 140 mp4a).
    if (audioOnly.isNotEmpty) {
      final list = audioOnly.toList();
      final preferred = list.where((s) => _preferredItags.contains(s.tag)).toList();
      final fallback = list.where((s) => _fallbackItags.contains(s.tag)).toList();
      preferred.sort(compareAudioOnly);
      fallback.sort(compareAudioOnly);
      final rest = list
          .where((s) => !_preferredItags.contains(s.tag) && !_fallbackItags.contains(s.tag))
          .toList();
      rest.sort(compareAudioOnly);
      final ordered = [...preferred, ...fallback, ...rest];
      if (ordered.isNotEmpty) {
        return ordered.map((s) => s.url.toString()).toList();
      }
    }
    if (muxed.isNotEmpty) {
      final list = muxed.toList()
        ..sort((MuxedStreamInfo a, MuxedStreamInfo b) => b.bitrate.compareTo(a.bitrate));
      return list.map((s) => s.url.toString()).toList();
    }
    if (audio.isNotEmpty) {
      final list = audio.toList()
        ..sort((AudioStreamInfo a, AudioStreamInfo b) => b.bitrate.compareTo(a.bitrate));
      return list.map((s) => s.url.toString()).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Piped API
  // ---------------------------------------------------------------------------

  Future<List<String>> _getPipedStreamUrls(String videoId) async {
    List<String> instances = _pipedInstances;
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_prefKeyPipedInstance)?.trim();
      if (custom != null && custom.isNotEmpty) {
        instances = [custom, ..._pipedInstances];
      }
    } catch (_) {}
    for (final base in instances) {
      try {
        final uri = Uri.parse('$base/streams/$videoId');
        final client = http.Client();
        try {
          final resp = await client.get(uri).timeout(const Duration(seconds: 8));
          if (resp.statusCode != 200) continue;

          final json = jsonDecode(resp.body) as Map<String, dynamic>?;
          if (json == null) continue;

          final audioStreams = json['audioStreams'] as List<dynamic>? ?? [];
          final withUrl = <Map<String, dynamic>>[];
          for (final e in audioStreams) {
            if (e is! Map) continue;
            final u = e['url'] as String?;
            if (u == null || u.isEmpty) continue;
            withUrl.add(Map<String, dynamic>.from(e));
          }
          withUrl.sort((a, b) {
            final aBit = (a['bitrate'] is int)
                ? a['bitrate'] as int
                : int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
            final bBit = (b['bitrate'] is int)
                ? b['bitrate'] as int
                : int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
            return bBit.compareTo(aBit);
          });
          final urls = withUrl
              .map((f) => f['url'] as String?)
              .where((u) => u != null && u.isNotEmpty)
              .cast<String>()
              .toList();
          if (urls.isNotEmpty) {
            if (kDebugMode) {
              print('[YouTubeMusic] Piped: got ${urls.length} URL(s) from $base');
            }
            return urls;
          }
        } finally {
          client.close();
        }
      } catch (e) {
        if (kDebugMode) {
          print('[YouTubeMusic] Piped $base failed: $e');
        }
      }
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Invidious API
  // ---------------------------------------------------------------------------

  Future<List<String>> _getInvidiousStreamUrls(String videoId) async {
    List<String> instances = _invidiousInstances;
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_prefKeyInvidiousInstance)?.trim();
      if (custom != null && custom.isNotEmpty) {
        instances = [custom, ..._invidiousInstances];
      }
    } catch (_) {}
    for (final base in instances) {
      try {
        final uri = Uri.parse('$base/api/v1/videos/$videoId').replace(
          queryParameters: {'local': 'true'},
        );
        final client = http.Client();
        try {
          final resp = await client.get(uri).timeout(const Duration(seconds: 8));
          if (resp.statusCode != 200) continue;
          final body = resp.body;
          if (body.isEmpty || body.trimLeft().startsWith('<')) continue;

          final json = jsonDecode(body) as Map<String, dynamic>?;
          if (json == null) continue;

          final urls = <String>[];

          String abs(String? u) {
            if (u == null || u.isEmpty) return '';
            if (u.startsWith('http')) return u;
            if (u.startsWith('/')) return '$base$u';
            return u;
          }

          final adaptive = json['adaptiveFormats'] as List<dynamic>? ?? [];
          final withUrl = <Map<String, dynamic>>[];
          for (final e in adaptive) {
            if (e is! Map) continue;
            final u = abs(e['url'] as String?);
            if (u.isEmpty) continue;
            withUrl.add(Map<String, dynamic>.from(e)..['url'] = u);
          }
          withUrl.sort((a, b) {
            final aAudio = a['audioQuality'] != null ? 1 : 0;
            final bAudio = b['audioQuality'] != null ? 1 : 0;
            if (aAudio != bAudio) return bAudio - aAudio;
            final aBit = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
            final bBit = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
            return bBit.compareTo(aBit);
          });
          for (final f in withUrl) {
            final u = f['url'] as String?;
            if (u != null) urls.add(u);
          }

          if (urls.isEmpty) {
            final streams = json['formatStreams'] as List<dynamic>? ?? [];
            for (final s in streams) {
              if (s is! Map) continue;
              final u = abs(s['url'] as String?);
              if (u.isNotEmpty) urls.add(u);
            }
          }

          if (urls.isEmpty) {
            final hls = abs(json['hlsUrl'] as String?);
            if (hls.isNotEmpty) urls.add(hls);
          }

          if (urls.isNotEmpty) {
            if (kDebugMode) {
              print('[YouTubeMusic] Invidious: got ${urls.length} URL(s) from $base');
            }
            return urls;
          }
        } finally {
          client.close();
        }
      } catch (e) {
        if (kDebugMode) {
          print('[YouTubeMusic] Invidious $base failed: $e');
        }
      }
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
    _innerTube.cookie = null;
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
