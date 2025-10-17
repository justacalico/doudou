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
      params['type'] = 'alphabeticalByName'; // Required parameter for getAlbumList2
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
          isFavorite: song['starred'] != null, // Navidrome uses 'starred' field with timestamp or null
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
          isFavorite: song['starred'] != null, // Navidrome uses 'starred' field with timestamp or null
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
      
      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        if (kDebugMode) {
          print('No subsonic-response in playlists response');
        }
        return [];
      }
      
      final playlistsContainer = subsonicResponse['playlists'];
      if (playlistsContainer == null) {
        if (kDebugMode) {
          print('No playlists in subsonic response');
        }
        return [];
      }
      
      final playlists = playlistsContainer['playlist'];
      if (playlists == null) {
        if (kDebugMode) {
          print('No playlist array in playlists - this might be normal for empty results');
        }
        return [];
      }
      
      // Handle case where playlists might be a single object instead of array
      final playlistsList = playlists is List ? playlists : [playlists];
      
      return playlistsList.map((playlist) => Playlist(
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
      
      // Safely navigate the response structure
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null) {
        if (kDebugMode) {
          print('No subsonic-response in playlist tracks response');
        }
        return [];
      }
      
      final playlist = subsonicResponse['playlist'];
      if (playlist == null) {
        if (kDebugMode) {
          print('No playlist in subsonic response');
        }
        return [];
      }
      
      final songs = playlist['entry'];
      if (songs == null) {
        if (kDebugMode) {
          print('No entry array in playlist - this might be normal for empty playlists');
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
        isFavorite: song['starred'] != null, // Navidrome uses 'starred' field with timestamp or null
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

  /// Get direct download URL (no transcoding)
  String getDirectStreamUrl(String trackId) {
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = trackId;
    
    return '$_serverUrl/rest/download?${Uri(queryParameters: params).query}';
  }

  /// Get transcoded stream URL with specific format
  String getTranscodedStreamUrl(String trackId, {String format = 'mp3', int? bitrate}) {
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
        isFavorite: song['starred'] != null, // Navidrome uses 'starred' field with timestamp or null
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

  @override
  Future<bool> toggleFavorite(String itemId, bool isFavorite) async {
    if (_serverUrl == null || _username == null || _token == null || _salt == null) {
      throw Exception('Server not configured');
    }

    if (kDebugMode) {
      print('NavidromeService.toggleFavorite: itemId=$itemId, isFavorite=$isFavorite');
      print('Server URL: $_serverUrl');
      print('Username: $_username');
    }

    try {
      // Navidrome uses star/unstar endpoints for favorites
      final action = isFavorite ? 'unstar' : 'star';
      final params = Map<String, dynamic>.from(_baseParams);
      params['id'] = itemId;
      final url = '$_serverUrl/rest/$action';

      if (kDebugMode) {
        print('Making GET request to: $url');
        print('Action: $action');
        print('Params: $params');
      }

      final response = await _dio.get(
        url,
        queryParameters: params,
      );

      if (kDebugMode) {
        print('Navidrome response: ${response.statusCode}');
        print('Response data: ${response.data}');
      }

      // Check for success response in Navidrome format
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['subsonic-response'] != null) {
          final subsonicResponse = data['subsonic-response'];
          final success = subsonicResponse['status'] == 'ok';
          
          if (kDebugMode) {
            print('Navidrome subsonic status: ${subsonicResponse['status']}, success: $success');
          }
          
          return success;
        }
      }
      
      if (kDebugMode) {
        print('Navidrome: No valid subsonic response found');
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite in Navidrome: $e');
      }
      return false;
    }
  }

  Future<Playlist?> createPlaylist(String name) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['name'] = name;
      
      final response = await _dio.get('$_serverUrl/rest/createPlaylist', queryParameters: params);
      
      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      if (subsonicResponse == null || subsonicResponse['status'] != 'ok') {
        if (kDebugMode) {
          print('Failed to create playlist in Navidrome: ${subsonicResponse?['error']}');
        }
        return null;
      }
      
      final playlist = subsonicResponse['playlist'];
      if (playlist != null) {
        return Playlist(
          id: playlist['id'],
          name: playlist['name'],
          imageUrl: playlist['coverArt'] != null ? '$_serverUrl/rest/getCoverArt?id=${playlist['coverArt']}&${Uri(queryParameters: _baseParams).query}' : null,
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
      if (kDebugMode) {
        print('Error creating playlist in Navidrome: $e');
      }
      return null;
    }
  }

  @override
  Future<bool> addToPlaylist(String playlistId, String trackId) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['playlistId'] = playlistId;
      params['songIdToAdd'] = trackId;
      
      final response = await _dio.get('$_serverUrl/rest/updatePlaylist', queryParameters: params);
      
      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      return subsonicResponse != null && subsonicResponse['status'] == 'ok';
    } catch (e) {
      if (kDebugMode) {
        print('Error adding track to playlist in Navidrome: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> renamePlaylist(String playlistId, String newName) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['playlistId'] = playlistId;
      params['name'] = newName;
      
      final response = await _dio.get('$_serverUrl/rest/updatePlaylist', queryParameters: params);
      
      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      return subsonicResponse != null && subsonicResponse['status'] == 'ok';
    } catch (e) {
      if (kDebugMode) {
        print('Error renaming playlist in Navidrome: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> removePlaylist(String playlistId) async {
    try {
      final params = Map<String, dynamic>.from(_baseParams);
      params['id'] = playlistId;
      
      final response = await _dio.get('$_serverUrl/rest/deletePlaylist', queryParameters: params);
      
      // Check for successful response
      final subsonicResponse = response.data['subsonic-response'];
      return subsonicResponse != null && subsonicResponse['status'] == 'ok';
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting playlist in Navidrome: $e');
      }
      return false;
    }
  }

  @override
  List<String> getAlternativeStreamUrls(String trackId) {
    // Return Navidrome alternative stream URLs with different formats/bitrates
    final params = Map<String, dynamic>.from(_baseParams);
    params['id'] = trackId;
    
    return [
      getStreamUrl(trackId),                    // Primary stream URL
      getStreamUrl(trackId, bitrate: 192),     // Medium bitrate fallback
      getStreamUrl(trackId, bitrate: 128),     // Lower bitrate fallback
      '$_serverUrl/rest/download?${Uri(queryParameters: params).query}', // Direct download fallback
    ];
  }
}