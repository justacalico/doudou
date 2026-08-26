import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:doudou/services/players/plex_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlexAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    };

    if (path.contains('/library/sections/1/all')) {
      final data = {
        'MediaContainer': {
          'Metadata': [
            {
              'ratingKey': '30',
              'title': 'Track C',
              'duration': '90000',
              'grandparentTitle': 'Artist C',
              'parentTitle': 'Album C',
              'index': '3',
              'thumb': '/track-thumb.jpg',
            }
          ]
        }
      };
      return ResponseBody.fromString(jsonEncode(data), 200, headers: headers);
    }

    if (path.contains('/library/metadata/')) {
      final data = {
        'MediaContainer': {
          'Metadata': [
            {
              'ratingKey': '20',
              'title': 'Track B',
              'duration': 180000,
              'grandparentTitle': 'Artist B',
              'parentTitle': 'Album B',
              'index': 2,
              'thumb': '',
              'parentThumb': '/parent.jpg',
              'grandparentThumb': '/grand.jpg',
              'Media': [
                {
                  'Part': [
                    {
                      'key': '/library/parts/99/file.mp3',
                      'id': 99,
                    }
                  ]
                }
              ]
            }
          ]
        }
      };
      return ResponseBody.fromString(jsonEncode(data), 200, headers: headers);
    }

    if (path.contains('/playlists/')) {
      final data = {
        'MediaContainer': {
          'Metadata': [
            {
              'ratingKey': '5',
              'title': 'Track A',
              'duration': 125000,
              'grandparentTitle': 'Artist A',
              'parentTitle': 'Album A',
              'index': 1,
              'thumb': '/thumb.jpg',
            }
          ]
        }
      };
      return ResponseBody.fromString(jsonEncode(data), 200, headers: headers);
    }

    if (path.contains('/playlists')) {
      final data = {
        'MediaContainer': {
          'Metadata': [
            {
              'ratingKey': '10',
              'title': 'My Mix',
              'composite': '/playlist.jpg',
              'leafCount': 12,
            }
          ]
        }
      };
      return ResponseBody.fromString(jsonEncode(data), 200, headers: headers);
    }

    if (path.contains('/library/sections')) {
      final data = {
        'MediaContainer': {
          'Directory': [
            {
              'key': '1',
              'type': 'artist',
              'title': 'Music',
            }
          ]
        }
      };
      return ResponseBody.fromString(jsonEncode(data), 200, headers: headers);
    }

    if (path == 'https://plex.example/') {
      final data = {
        'MediaContainer': {'machineIdentifier': 'abc123'}
      };
      return ResponseBody.fromString(jsonEncode(data), 200, headers: headers);
    }

    return ResponseBody.fromString('{}', 404, headers: headers);
  }
}

Dio _fakeDio() {
  final dio = Dio();
  dio.httpClientAdapter = _FakePlexAdapter();
  return dio;
}

void main() {
  group('PlexService', () {
    test('configure sets serverUrl and token', () {
      final service = PlexService();
      service.configure(serverUrl: 'https://plex.example/', token: 'tok123');
      expect(service.getAuthHeaders(), containsPair('X-Plex-Token', 'tok123'));
    });

    test('getAuthHeaders returns empty map when not configured', () {
      final service = PlexService();
      expect(service.getAuthHeaders(), isEmpty);
    });

    test('validateCredentials returns true with a valid server', () async {
      final service = PlexService(dio: _fakeDio());
      service.configure(serverUrl: 'https://plex.example', token: 'tok123');
      expect(await service.validateCredentials(), isTrue);
    });

    test('getLibraries returns music libraries', () async {
      final service = PlexService(dio: _fakeDio());
      service.configure(serverUrl: 'https://plex.example', token: 'tok123');
      final libraries = await service.getLibraries();
      expect(libraries.length, 1);
      expect(libraries.first.id, '1');
      expect(libraries.first.name, 'Music');
      expect(libraries.first.collectionType, 'music');
    });

    test('getTracks with parentId returns parsed tracks', () async {
      final service = PlexService(dio: _fakeDio());
      service.configure(serverUrl: 'https://plex.example', token: 'tok123');
      final tracks = await service.getTracks(parentId: '20');
      expect(tracks.length, 1);
      expect(tracks.first.id, '20');
      expect(tracks.first.name, 'Track B');
      expect(tracks.first.duration, 180); // 180000 ms
      expect(tracks.first.trackNumber, 2);
      expect(tracks.first.imageUrl, isNotNull);
    });

    test('getTracks with libraryId falls back to track thumb', () async {
      final service = PlexService(dio: _fakeDio());
      service.configure(serverUrl: 'https://plex.example', token: 'tok123');
      final tracks = await service.getTracks(libraryId: '1');
      expect(tracks.length, 1);
      expect(tracks.first.name, 'Track C');
      expect(tracks.first.duration, 90); // string "90000" parsed
      expect(tracks.first.trackNumber, 3);
      expect(tracks.first.imageUrl, contains('track-thumb.jpg'));
    });

    test('getPlaylists returns parsed playlists', () async {
      final service = PlexService(dio: _fakeDio());
      service.configure(serverUrl: 'https://plex.example', token: 'tok123');
      final playlists = await service.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.id, '10');
      expect(playlists.first.name, 'My Mix');
      expect(playlists.first.trackCount, 12);
      expect(playlists.first.imageUrl, contains('playlist.jpg'));
    });

    test('getPlaylistTracks returns parsed tracks', () async {
      final service = PlexService(dio: _fakeDio());
      service.configure(serverUrl: 'https://plex.example', token: 'tok123');
      final tracks = await service.getPlaylistTracks('5');
      expect(tracks.length, 1);
      expect(tracks.first.name, 'Track A');
      expect(tracks.first.duration, 125); // 125000 ms
    });

    test('getBestStreamUrl prefers part key', () async {
      final service = PlexService(dio: _fakeDio());
      service.configure(serverUrl: 'https://plex.example', token: 'tok123');
      final url = await service.getBestStreamUrl('20');
      expect(url, contains('/library/parts/99/file.mp3'));
      expect(url, contains('X-Plex-Token=tok123'));
    });

    test('getDownloadUrl and helpers build correct URLs', () {
      final service = PlexService();
      service.configure(serverUrl: 'https://plex.example/', token: 'tok');

      expect(
        service.getDownloadUrl('20'),
        'https://plex.example/library/metadata/20/download?X-Plex-Token=tok',
      );
      expect(
        service.getDirectPartUrl('99'),
        'https://plex.example/library/parts/99/file.mp3?X-Plex-Token=tok',
      );
      expect(
        service.getUniversalStreamUrl('20'),
        contains('audio/:/transcode/universal/start.mp3'),
      );
      expect(
        service.getStreamUrl('20'),
        contains('/library/metadata/20/download'),
      );
    });
  });
}
