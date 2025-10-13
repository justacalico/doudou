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
    
    // Platform-specific configurations
    if (Platform.isLinux) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
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

  @override
  Future<bool> authenticate(String serverUrl, String identifier, String credential) async {
    try {
      _serverUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
      _token = credential; // For Plex, credential is the X-Plex-Token
      
      if (kDebugMode) {
        print('Plex: Attempting authentication to $_serverUrl with token');
      }
      
      // Try to get server info using a more standard endpoint
      final response = await _dio.get(
        '$_serverUrl/',
        queryParameters: {'X-Plex-Token': _token},
      );
      
      if (response.statusCode == 200 && response.data['MediaContainer'] != null) {
        _machineIdentifier = response.data['MediaContainer']['machineIdentifier'];
        if (kDebugMode) {
          print('Plex: Authentication successful. Machine ID: $_machineIdentifier');
        }
        return true;
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
    _serverUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
  }

  @override
  Future<bool> validateCredentials() async {
    if (_serverUrl == null || _token == null) return false;
    
    try {
      final response = await _dio.get(
        '$_serverUrl/identity',
        queryParameters: {'X-Plex-Token': _token},
      );
      
      return response.statusCode == 200;
    } catch (e) {
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
          .where((section) => section['type'] == 'artist') // Only music libraries
          .map((section) => Library(
                id: section['key'].toString(),
                name: section['title'],
                collectionType: 'music',
                imageUrl: null,
              ))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex libraries: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
    try {
      final String endpoint = libraryId != null 
          ? '$_serverUrl/library/sections/$libraryId/albums'
          : '$_serverUrl/library/sections/albums';
          
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'X-Plex-Token': _token,
          if (limit != null) 'X-Plex-Container-Size': limit.toString(),
          if (startIndex != null) 'X-Plex-Container-Start': startIndex.toString(),
        },
      );
      
      final albums = response.data['MediaContainer']['Metadata'] as List? ?? [];
      return albums.map((album) => Album(
        id: album['ratingKey'].toString(),
        name: album['title'],
        artistName: album['parentTitle'] ?? 'Unknown Artist',
        year: album['year'],
        imageUrl: album['thumb'] != null ? '$_serverUrl${album['thumb']}?X-Plex-Token=$_token' : null,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex albums: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Artist>> getArtists({String? libraryId, int? limit, int? startIndex}) async {
    try {
      final String endpoint = libraryId != null 
          ? '$_serverUrl/library/sections/$libraryId/all'
          : '$_serverUrl/library/sections/all';
          
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'X-Plex-Token': _token,
          'type': '8', // Artist type in Plex
          if (limit != null) 'X-Plex-Container-Size': limit.toString(),
          if (startIndex != null) 'X-Plex-Container-Start': startIndex.toString(),
        },
      );
      
      final artists = response.data['MediaContainer']['Metadata'] as List? ?? [];
      return artists.map((artist) => Artist(
        id: artist['ratingKey'].toString(),
        name: artist['title'],
        imageUrl: artist['thumb'] != null ? '$_serverUrl${artist['thumb']}?X-Plex-Token=$_token' : null,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex artists: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Track>> getTracks({String? libraryId, String? parentId, int? limit, int? startIndex}) async {
    try {
      String endpoint;
      if (parentId != null) {
        endpoint = '$_serverUrl/library/metadata/$parentId/children';
      } else if (libraryId != null) {
        endpoint = '$_serverUrl/library/sections/$libraryId/all';
      } else {
        endpoint = '$_serverUrl/library/sections/all';
      }
      
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'X-Plex-Token': _token,
          if (parentId == null) 'type': '10', // Track type in Plex
          if (limit != null) 'X-Plex-Container-Size': limit.toString(),
          if (startIndex != null) 'X-Plex-Container-Start': startIndex.toString(),
        },
      );
      
      final tracks = response.data['MediaContainer']['Metadata'] as List? ?? [];
      return tracks.map((track) => Track(
        id: track['ratingKey'].toString(),
        name: track['title'],
        artistName: track['grandparentTitle'] ?? 'Unknown Artist',
        albumName: track['parentTitle'] ?? 'Unknown Album',
        duration: (track['duration'] ?? 0) ~/ 1000, // Convert from ms to seconds
        trackNumber: track['index'] is int ? track['index'] : (int.tryParse(track['index']?.toString() ?? '0') ?? 0),
        imageUrl: track['thumb'] != null ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token' : null,
      )).toList();
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
        queryParameters: {
          'X-Plex-Token': _token,
          'playlistType': 'audio',
        },
      );
      
      final playlists = response.data['MediaContainer']['Metadata'] as List? ?? [];
      return playlists.map((playlist) => Playlist(
        id: playlist['ratingKey'].toString(),
        name: playlist['title'],
        imageUrl: playlist['composite'] != null ? '$_serverUrl${playlist['composite']}?X-Plex-Token=$_token' : null,
        trackCount: playlist['leafCount'] ?? 0,
      )).toList();
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
      return tracks.map((track) => Track(
        id: track['ratingKey'].toString(),
        name: track['title'],
        artistName: track['grandparentTitle'] ?? 'Unknown Artist',
        albumName: track['parentTitle'] ?? 'Unknown Album',
        duration: (track['duration'] ?? 0) ~/ 1000,
        trackNumber: track['index'],
        imageUrl: track['thumb'] != null ? '$_serverUrl${track['thumb']}?X-Plex-Token=$_token' : null,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Plex playlist tracks: $e');
      }
      return [];
    }
  }

  @override
  String getStreamUrl(String trackId, {int? bitrate}) {
    return '$_serverUrl/library/metadata/$trackId/file.mp3?X-Plex-Token=$_token';
  }

  @override
  String getImageUrl(String itemId, {String type = 'Primary', int? width, int? height}) {
    String url = '$_serverUrl/library/metadata/$itemId/thumb?X-Plex-Token=$_token';
    if (width != null && height != null) {
      url += '&width=$width&height=$height';
    }
    return url;
  }

  @override
  Future<SearchResults> search(String query, {List<String>? includeItemTypes, int? limit}) async {
    try {
      final response = await _dio.get(
        '$_serverUrl/search',
        queryParameters: {
          'X-Plex-Token': _token,
          'query': query,
          if (limit != null) 'limit': limit.toString(),
        },
      );
      
      final results = response.data['MediaContainer']['Metadata'] as List? ?? [];
      
      final albums = <Album>[];
      final artists = <Artist>[];
      final tracks = <Track>[];
      
      for (final item in results) {
        switch (item['type']) {
          case 'album':
            albums.add(Album(
              id: item['ratingKey'].toString(),
              name: item['title'],
              artistName: item['parentTitle'] ?? 'Unknown Artist',
              year: item['year'],
              imageUrl: item['thumb'] != null ? '$_serverUrl${item['thumb']}?X-Plex-Token=$_token' : null,
            ));
            break;
          case 'artist':
            artists.add(Artist(
              id: item['ratingKey'].toString(),
              name: item['title'],
              imageUrl: item['thumb'] != null ? '$_serverUrl${item['thumb']}?X-Plex-Token=$_token' : null,
            ));
            break;
          case 'track':
            tracks.add(Track(
              id: item['ratingKey'].toString(),
              name: item['title'],
              artistName: item['grandparentTitle'] ?? 'Unknown Artist',
              albumName: item['parentTitle'] ?? 'Unknown Album',
              duration: (item['duration'] ?? 0) ~/ 1000,
              trackNumber: item['index'],
              imageUrl: item['thumb'] != null ? '$_serverUrl${item['thumb']}?X-Plex-Token=$_token' : null,
            ));
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
}