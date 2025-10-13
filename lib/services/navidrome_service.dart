import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../models/jellyfin_models.dart';
import 'base_service.dart';

class NavidromeService implements BaseMediaService {
  late Dio _dio;
  String? _serverUrl;
  String? _username;
  String? _token;
  String? _salt;

  @override
  ServerType get serverType => ServerType.navidrome;

  NavidromeService() {
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
      _username = identifier;
      
      // Navidrome uses Subsonic API authentication
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
      
      if (response.statusCode == 200 && response.data['subsonic-response']['status'] == 'ok') {
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Navidrome authentication error: $e');
      }
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
  void setServer(String serverUrl) {
    _serverUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
  }

  @override
  Future<bool> validateCredentials() async {
    if (_serverUrl == null || _username == null || _token == null || _salt == null) return false;
    
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
      
      return response.statusCode == 200 && response.data['subsonic-response']['status'] == 'ok';
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
      
      final folders = response.data['subsonic-response']['musicFolders']['musicFolder'] as List;
      return folders.map((folder) => Library(
        id: folder['id'].toString(),
        name: folder['name'],
        collectionType: 'music',
        imageUrl: null,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Navidrome libraries: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Album>> getAlbums({String? libraryId, int? limit, int? startIndex}) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      if (libraryId != null) params['musicFolderId'] = libraryId;
      if (limit != null) params['size'] = limit.toString();
      if (startIndex != null) params['offset'] = startIndex.toString();
      
      final response = await _dio.get('$_serverUrl/rest/getAlbumList2', queryParameters: params);
      
      if (kDebugMode) {
        print('Navidrome getAlbums response: ${response.data}');
      }
      
      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        if (kDebugMode) {
          print('No subsonic-response in albums response');
        }
        return [];
      }
      
      final albumList2 = subsonicResponse['albumList2'];
      if (albumList2 == null) {
        if (kDebugMode) {
          print('No albumList2 in subsonic response');
        }
        return [];
      }
      
      final albums = albumList2['album'];
      if (albums == null) {
        if (kDebugMode) {
          print('No album array in albumList2 - this might be normal for empty results');
        }
        return [];
      }
      
      // Handle case where albums might be a single object instead of array
      final albumsList = albums is List ? albums : [albums];
      
      return albumsList.map((album) => Album(
        id: album['id'],
        name: album['name'],
        artistName: album['artist'] ?? 'Unknown Artist',
        year: album['year'],
        imageUrl: album['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${album['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Navidrome albums: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Artist>> getArtists({String? libraryId, int? limit, int? startIndex}) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      if (libraryId != null) params['musicFolderId'] = libraryId;
      
      final response = await _dio.get('$_serverUrl/rest/getArtists', queryParameters: params);
      
      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        if (kDebugMode) {
          print('No subsonic-response in artists response');
        }
        return [];
      }
      
      final artists = subsonicResponse['artists'];
      if (artists == null) {
        if (kDebugMode) {
          print('No artists in subsonic response');
        }
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
            artistList.add(Artist(
              id: artist['id'],
              name: artist['name'],
              imageUrl: artist['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${artist['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
            ));
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
      if (kDebugMode) {
        print('Error getting Navidrome artists: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Track>> getTracks({String? libraryId, String? parentId, int? limit, int? startIndex}) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      if (limit != null) params['size'] = limit.toString();
      if (startIndex != null) params['offset'] = startIndex.toString();
      
      Response response;
      if (parentId != null) {
        // Get songs from album
        params['id'] = parentId;
        response = await _dio.get('$_serverUrl/rest/getAlbum', queryParameters: params);
        
        final subsonicResponse = response.data['subsonic-response'];
        if (subsonicResponse == null) {
          if (kDebugMode) {
            print('No subsonic-response in album tracks response');
          }
          return [];
        }
        
        final album = subsonicResponse['album'];
        if (album == null) {
          if (kDebugMode) {
            print('No album in subsonic response');
          }
          return [];
        }
        
        final songs = album['song'];
        if (songs == null) {
          if (kDebugMode) {
            print('No songs in album - this might be normal for empty albums');
          }
          return [];
        }
        
        // Handle case where songs might be a single object instead of array
        final songsList = songs is List ? songs : [songs];
        
        return songsList.map((song) => Track(
          id: song['id'],
          name: song['title'],
          artistName: song['artist'] ?? 'Unknown Artist',
          albumName: song['album'] ?? 'Unknown Album',
          duration: song['duration'],
          trackNumber: song['track'],
          imageUrl: song['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
        )).toList();
      } else {
        // Get random songs or from library
        if (libraryId != null) params['musicFolderId'] = libraryId;
        params['size'] = (limit ?? 50).toString();
        
        response = await _dio.get('$_serverUrl/rest/getRandomSongs', queryParameters: params);
        
        final subsonicResponse = response.data['subsonic-response'];
        if (subsonicResponse == null) {
          if (kDebugMode) {
            print('No subsonic-response in random songs response');
          }
          return [];
        }
        
        final randomSongs = subsonicResponse['randomSongs'];
        if (randomSongs == null) {
          if (kDebugMode) {
            print('No randomSongs in subsonic response');
          }
          return [];
        }
        
        final songs = randomSongs['song'];
        if (songs == null) {
          if (kDebugMode) {
            print('No songs in randomSongs - this might be normal for empty results');
          }
          return [];
        }
        
        // Handle case where songs might be a single object instead of array
        final songsList = songs is List ? songs : [songs];
        
        return songsList.map((song) => Track(
          id: song['id'],
          name: song['title'],
          artistName: song['artist'] ?? 'Unknown Artist',
          albumName: song['album'] ?? 'Unknown Album',
          duration: song['duration'],
          trackNumber: song['track'],
          imageUrl: song['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
        )).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Navidrome tracks: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await _dio.get('$_serverUrl/rest/getPlaylists', queryParameters: _baseParams);
      
      final playlists = response.data['subsonic-response']['playlists']['playlist'] as List? ?? [];
      return playlists.map((playlist) => Playlist(
        id: playlist['id'],
        name: playlist['name'],
        imageUrl: playlist['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${playlist['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
        trackCount: playlist['songCount'] ?? 0,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Navidrome playlists: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['id'] = playlistId;
      
      final response = await _dio.get('$_serverUrl/rest/getPlaylist', queryParameters: params);
      
      final playlist = response.data['subsonic-response']['playlist'];
      final songs = playlist['entry'] as List? ?? [];
      
      return songs.map((song) => Track(
        id: song['id'],
        name: song['title'],
        artistName: song['artist'] ?? 'Unknown Artist',
        albumName: song['album'] ?? 'Unknown Album',
        duration: song['duration'],
        trackNumber: song['track'],
        imageUrl: song['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Navidrome playlist tracks: $e');
      }
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

  @override
  String getImageUrl(String itemId, {String type = 'Primary', int? width, int? height}) {
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = itemId;
    if (width != null) params['size'] = width.toString();
    
    return '$_serverUrl/rest/getCoverArt?${Uri(queryParameters: params).query}';
  }

  @override
  Future<SearchResults> search(String query, {List<String>? includeItemTypes, int? limit}) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['query'] = query;
      if (limit != null) params['count'] = limit.toString();
      
      final response = await _dio.get('$_serverUrl/rest/search3', queryParameters: params);
      
      final searchResult = response.data['subsonic-response']['searchResult3'];
      
      final albums = (searchResult['album'] as List? ?? []).map((album) => Album(
        id: album['id'],
        name: album['name'],
        artistName: album['artist'] ?? 'Unknown Artist',
        year: album['year'],
        imageUrl: album['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${album['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
      )).toList();
      
      final artists = (searchResult['artist'] as List? ?? []).map((artist) => Artist(
        id: artist['id'],
        name: artist['name'],
        imageUrl: artist['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${artist['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
      )).toList();
      
      final tracks = (searchResult['song'] as List? ?? []).map((song) => Track(
        id: song['id'],
        name: song['title'],
        artistName: song['artist'] ?? 'Unknown Artist',
        albumName: song['album'] ?? 'Unknown Album',
        duration: song['duration'],
        trackNumber: song['track'],
        imageUrl: song['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${song['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
      )).toList();
      
      return SearchResults(albums: albums, artists: artists, tracks: tracks);
    } catch (e) {
      if (kDebugMode) {
        print('Error searching Navidrome: $e');
      }
      return SearchResults();
    }
  }

  @override
  Future<ServerInfo> getServerInfo() async {
    try {
      final response = await _dio.get('$_serverUrl/rest/ping', queryParameters: _baseParams);
      
      final subsonicResponse = response.data['subsonic-response'];
      return ServerInfo(
        name: 'Navidrome Server',
        version: subsonicResponse['version'] ?? 'Unknown',
        id: _serverUrl ?? 'unknown',
        type: ServerType.navidrome,
      );
    } catch (e) {
      return ServerInfo(
        name: 'Navidrome Server',
        version: 'Unknown',
        id: _serverUrl ?? 'unknown',
        type: ServerType.navidrome,
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
}