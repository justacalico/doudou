import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';
import '../../models/jellyfin_models.dart';
import '../base_service.dart';

class SubsonicService implements BaseMediaService {
  late Dio _dio;
  String? _serverUrl;
  String? _username;
  String? _token;
  String? _salt;

  @override
  ServerType get serverType => ServerType.subsonic;

  SubsonicService() {
    _dio = Dio();

    // Configure timeouts
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // Platform-specific configurations
    if (Platform.isLinux) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
          (client) {
            client.badCertificateCallback = (cert, host, port) {
              return true;
            };
            return client;
          };
    }
  }

  @override
  Future<bool> authenticate(
    String serverUrl,
    String identifier,
    String credential,
  ) async {
    try {
      _serverUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;
      _username = identifier;

      // Subsonic API authentication
      _salt = DateTime.now().millisecondsSinceEpoch.toString();
      _token = _generateToken(credential, _salt!);

      // Test authentication with ping
      final response = await _dio.get(
        '$_serverUrl/rest/ping',
        queryParameters: {
          'u': _username,
          't': _token,
          's': _salt,
          'v': '1.16.1',
          'c': 'Doudou',
          'f': 'json',
        },
      );

      if (response.statusCode == 200 &&
          response.data['subsonic-response']['status'] == 'ok') {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  String _generateToken(String password, String salt) {
    // MD5 hash of password + salt
    return _md5Hash(password + salt);
  }

  String _md5Hash(String input) {
    var bytes = utf8.encode(input);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  @override
  void setServerId(String? serverId) {}

  @override
  Future<void> persistLocalDataIfAny() async {}

  @override
  void setServer(String serverUrl) {
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
  }

  @override
  Future<bool> validateCredentials() async {
    if (_serverUrl == null ||
        _username == null ||
        _token == null ||
        _salt == null) {
      return false;
    }

    try {
      final response = await _dio.get(
        '$_serverUrl/rest/ping',
        queryParameters: {
          'u': _username,
          't': _token,
          's': _salt,
          'v': '1.16.1',
          'c': 'Doudou',
          'f': 'json',
        },
      );

      return response.statusCode == 200 &&
          response.data['subsonic-response']['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> get _baseParams => {
    'u': _username,
    't': _token,
    's': _salt,
    'v': '1.16.1',
    'c': 'Doudou',
    'f': 'json',
  };

  @override
  Future<List<Library>> getLibraries() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/rest/getMusicFolders',
        queryParameters: _baseParams,
      );

      final folders =
          response.data['subsonic-response']['musicFolders']['musicFolder']
              as List;
      return folders
          .map(
            (folder) => Library(
              id: folder['id'].toString(),
              name: folder['name'],
              collectionType: 'music',
              imageUrl: null,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['type'] =
          'alphabeticalByName'; // Required parameter for getAlbumList2
      if (libraryId != null) params['musicFolderId'] = libraryId;
      if (limit != null) params['size'] = limit.toString();
      if (startIndex != null) params['offset'] = startIndex.toString();

      final response = await _dio.get(
        '$_serverUrl/rest/getAlbumList2',
        queryParameters: params,
      );

      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        return [];
      }

      final albumList2 = subsonicResponse['albumList2'];
      if (albumList2 == null) {
        return [];
      }

      final albums = albumList2['album'];
      if (albums == null) {
        return [];
      }

      // Handle case where albums might be a single object instead of array
      final albumsList = albums is List ? albums : [albums];

      return albumsList
          .map(
            (album) => Album(
              id: album['id'],
              name: album['name'],
              artistName: album['artist'] ?? 'Unknown Artist',
              year: album['year'],
              imageUrl: album['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${album['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      if (libraryId != null) params['musicFolderId'] = libraryId;

      final response = await _dio.get(
        '$_serverUrl/rest/getArtists',
        queryParameters: params,
      );

      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        return [];
      }

      final artists = subsonicResponse['artists'];
      if (artists == null) {
        return [];
      }

      final indexes = artists['index'] as List? ?? [];
      final List<Artist> artistList = [];

      for (final index in indexes) {
        final artistArray = index['artist'];
        if (artistArray != null) {
          // Handle case where artist might be a single object instead of array
          final artistsList = artistArray is List ? artistArray : [artistArray];
          for (final artist in artistsList) {
            artistList.add(
              Artist(
                id: artist['id'],
                name: artist['name'],
                imageUrl: artist['coverArt'] != null
                    ? '$_serverUrl/rest/getCoverArt?id=${artist['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                    : null,
              ),
            );
          }
        }
      }

      // Apply limit and offset manually
      if (startIndex != null && limit != null) {
        final end = (startIndex + limit).clamp(0, artistList.length);
        return artistList.sublist(startIndex.clamp(0, artistList.length), end);
      } else if (startIndex != null) {
        return artistList.sublist(startIndex.clamp(0, artistList.length));
      } else if (limit != null) {
        return artistList.take(limit).toList();
      }

      return artistList;
    } catch (e) {
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
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      if (limit != null) params['size'] = limit.toString();
      if (startIndex != null) params['offset'] = startIndex.toString();

      Response response;
      if (parentId != null) {
        // Get songs from album
        params['id'] = parentId;
        response = await _dio.get(
          '$_serverUrl/rest/getAlbum',
          queryParameters: params,
        );

        final subsonicResponse = response.data['subsonic-response'];
        if (subsonicResponse == null) {
          return [];
        }

        final album = subsonicResponse['album'];
        if (album == null) {
          return [];
        }

        final songs = album['song'];
        if (songs == null) {
          return [];
        }

        // Handle case where songs might be a single object instead of array
        final songsList = songs is List ? songs : [songs];

        return songsList
            .map(
              (song) => Track(
                id: song['id'],
                name: song['title'],
                artistName: song['artist'] ?? 'Unknown Artist',
                albumName: song['album'] ?? 'Unknown Album',
                duration: song['duration'] != null
                    ? (song['duration'] as int) * 1000
                    : null, // Convert seconds to milliseconds
                trackNumber: song['track'],
                imageUrl: song['coverArt'] != null
                    ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                    : null,
                isFavorite:
                    song['starred'] !=
                    null, // Subsonic uses 'starred' field with timestamp or null
              ),
            )
            .toList();
      } else {
        // Get random songs or from library
        if (libraryId != null) params['musicFolderId'] = libraryId;
        params['size'] = (limit ?? 50).toString();

        response = await _dio.get(
          '$_serverUrl/rest/getRandomSongs',
          queryParameters: params,
        );

        final subsonicResponse = response.data['subsonic-response'];
        if (subsonicResponse == null) {
          return [];
        }

        final randomSongs = subsonicResponse['randomSongs'];
        if (randomSongs == null) {
          return [];
        }

        final songs = randomSongs['song'];
        if (songs == null) {
          return [];
        }

        // Handle case where songs might be a single object instead of array
        final songsList = songs is List ? songs : [songs];

        return songsList
            .map(
              (song) => Track(
                id: song['id'],
                name: song['title'],
                artistName: song['artist'] ?? 'Unknown Artist',
                albumName: song['album'] ?? 'Unknown Album',
                duration: song['duration'] != null
                    ? (song['duration'] as int) * 1000
                    : null, // Convert seconds to milliseconds
                trackNumber: song['track'],
                imageUrl: song['coverArt'] != null
                    ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                    : null,
                isFavorite:
                    song['starred'] !=
                    null, // Subsonic uses 'starred' field with timestamp or null
              ),
            )
            .toList();
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/rest/getPlaylists',
        queryParameters: _baseParams,
      );

      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        return [];
      }

      final playlistsContainer = subsonicResponse['playlists'];
      if (playlistsContainer == null) {
        return [];
      }

      final playlists = playlistsContainer['playlist'];
      if (playlists == null) {
        return [];
      }

      // Handle case where playlists might be a single object instead of array
      final playlistsList = playlists is List ? playlists : [playlists];

      return playlistsList
          .map(
            (playlist) => Playlist(
              id: playlist['id'],
              name: playlist['name'],
              imageUrl: playlist['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${playlist['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
              trackCount: playlist['songCount'] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['id'] = playlistId;

      final response = await _dio.get(
        '$_serverUrl/rest/getPlaylist',
        queryParameters: params,
      );

      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        return [];
      }

      final playlist = subsonicResponse['playlist'];
      if (playlist == null) {
        return [];
      }

      final songs = playlist['entry'];
      if (songs == null) {
        return [];
      }

      // Handle case where songs might be a single object instead of array
      final songsList = songs is List ? songs : [songs];

      return songsList
          .map(
            (song) => Track(
              id: song['id'],
              name: song['title'],
              artistName: song['artist'] ?? 'Unknown Artist',
              albumName: song['album'] ?? 'Unknown Album',
              duration: song['duration'] != null
                  ? (song['duration'] as int) * 1000
                  : null, // Convert seconds to milliseconds
              trackNumber: song['track'],
              imageUrl: song['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
              isFavorite:
                  song['starred'] !=
                  null, // Subsonic uses 'starred' field with timestamp or null
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = trackId;
    if (bitrate != null) params['maxBitRate'] = bitrate.toString();

    return '$_serverUrl/rest/stream?${Uri(queryParameters: params).query}';
  }

  /// Get direct download URL (no transcoding)
  String getDirectStreamUrl(String trackId) {
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = trackId;

    return '$_serverUrl/rest/download?${Uri(queryParameters: params).query}';
  }

  /// Get transcoded stream URL with specific format
  String getTranscodedStreamUrl(
    String trackId, {
    String format = 'mp3',
    int? bitrate,
  }) {
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = trackId;
    params['format'] = format;
    if (bitrate != null) params['maxBitRate'] = bitrate.toString();

    return '$_serverUrl/rest/stream?${Uri(queryParameters: params).query}';
  }

  /// Get alternative stream URL (using different endpoint)
  String getAlternativeStreamUrl(String trackId) {
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = trackId;

    return '$_serverUrl/rest/stream?${Uri(queryParameters: params).query}';
  }

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = itemId;
    if (width != null) params['size'] = width.toString();

    return '$_serverUrl/rest/getCoverArt?${Uri(queryParameters: params).query}';
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['query'] = query;
      // Subsonic search3 uses separate count parameters for each type
      final searchLimit = limit ?? 100;
      params['artistCount'] = searchLimit.toString();
      params['albumCount'] = searchLimit.toString();
      params['songCount'] = searchLimit.toString();

      final response = await _dio.get(
        '$_serverUrl/rest/search3',
        queryParameters: params,
      );

      final searchResult = response.data['subsonic-response']['searchResult3'];

      final albums = (searchResult['album'] as List? ?? [])
          .map(
            (album) => Album(
              id: album['id'],
              name: album['name'],
              artistName: album['artist'] ?? 'Unknown Artist',
              year: album['year'],
              imageUrl: album['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${album['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
            ),
          )
          .toList();

      final artists = (searchResult['artist'] as List? ?? [])
          .map(
            (artist) => Artist(
              id: artist['id'],
              name: artist['name'],
              imageUrl: artist['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${artist['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
            ),
          )
          .toList();

      final tracks = (searchResult['song'] as List? ?? [])
          .map(
            (song) => Track(
              id: song['id'],
              name: song['title'],
              artistName: song['artist'] ?? 'Unknown Artist',
              albumName: song['album'] ?? 'Unknown Album',
              duration: song['duration'] != null
                  ? (song['duration'] as int) * 1000
                  : null, // Convert seconds to milliseconds
              trackNumber: song['track'],
              imageUrl: song['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
              isFavorite:
                  song['starred'] !=
                  null, // Subsonic uses 'starred' field with timestamp or null
            ),
          )
          .toList();

      return SearchResults(albums: albums, artists: artists, tracks: tracks);
    } catch (e) {
      return SearchResults();
    }
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/rest/ping',
        queryParameters: _baseParams,
      );

      final subsonicResponse = response.data['subsonic-response'];
      return ServerInfo(
        name: 'Subsonic Server',
        version: subsonicResponse['version'] ?? 'Unknown',
        id: _serverUrl ?? 'unknown',
        type: ServerType.subsonic,
      );
    } catch (e) {
      return ServerInfo(
        name: 'Subsonic Server',
        version: 'Unknown',
        id: _serverUrl ?? 'unknown',
        type: ServerType.subsonic,
      );
    }
  }

  @override
  get currentServer => {
    'url': _serverUrl,
    'username': _username,
    'token': _token,
    'salt': _salt,
  };

  @override
  void clearAuth() {
    _username = null;
    _token = null;
    _salt = null;
    _serverUrl = null;
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    if (_serverUrl == null ||
        _username == null ||
        _token == null ||
        _salt == null) {
      throw Exception('Server not configured');
    }

    try {
      // Subsonic uses star/unstar endpoints for favorites
      final action = isFavorite ? 'unstar' : 'star';
      final params = Map<String, dynamic>.from(_baseParams);
      params['id'] = itemId;
      final url = '$_serverUrl/rest/$action';

      final response = await _dio.get(url, queryParameters: params);

      // Check for success response in Subsonic format
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['subsonic-response'] != null) {
          final subsonicResponse = data['subsonic-response'];
          final success = subsonicResponse['status'] == 'ok';

          return success;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Playlist?> createPlaylist(String name) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['name'] = name;

      final response = await _dio.get(
        '$_serverUrl/rest/createPlaylist',
        queryParameters: params,
      );

      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null || subsonicResponse['status'] != 'ok') {
        return null;
      }

      final playlist = subsonicResponse['playlist'];
      if (playlist != null) {
        return Playlist(
          id: playlist['id'],
          name: playlist['name'],
          imageUrl: playlist['coverArt'] != null
              ? '$_serverUrl/rest/getCoverArt?id=${playlist['coverArt']}&${Uri(queryParameters: _baseParams).query}'
              : null,
          trackCount: playlist['songCount'] ?? 0,
        );
      }

      // If no playlist in response, return a basic one (some servers don't return the created playlist)
      return Playlist(
        id: '', // Will be filled when we reload playlists
        name: name,
        imageUrl: null,
        trackCount: 0,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['playlistId'] = playlistId;
      params['songIdToAdd'] = trackId;

      final response = await _dio.get(
        '$_serverUrl/rest/updatePlaylist',
        queryParameters: params,
      );

      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      return subsonicResponse != null && subsonicResponse['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeTrackFromPlaylist(
    String playlistId,
    int trackIndex,
  ) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['playlistId'] = playlistId;
      params['songIndexToRemove'] = trackIndex.toString();

      final response = await _dio.get(
        '$_serverUrl/rest/updatePlaylist',
        queryParameters: params,
      );

      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      return subsonicResponse != null && subsonicResponse['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  Future<bool> renamePlaylist(String playlistId, String newName) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['playlistId'] = playlistId;
      params['name'] = newName;

      final response = await _dio.get(
        '$_serverUrl/rest/updatePlaylist',
        queryParameters: params,
      );

      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      return subsonicResponse != null && subsonicResponse['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  Future<bool> removePlaylist(String playlistId) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['id'] = playlistId;

      final response = await _dio.get(
        '$_serverUrl/rest/deletePlaylist',
        queryParameters: params,
      );

      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      return subsonicResponse != null && subsonicResponse['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  /// Get all tracks from the library using search3 with pagination
  /// This is more reliable than getRandomSongs for getting all music
  @override
  Future<List<Track>> getAllTracks({int? maxTracks}) async {
    if (_serverUrl == null ||
        _username == null ||
        _token == null ||
        _salt == null) {
      return [];
    }

    try {
      final List<Track> allTracks = [];
      int offset = 0;
      const int pageSize = 500; // Max allowed by Subsonic API
      final int maxToFetch = maxTracks ?? 50000; // Safety limit
      bool hasMore = true;

      while (hasMore && allTracks.length < maxToFetch) {
        final params = Map<String, dynamic>.from(_baseParams);
        params['query'] = ''; // Empty query returns all
        params['songCount'] = pageSize.toString();
        params['songOffset'] = offset.toString();
        params['artistCount'] = '0'; // We only want songs
        params['albumCount'] = '0';

        final response = await _dio.get(
          '$_serverUrl/rest/search3',
          queryParameters: params,
        );

        final subsonicResponse = response.data['subsonic-response'];
        if (subsonicResponse == null || subsonicResponse['status'] != 'ok') {
          break;
        }

        final searchResult = subsonicResponse['searchResult3'];
        if (searchResult == null) {
          break;
        }

        final songs = searchResult['song'];
        if (songs == null || (songs is List && songs.isEmpty)) {
          hasMore = false;
          break;
        }

        final songsList = songs is List ? songs : [songs];

        for (final song in songsList) {
          allTracks.add(
            Track(
              id: song['id'],
              name: song['title'] ?? 'Unknown Title',
              artistName: song['artist'] ?? 'Unknown Artist',
              albumName: song['album'] ?? 'Unknown Album',
              duration: song['duration'] != null
                  ? (song['duration'] as int) * 1000
                  : null,
              trackNumber: song['track'],
              imageUrl: song['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
              isFavorite: song['starred'] != null,
              albumId: song['albumId'],
            ),
          );
        }

        if (songsList.length < pageSize) {
          hasMore = false;
        } else {
          offset += pageSize;
        }
      }

      return allTracks;
    } catch (e) {
      return [];
    }
  }

  /// Get all starred (favorite) items using getStarred2 API
  @override
  Future<List<Track>> getStarredTracks() async {
    if (_serverUrl == null ||
        _username == null ||
        _token == null ||
        _salt == null) {
      return [];
    }

    try {
      final response = await _dio.get(
        '$_serverUrl/rest/getStarred2',
        queryParameters: _baseParams,
      );

      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null || subsonicResponse['status'] != 'ok') {
        return [];
      }

      final starred = subsonicResponse['starred2'];
      if (starred == null) {
        return [];
      }

      final songs = starred['song'];
      if (songs == null) {
        return [];
      }

      final songsList = songs is List ? songs : [songs];

      return songsList
          .map(
            (song) => Track(
              id: song['id'],
              name: song['title'] ?? 'Unknown Title',
              artistName: song['artist'] ?? 'Unknown Artist',
              albumName: song['album'] ?? 'Unknown Album',
              duration: song['duration'] != null
                  ? (song['duration'] as int) * 1000
                  : null,
              trackNumber: song['track'],
              imageUrl: song['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
              isFavorite: true, // All returned items are starred
              albumId: song['albumId'],
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get starred albums
  @override
  Future<List<Album>> getStarredAlbums() async {
    if (_serverUrl == null ||
        _username == null ||
        _token == null ||
        _salt == null) {
      return [];
    }

    try {
      final response = await _dio.get(
        '$_serverUrl/rest/getStarred2',
        queryParameters: _baseParams,
      );

      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null || subsonicResponse['status'] != 'ok') {
        return [];
      }

      final starred = subsonicResponse['starred2'];
      if (starred == null) {
        return [];
      }

      final albums = starred['album'];
      if (albums == null) {
        return [];
      }

      final albumsList = albums is List ? albums : [albums];

      return albumsList
          .map(
            (album) => Album(
              id: album['id'],
              name: album['name'] ?? 'Unknown Album',
              artistName: album['artist'] ?? 'Unknown Artist',
              year: album['year'],
              imageUrl: album['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${album['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
              isFavorite: true,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get starred artists
  @override
  Future<List<Artist>> getStarredArtists() async {
    if (_serverUrl == null ||
        _username == null ||
        _token == null ||
        _salt == null) {
      return [];
    }

    try {
      final response = await _dio.get(
        '$_serverUrl/rest/getStarred2',
        queryParameters: _baseParams,
      );

      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null || subsonicResponse['status'] != 'ok') {
        return [];
      }

      final starred = subsonicResponse['starred2'];
      if (starred == null) {
        return [];
      }

      final artists = starred['artist'];
      if (artists == null) {
        return [];
      }

      final artistsList = artists is List ? artists : [artists];

      return artistsList
          .map(
            (artist) => Artist(
              id: artist['id'],
              name: artist['name'] ?? 'Unknown Artist',
              imageUrl: artist['coverArt'] != null
                  ? '$_serverUrl/rest/getCoverArt?id=${artist['coverArt']}&${Uri(queryParameters: _baseParams).query}'
                  : null,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    // Return Subsonic alternative stream URLs with different formats/bitrates
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = trackId;

    return [
      getStreamUrl(trackId), // Primary stream URL
      getStreamUrl(trackId, bitrate: 192), // Medium bitrate fallback
      getStreamUrl(trackId, bitrate: 128), // Lower bitrate fallback
      '$_serverUrl/rest/download?${Uri(queryParameters: params).query}', // Direct download fallback
    ];
  }

  @override
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId) async {
    // Subsonic doesn't need async metadata fetching, return sync version
    return getAlternativeStreamUrls(trackId);
  }
}
