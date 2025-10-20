import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';
import 'base_service.dart';

class PlexService implements BaseMediaService {
  late Dio _dio;
  String? _serverUrl;
  String? _token;
  String? _machineIdentifier;

  @override
  ServerType get serverType => ServerType.plex;

  PlexService() {
    _dio = Dio();

    // Configure timeouts
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // Set default headers for JSON responses
    _dio.options.headers['Accept'] = 'application/json';
    _dio.options.headers['X-Plex-Client-Identifier'] = 'doudou-flutter';
    _dio.options.headers['X-Plex-Product'] = 'Doudou';
    _dio.options.headers['X-Plex-Version'] = '1.0.0';

    // Platform-specific configurations
    if (Platform.isLinux) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
          (client) {
            client.badCertificateCallback = (cert, host, port) {
              if (kDebugMode) {
                print('Warning: Accepting bad certificate for $host:$port');
              }
              return true;
            };
            return client;
          };
    }
  }

  /// Helper method to safely parse duration from Plex API response
  int _parseDuration(dynamic duration) {
    if (duration == null) return 0;
    if (duration is int) return duration ~/ 1000; // Convert from ms to seconds
    if (duration is String) {
      final parsed = int.tryParse(duration);
      return parsed != null ? parsed ~/ 1000 : 0;
    }
    return 0;
  }

  /// Get track's part ID for direct streaming (most reliable method)
  Future<String?> _getTrackPartId(String trackId) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/library/metadata/$trackId',
        queryParameters: {'X-Plex-Token': _token},
      );

      final metadata = response.data['MediaContainer']['Metadata'];
      if (metadata != null && metadata.isNotEmpty) {
        final media = metadata[0]['Media'];
        if (media != null && media.isNotEmpty) {
          final part = media[0]['Part'];
          if (part != null && part.isNotEmpty) {
            final partId = part[0]['id'];
            if (kDebugMode) {
              print('Found part ID: $partId for track: $trackId');
            }
            return partId?.toString();
          }
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting track part ID: $e');
      }
      return null;
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
      _token = credential; // For Plex, credential is the X-Plex-Token

      if (kDebugMode) {
        print('Plex: Attempting authentication to $_serverUrl with token');
      }

      // Try to get server info using the root endpoint
      final response = await _dio.get(
        '$_serverUrl/',
        queryParameters: {'X-Plex-Token': _token},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (kDebugMode) {
        print('Plex auth response status: ${response.statusCode}');
        print('Plex auth response data: ${response.data}');
      }

      if (response.statusCode == 200) {
        // Try to parse the response data
        if (response.data is Map && response.data['MediaContainer'] != null) {
          _machineIdentifier =
              response.data['MediaContainer']['machineIdentifier'];
          if (kDebugMode) {
            print(
              'Plex: Authentication successful. Machine ID: $_machineIdentifier',
            );
          }
          return true;
        } else if (response.data is String &&
            response.data.contains('MediaContainer')) {
          // If we get XML response, consider it successful for now
          if (kDebugMode) {
            print('Plex: Authentication successful (XML response)');
          }
          return true;
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Plex authentication error: $e');
      }
      return false;
    }
  }

  @override
  void setServer(String serverUrl) {
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
  }

  @override
  Future<bool> validateCredentials() async {
    if (_serverUrl == null || _token == null) return false;

    try {
      final response = await _dio.get(
        '$_serverUrl/',
        queryParameters: {'X-Plex-Token': _token},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        if (response.data is Map && response.data['MediaContainer'] != null) {
          return true;
        } else if (response.data is String &&
            response.data.contains('MediaContainer')) {
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Plex credential validation error: $e');
      }
      return false;
    }
  }

  @override
  Future<List<Library>> getLibraries() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/library/sections',
        queryParameters: {'X-Plex-Token': _token},
      );

      final sections = response.data['MediaContainer']['Directory'] as List;
      return sections
          .where(
            (section) => section['type'] == 'artist',
          ) // Only music libraries
          .map(
            (section) => Library(
              id: section['key'].toString(),
              name: section['title'],
              collectionType: 'music',
              imageUrl: null,
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex libraries: $e');
      }
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
      List<Album> allAlbums = [];

      if (libraryId != null) {
        // Get albums from specific library
        final response = await _dio.get(
          '$_serverUrl/library/sections/$libraryId/all',
          queryParameters: {
            'X-Plex-Token': _token,
            'type': '9', // Album type in Plex
            if (limit != null) 'X-Plex-Container-Size': limit.toString(),
            if (startIndex != null)
              'X-Plex-Container-Start': startIndex.toString(),
          },
        );

        final albums =
            response.data['MediaContainer']['Metadata'] as List? ?? [];
        allAlbums.addAll(
          albums
              .map(
                (album) => Album(
                  id: album['ratingKey'].toString(),
                  name: album['title'],
                  artistName: album['parentTitle'] ?? 'Unknown Artist',
                  year: album['year'] is int
                      ? album['year']
                      : (int.tryParse(album['year']?.toString() ?? '0') ?? 0),
                  imageUrl: album['thumb'] != null
                      ? '$_serverUrl${album['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else {
        // Get all music libraries first, then get albums from each
        final libraries = await getLibraries();
        for (final library in libraries) {
          if (library.collectionType == 'music') {
            final response = await _dio.get(
              '$_serverUrl/library/sections/${library.id}/all',
              queryParameters: {
                'X-Plex-Token': _token,
                'type': '9', // Album type in Plex
                if (limit != null) 'X-Plex-Container-Size': limit.toString(),
                if (startIndex != null)
                  'X-Plex-Container-Start': startIndex.toString(),
              },
            );

            final albums =
                response.data['MediaContainer']['Metadata'] as List? ?? [];
            allAlbums.addAll(
              albums
                  .map(
                    (album) => Album(
                      id: album['ratingKey'].toString(),
                      name: album['title'],
                      artistName: album['parentTitle'] ?? 'Unknown Artist',
                      year: album['year'] is int
                          ? album['year']
                          : (int.tryParse(album['year']?.toString() ?? '0') ??
                                0),
                      imageUrl: album['thumb'] != null
                          ? '$_serverUrl${album['thumb']}?X-Plex-Token=$_token'
                          : null,
                    ),
                  )
                  .toList(),
            );
          }
        }
      }

      return allAlbums;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex albums: $e');
      }
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
      List<Artist> allArtists = [];

      if (libraryId != null) {
        // Get artists from specific library
        final response = await _dio.get(
          '$_serverUrl/library/sections/$libraryId/all',
          queryParameters: {
            'X-Plex-Token': _token,
            'type': '8', // Artist type in Plex
            if (limit != null) 'X-Plex-Container-Size': limit.toString(),
            if (startIndex != null)
              'X-Plex-Container-Start': startIndex.toString(),
          },
        );

        final artists =
            response.data['MediaContainer']['Metadata'] as List? ?? [];
        allArtists.addAll(
          artists
              .map(
                (artist) => Artist(
                  id: artist['ratingKey'].toString(),
                  name: artist['title'],
                  imageUrl: artist['thumb'] != null
                      ? '$_serverUrl${artist['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else {
        // Get all music libraries first, then get artists from each
        final libraries = await getLibraries();
        for (final library in libraries) {
          if (library.collectionType == 'music') {
            final response = await _dio.get(
              '$_serverUrl/library/sections/${library.id}/all',
              queryParameters: {
                'X-Plex-Token': _token,
                'type': '8', // Artist type in Plex
                if (limit != null) 'X-Plex-Container-Size': limit.toString(),
                if (startIndex != null)
                  'X-Plex-Container-Start': startIndex.toString(),
              },
            );

            final artists =
                response.data['MediaContainer']['Metadata'] as List? ?? [];
            allArtists.addAll(
              artists
                  .map(
                    (artist) => Artist(
                      id: artist['ratingKey'].toString(),
                      name: artist['title'],
                      imageUrl: artist['thumb'] != null
                          ? '$_serverUrl${artist['thumb']}?X-Plex-Token=$_token'
                          : null,
                    ),
                  )
                  .toList(),
            );
          }
        }
      }

      return allArtists;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex artists: $e');
      }
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
      List<Track> allTracks = [];

      if (parentId != null) {
        // Get tracks from specific album
        final response = await _dio.get(
          '$_serverUrl/library/metadata/$parentId/children',
          queryParameters: {
            'X-Plex-Token': _token,
            if (limit != null) 'X-Plex-Container-Size': limit.toString(),
            if (startIndex != null)
              'X-Plex-Container-Start': startIndex.toString(),
          },
        );

        final tracks =
            response.data['MediaContainer']['Metadata'] as List? ?? [];
        allTracks.addAll(
          tracks
              .map(
                (track) => Track(
                  id: track['ratingKey'].toString(),
                  name: track['title'],
                  artistName: track['grandparentTitle'] ?? 'Unknown Artist',
                  albumName: track['parentTitle'] ?? 'Unknown Album',
                  duration: _parseDuration(track['duration']),
                  trackNumber: track['index'] is int
                      ? track['index']
                      : (int.tryParse(track['index']?.toString() ?? '0') ?? 0),
                  imageUrl: track['thumb'] != null
                      ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else if (libraryId != null) {
        // Get tracks from specific library
        final response = await _dio.get(
          '$_serverUrl/library/sections/$libraryId/all',
          queryParameters: {
            'X-Plex-Token': _token,
            'type': '10', // Track type in Plex
            if (limit != null) 'X-Plex-Container-Size': limit.toString(),
            if (startIndex != null)
              'X-Plex-Container-Start': startIndex.toString(),
          },
        );

        final tracks =
            response.data['MediaContainer']['Metadata'] as List? ?? [];
        allTracks.addAll(
          tracks
              .map(
                (track) => Track(
                  id: track['ratingKey'].toString(),
                  name: track['title'],
                  artistName: track['grandparentTitle'] ?? 'Unknown Artist',
                  albumName: track['parentTitle'] ?? 'Unknown Album',
                  duration: _parseDuration(track['duration']),
                  trackNumber: track['index'] is int
                      ? track['index']
                      : (int.tryParse(track['index']?.toString() ?? '0') ?? 0),
                  imageUrl: track['thumb'] != null
                      ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else {
        // Get all music libraries first, then get tracks from each (with limit to avoid too many results)
        final libraries = await getLibraries();
        for (final library in libraries) {
          if (library.collectionType == 'music') {
            final response = await _dio.get(
              '$_serverUrl/library/sections/${library.id}/all',
              queryParameters: {
                'X-Plex-Token': _token,
                'type': '10', // Track type in Plex
                'X-Plex-Container-Size': (limit ?? 100)
                    .toString(), // Default limit to prevent huge responses
                if (startIndex != null)
                  'X-Plex-Container-Start': startIndex.toString(),
              },
            );

            final tracks =
                response.data['MediaContainer']['Metadata'] as List? ?? [];
            allTracks.addAll(
              tracks
                  .map(
                    (track) => Track(
                      id: track['ratingKey'].toString(),
                      name: track['title'],
                      artistName: track['grandparentTitle'] ?? 'Unknown Artist',
                      albumName: track['parentTitle'] ?? 'Unknown Album',
                      duration: _parseDuration(track['duration']),
                      trackNumber: track['index'] is int
                          ? track['index']
                          : (int.tryParse(track['index']?.toString() ?? '0') ??
                                0),
                      imageUrl: track['thumb'] != null
                          ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token'
                          : null,
                    ),
                  )
                  .toList(),
            );
          }
        }
      }

      return allTracks;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex tracks: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/playlists',
        queryParameters: {'X-Plex-Token': _token, 'playlistType': 'audio'},
      );

      final playlists =
          response.data['MediaContainer']['Metadata'] as List? ?? [];
      return playlists
          .map(
            (playlist) => Playlist(
              id: playlist['ratingKey'].toString(),
              name: playlist['title'],
              imageUrl: playlist['composite'] != null
                  ? '$_serverUrl${playlist['composite']}?X-Plex-Token=$_token'
                  : null,
              trackCount: playlist['leafCount'] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex playlists: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/playlists/$playlistId/items',
        queryParameters: {'X-Plex-Token': _token},
      );

      final tracks = response.data['MediaContainer']['Metadata'] as List? ?? [];
      return tracks
          .map(
            (track) => Track(
              id: track['ratingKey'].toString(),
              name: track['title'],
              artistName: track['grandparentTitle'] ?? 'Unknown Artist',
              albumName: track['parentTitle'] ?? 'Unknown Album',
              duration: _parseDuration(track['duration']),
              trackNumber: track['index'] is int
                  ? track['index']
                  : (int.tryParse(track['index']?.toString() ?? '0') ?? 0),
              imageUrl: track['thumb'] != null
                  ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token'
                  : null,
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex playlist tracks: $e');
      }
      return [];
    }
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    // Synchronous fallback - use universal transcode
    // For best results, use getPreferredStreamUrl instead
    return getUniversalStreamUrl(trackId, bitrate: bitrate ?? 192);
  }

  /// Get the best stream URL (async version that fetches part ID)
  /// This is what your bash script uses - Method 3 (Direct File)
  Future<String> getPreferredStreamUrl(String trackId, {int? bitrate}) async {
    final partId = await _getTrackPartId(trackId);
    
    if (partId != null) {
      if (kDebugMode) {
        print('Using direct file stream with part ID: $partId');
      }
      return getDirectPartUrl(partId);
    }
    
    if (kDebugMode) {
      print('Part ID not found, using universal transcode');
    }
    return getUniversalStreamUrl(trackId, bitrate: bitrate ?? 192);
  }

  /// Direct stream fallback (if you happen to have partId)
  String getDirectStreamUrl(String partId) {
    return getDirectPartUrl(partId);
  }

  /// Get transcoded stream URL with specific format and bitrate (deprecated approach)
  String getTranscodedStreamUrl(
    String trackId, {
    String format = 'mp3',
    int? bitrate,
  }) {
    final params = <String, String>{'X-Plex-Token': _token!, 'format': format};

    if (bitrate != null) {
      params['audioBitrate'] = bitrate.toString();
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_serverUrl/library/metadata/$trackId/file.$format?$queryString';
  }

  /// Get universal stream URL using Plex's universal transcode endpoint
  String getUniversalStreamUrl(String trackId, {int? bitrate}) {
    final audioBitrate = bitrate ?? 192;
    return '$_serverUrl/audio/:/transcode/universal/start.mp3'
        '?path=/library/metadata/$trackId'
        '&mediaIndex=0'
        '&partIndex=0'
        '&protocol=http'
        '&directPlay=0'
        '&directStream=0'
        '&audioBitrate=$audioBitrate'
        '&X-Plex-Token=$_token';
  }

  /// Get direct part file URL (requires part ID from track metadata)
  /// THIS IS METHOD 3 FROM YOUR BASH SCRIPT - THE ONE THAT WORKS!
  String getDirectPartUrl(String partId) {
    return '$_serverUrl/library/parts/$partId/file.mp3?X-Plex-Token=$_token';
  }

  /// Get download URL
  String getDownloadUrl(String trackId) {
    return '$_serverUrl/library/metadata/$trackId/download?X-Plex-Token=$_token';
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    return [
      // Method 2 - Universal transcode (high quality)
      getUniversalStreamUrl(trackId, bitrate: 192),
      // Method 2 - Universal transcode (standard quality)  
      getUniversalStreamUrl(trackId, bitrate: 128),
      // Method 4 - Download URL as final fallback
      getDownloadUrl(trackId),
    ];
  }

  /// Get alternative stream URLs with async part ID fetching
  Future<List<String>> getAlternativeStreamUrlsAsync(String trackId, {String? partId}) async {
    // Fetch part ID if not provided
    final actualPartId = partId ?? await _getTrackPartId(trackId);
    
    return [
      // Method 3 from bash - most reliable if we have part ID
      if (actualPartId != null) getDirectPartUrl(actualPartId),
      // Method 2 - Universal transcode
      getUniversalStreamUrl(trackId, bitrate: 192),
      // Method 4 - Download URL
      getDownloadUrl(trackId),
      // Lower bitrate fallback
      getUniversalStreamUrl(trackId, bitrate: 128),
    ];
  }

  @override
  String getImageUrl(
    String itemId, {
    String type = 'Primary',
    int? width,
    int? height,
  }) {
    String url =
        '$_serverUrl/library/metadata/$itemId/thumb?X-Plex-Token=$_token';
    if (width != null && height != null) {
      url += '&width=$width&height=$height';
    }
    return url;
  }

  @override
  Future<SearchResults> search(
    String query, {
    List<String>? includeItemTypes,
    int? limit,
  }) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/search',
        queryParameters: {
          'X-Plex-Token': _token,
          'query': query,
          if (limit != null) 'limit': limit.toString(),
        },
      );

      final results =
          response.data['MediaContainer']['Metadata'] as List? ?? [];

      final albums = <Album>[];
      final artists = <Artist>[];
      final tracks = <Track>[];

      for (final item in results) {
        switch (item['type']) {
          case 'album':
            albums.add(
              Album(
                id: item['ratingKey'].toString(),
                name: item['title'],
                artistName: item['parentTitle'] ?? 'Unknown Artist',
                year: item['year'],
                imageUrl: item['thumb'] != null
                    ? '$_serverUrl${item['thumb']}?X-Plex-Token=$_token'
                    : null,
              ),
            );
            break;
          case 'artist':
            artists.add(
              Artist(
                id: item['ratingKey'].toString(),
                name: item['title'],
                imageUrl: item['thumb'] != null
                    ? '$_serverUrl${item['thumb']}?X-Plex-Token=$_token'
                    : null,
              ),
            );
            break;
          case 'track':
            tracks.add(
              Track(
                id: item['ratingKey'].toString(),
                name: item['title'],
                artistName: item['grandparentTitle'] ?? 'Unknown Artist',
                albumName: item['parentTitle'] ?? 'Unknown Album',
                duration: (item['duration'] ?? 0) ~/ 1000,
                trackNumber: item['index'],
                imageUrl: item['thumb'] != null
                    ? '$_serverUrl${item['thumb']}?X-Plex-Token=$_token'
                    : null,
              ),
            );
            break;
        }
      }

      return SearchResults(albums: albums, artists: artists, tracks: tracks);
    } catch (e) {
      if (kDebugMode) {
        print('Error searching Plex: $e');
      }
      return SearchResults();
    }
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/',
        queryParameters: {'X-Plex-Token': _token},
      );

      final container = response.data['MediaContainer'];
      return ServerInfo(
        name: container['friendlyName'] ?? 'Plex Server',
        version: container['version'] ?? 'Unknown',
        id: container['machineIdentifier'] ?? _machineIdentifier ?? 'unknown',
        type: ServerType.plex,
      );
    } catch (e) {
      return ServerInfo(
        name: 'Plex Server',
        version: 'Unknown',
        id: _machineIdentifier ?? 'unknown',
        type: ServerType.plex,
      );
    }
  }

  @override
  get currentServer => {
    'url': _serverUrl,
    'token': _token,
    'machineIdentifier': _machineIdentifier,
  };

  @override
  void clearAuth() {
    _token = null;
    _machineIdentifier = null;
    _serverUrl = null;
  }

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    if (_serverUrl == null || _token == null) {
      throw Exception('Server not configured');
    }

    if (kDebugMode) {
      print(
        'PlexService.toggleFavorite: itemId=$itemId, isFavorite=$isFavorite',
      );
      print('Server URL: $_serverUrl');
    }

    try {
      // Plex uses PUT method for toggling favorites
      // The endpoint is /library/metadata/{itemId}/favorite
      final method = isFavorite ? 'DELETE' : 'PUT';
      final url = '$_serverUrl/library/metadata/$itemId/favorite';

      if (kDebugMode) {
        print('Making $method request to: $url');
      }

      final response = await _dio.request(
        url,
        options: Options(method: method, headers: {'X-Plex-Token': _token}),
      );

      final success = response.statusCode == 200;

      if (kDebugMode) {
        print('Plex response: ${response.statusCode}, success: $success');
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite in Plex: $e');
      }
      return false;
    }
  }
}