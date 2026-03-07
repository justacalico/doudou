import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../models/jellyfin_models.dart';

/// Lightweight Plex client used by the Plex backend.
///
/// This is adapted from the upstream Doudou project and only
/// exposes the operations Harmony needs.
class PlexService {
  final Dio _dio;
  String? _serverUrl;
  String? _token;
  String? _machineIdentifier;

  PlexService() : _dio = Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 30);

    _dio.options.headers['Accept'] = 'application/json';
    _dio.options.headers['X-Plex-Client-Identifier'] = 'doudou';
    _dio.options.headers['X-Plex-Product'] = 'Doudou';
    _dio.options.headers['X-Plex-Version'] = '1.0.0';

    if (Platform.isLinux) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
  }

  /// Configure the service with a base URL and Plex token.
  void configure({
    required String serverUrl,
    required String token,
  }) {
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    _token = token;
  }

  /// Helper to safely parse durations (Plex reports milliseconds).
  int _parseDuration(dynamic duration) {
    if (duration == null) return 0;
    if (duration is int) return duration ~/ 1000;
    if (duration is String) {
      final parsed = int.tryParse(duration);
      return parsed != null ? parsed ~/ 1000 : 0;
    }
    return 0;
  }

  Future<String?> _getTrackPartKey(String trackId) async {
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
            final partKey = part[0]['key'];
            return partKey?.toString();
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

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
            return partId?.toString();
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Quick probe call to confirm the server and token are valid.
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
          _machineIdentifier =
              response.data['MediaContainer']['machineIdentifier']?.toString();
          return true;
        } else if (response.data is String &&
            (response.data as String).contains('MediaContainer')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Library>> getLibraries() async {
    try {
      final response = await _dio.get(
        '$_serverUrl/library/sections',
        queryParameters: {'X-Plex-Token': _token},
      );

      final sections = response.data['MediaContainer']['Directory'] as List;
      return sections
          .where((section) => section['type'] == 'artist')
          .map(
            (section) => Library(
              id: section['key'].toString(),
              name: section['title'] as String,
              collectionType: 'music',
              imageUrl: null,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Album>> getAlbums({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      final allAlbums = <Album>[];

      if (libraryId != null) {
        final response = await _dio.get(
          '$_serverUrl/library/sections/$libraryId/all',
          queryParameters: {
            'X-Plex-Token': _token,
            'type': '9',
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
                  name: album['title'] as String,
                  artistName: album['parentTitle'] ?? 'Unknown Artist',
                  year: album['year'] is int
                      ? album['year'] as int
                      : (int.tryParse(album['year']?.toString() ?? '0') ?? 0),
                  imageUrl: album['thumb'] != null
                      ? '$_serverUrl${album['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else {
        final libraries = await getLibraries();
        for (final library in libraries) {
          if (library.collectionType != 'music') continue;
          final response = await _dio.get(
            '$_serverUrl/library/sections/${library.id}/all',
            queryParameters: {
              'X-Plex-Token': _token,
              'type': '9',
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
                    name: album['title'] as String,
                    artistName: album['parentTitle'] ?? 'Unknown Artist',
                    year: album['year'] is int
                        ? album['year'] as int
                        : (int.tryParse(album['year']?.toString() ?? '0') ?? 0),
                    imageUrl: album['thumb'] != null
                        ? '$_serverUrl${album['thumb']}?X-Plex-Token=$_token'
                        : null,
                  ),
                )
                .toList(),
          );
        }
      }

      return allAlbums;
    } catch (_) {
      return [];
    }
  }

  Future<List<Artist>> getArtists({
    String? libraryId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      final allArtists = <Artist>[];

      if (libraryId != null) {
        final response = await _dio.get(
          '$_serverUrl/library/sections/$libraryId/all',
          queryParameters: {
            'X-Plex-Token': _token,
            'type': '8',
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
                  name: artist['title'] as String,
                  imageUrl: artist['thumb'] != null
                      ? '$_serverUrl${artist['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else {
        final libraries = await getLibraries();
        for (final library in libraries) {
          if (library.collectionType != 'music') continue;
          final response = await _dio.get(
            '$_serverUrl/library/sections/${library.id}/all',
            queryParameters: {
              'X-Plex-Token': _token,
              'type': '8',
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
                    name: artist['title'] as String,
                    imageUrl: artist['thumb'] != null
                        ? '$_serverUrl${artist['thumb']}?X-Plex-Token=$_token'
                        : null,
                  ),
                )
                .toList(),
          );
        }
      }

      return allArtists;
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> getTracks({
    String? libraryId,
    String? parentId,
    int? limit,
    int? startIndex,
  }) async {
    try {
      final allTracks = <Track>[];

      if (parentId != null) {
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
                  name: track['title'] as String,
                  artistName: track['grandparentTitle'] ?? 'Unknown Artist',
                  albumName: track['parentTitle'] ?? 'Unknown Album',
                  duration: _parseDuration(track['duration']),
                  trackNumber: track['index'] is int
                      ? track['index'] as int
                      : (int.tryParse(track['index']?.toString() ?? '0') ?? 0),
                  imageUrl: track['thumb'] != null
                      ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else if (libraryId != null) {
        final response = await _dio.get(
          '$_serverUrl/library/sections/$libraryId/all',
          queryParameters: {
            'X-Plex-Token': _token,
            'type': '10',
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
                  name: track['title'] as String,
                  artistName: track['grandparentTitle'] ?? 'Unknown Artist',
                  albumName: track['parentTitle'] ?? 'Unknown Album',
                  duration: _parseDuration(track['duration']),
                  trackNumber: track['index'] is int
                      ? track['index'] as int
                      : (int.tryParse(track['index']?.toString() ?? '0') ?? 0),
                  imageUrl: track['thumb'] != null
                      ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token'
                      : null,
                ),
              )
              .toList(),
        );
      } else {
        final libraries = await getLibraries();
        for (final library in libraries) {
          if (library.collectionType != 'music') continue;
          final response = await _dio.get(
            '$_serverUrl/library/sections/${library.id}/all',
            queryParameters: {
              'X-Plex-Token': _token,
              'type': '10',
              'X-Plex-Container-Size': (limit ?? 100).toString(),
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
                    name: track['title'] as String,
                    artistName: track['grandparentTitle'] ?? 'Unknown Artist',
                    albumName: track['parentTitle'] ?? 'Unknown Album',
                    duration: _parseDuration(track['duration']),
                    trackNumber: track['index'] is int
                        ? track['index'] as int
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

      return allTracks;
    } catch (_) {
      return [];
    }
  }

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
              name: playlist['title'] as String,
              imageUrl: playlist['composite'] != null
                  ? '$_serverUrl${playlist['composite']}?X-Plex-Token=$_token'
                  : null,
              trackCount: playlist['leafCount'] ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

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
              name: track['title'] as String,
              artistName: track['grandparentTitle'] ?? 'Unknown Artist',
              albumName: track['parentTitle'] ?? 'Unknown Album',
              duration: _parseDuration(track['duration']),
              trackNumber: track['index'] is int
                  ? track['index'] as int
                  : (int.tryParse(track['index']?.toString() ?? '0') ?? 0),
              imageUrl: track['thumb'] != null
                  ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token'
                  : null,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  String getStreamUrl(String trackId, {int? bitrate}) {
    return getDownloadUrl(trackId);
  }

  Future<String> getBestStreamUrl(String trackId, {int? bitrate}) async {
    final partKey = await _getTrackPartKey(trackId);
    if (partKey != null) {
      return getDirectStreamWithPartKey(partKey);
    }

    final partId = await _getTrackPartId(trackId);
    if (partId != null) {
      return getDirectPartUrl(partId);
    }

    final universal = getUniversalStreamUrl(trackId, bitrate: bitrate);
    if (universal.isNotEmpty) {
      return universal;
    }

    return getDownloadUrl(trackId);
  }

  String getDirectStreamUrl(String trackId) {
    return getDownloadUrl(trackId);
  }

  Map<String, String> getAuthHeaders() {
    final token = _token;
    if (token == null) return const {};
    return {'X-Plex-Token': token, 'Accept': 'application/json'};
  }

  String getDownloadUrl(String trackId) {
    return '$_serverUrl/library/metadata/$trackId/download?X-Plex-Token=$_token';
  }

  String getDirectPartUrl(String partId) {
    return '$_serverUrl/library/parts/$partId/file.mp3?X-Plex-Token=$_token';
  }

  String getDirectStreamWithPartKey(String partKey) {
    return '$_serverUrl$partKey?X-Plex-Token=$_token';
  }

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

  Future<SearchResults> search(
    String query, {
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
          response.data['MediaContainer']['Metadata'] as List? ?? const [];

      final albums = <Album>[];
      final artists = <Artist>[];
      final tracks = <Track>[];

      for (final item in results) {
        switch (item['type']) {
          case 'album':
            albums.add(
              Album(
                id: item['ratingKey'].toString(),
                name: item['title'] as String,
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
                name: item['title'] as String,
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
                name: item['title'] as String,
                artistName: item['grandparentTitle'] ?? 'Unknown Artist',
                albumName: item['parentTitle'] ?? 'Unknown Album',
                duration: _parseDuration(item['duration']),
                trackNumber: item['index'] as int?,
                imageUrl: item['thumb'] != null
                    ? '$_serverUrl${item['thumb']}?X-Plex-Token=$_token'
                    : null,
              ),
            );
            break;
        }
      }

      return SearchResults(albums: albums, artists: artists, tracks: tracks);
    } catch (_) {
      return const SearchResults();
    }
  }

  String? get machineIdentifier => _machineIdentifier;
}
