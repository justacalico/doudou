import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';

class JellyfinService {
  late Dio _dio;
  JellyfinServer? _server;

  JellyfinService() {
    _dio = Dio();
  }

  void setServer(JellyfinServer server) {
    _server = server;
    _dio.options.baseUrl = server.serverUrl;
    
    if (server.accessToken != null) {
      _dio.options.headers['X-Emby-Token'] = server.accessToken;
    }
  }

  Future<bool> authenticate(String serverUrl, String username, String password) async {
    try {
      _dio.options.baseUrl = serverUrl;
      
      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {
          'Username': username,
          'Pw': password,
        },
        options: Options(
          headers: {
            'X-Emby-Authorization': 'MediaBrowser Client="Doudou", Device="Flutter", DeviceId="doudou-flutter", Version="1.0.0"',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _server = JellyfinServer(
          serverUrl: serverUrl,
          userId: data['User']['Id'],
          accessToken: data['AccessToken'],
        );
        
        _dio.options.headers['X-Emby-Token'] = _server!.accessToken;
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Authentication error: $e');
      }
    }
    return false;
  }

  Future<List<Album>> getAlbums() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'IncludeItemTypes': 'MusicAlbum',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Album.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching albums: $e');
      }
    }
    return [];
  }

  Future<List<Track>> getAlbumTracks(String albumId) async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Users/${_server!.userId}/Items',
        queryParameters: {
          'ParentId': albumId,
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,ImageTags',
          'SortBy': 'IndexNumber',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching album tracks: $e');
      }
    }
    return [];
  }

  Future<List<Artist>> getArtists() async {
    if (_server == null) throw Exception('Server not configured');

    try {
      final response = await _dio.get(
        '/Artists',
        queryParameters: {
          'userId': _server!.userId,
          'Fields': 'PrimaryImageAspectRatio,ImageTags',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['Items'];
        return items.map((item) => Artist.fromJson(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching artists: $e');
      }
    }
    return [];
  }

  String getImageUrl(String itemId, {int? width, int? height}) {
    if (_server == null) return '';
    
    final params = <String, String>{};
    if (width != null) params['width'] = width.toString();
    if (height != null) params['height'] = height.toString();
    
    final queryString = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    
    return '${_server!.serverUrl}/Items/$itemId/Images/Primary$queryString';
  }

  String getStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Use the stream endpoint with specific parameters for better compatibility
    final params = {
      'UserId': _server!.userId,
      'DeviceId': 'doudou-flutter',
      'api_key': _server!.accessToken,
      'Container': 'mp3,aac,m4a,flac,webm,mp4,ogg', // Specify supported containers
      'AudioCodec': 'mp3,aac,flac,vorbis,opus',      // Specify supported codecs
      'AudioBitRate': '128000',                       // Set reasonable bitrate
      'MaxAudioChannels': '2',                        // Stereo
      'TranscodingContainer': 'mp3',                  // Fallback container
      'TranscodingProtocol': 'http',                  // Use HTTP protocol
    };
    
    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    
    return '${_server!.serverUrl}/Audio/$itemId/stream?$queryString';
  }

  String getDirectStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Alternative: direct download URL (no transcoding)
    return '${_server!.serverUrl}/Items/$itemId/Download?api_key=${_server!.accessToken}';
  }

  String getUniversalStreamUrl(String itemId) {
    if (_server == null) return '';
    
    // Alternative: universal endpoint with minimal params
    return '${_server!.serverUrl}/Audio/$itemId/universal?UserId=${_server!.userId}&DeviceId=doudou-flutter&api_key=${_server!.accessToken}';
  }

  JellyfinServer? get currentServer => _server;
}
