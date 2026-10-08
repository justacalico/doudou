import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/mcp/mcp_protocol.dart';
import 'package:doudou/mcp/mcp_tools.dart';
import 'package:doudou/services/mcp/mcp_app_bridge.dart';
import 'package:doudou/services/mcp/mcp_toolset.dart';
import 'package:doudou/services/mcp_server_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class FakeMcpAppBridge implements McpAppBridge {
  final calls = <String>[];
  final songCalls = <Map<String, Object?>>[];
  int seekPosition = -1;
  int volume = -1;
  bool? shuffle;
  String? repeat;
  bool? favoriteResult;
  int enqueuedIndex = 3;

  Map<String, Object?> state = {
    'playing': true,
    'processing_state': 'ready',
    'position_ms': 1234,
    'volume': 80,
    'shuffle': false,
    'repeat_mode': 'off',
    'queue_index': 0,
    'queue_length': 2,
    'song': {'id': 'abc', 'title': 'Song', 'artist': 'Artist'},
  };

  Map<String, Object?> queue = {
    'queue_index': 0,
    'length': 2,
    'items': [
      {'index': 0, 'id': 'abc', 'title': 'Song', 'current': true},
      {'index': 1, 'id': 'def', 'title': 'Next', 'current': false},
    ],
  };

  Map<String, Object?> searchResult = {
    'songs': [
      {'videoId': 'abc', 'title': 'Song'}
    ],
  };

  void _rec(String name) => calls.add(name);

  @override
  Map<String, Object?> playbackState() {
    _rec('playbackState');
    return state;
  }

  @override
  Map<String, Object?> queueState() {
    _rec('queueState');
    return queue;
  }

  @override
  Future<void> play() async => _rec('play');
  @override
  Future<void> pause() async => _rec('pause');
  @override
  Future<void> next() async => _rec('next');
  @override
  Future<void> previous() async => _rec('previous');

  @override
  Future<void> seek(int positionMs) async {
    _rec('seek');
    seekPosition = positionMs;
  }

  @override
  Future<void> setVolume(int v) async {
    _rec('setVolume');
    volume = v;
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _rec('setShuffle');
    shuffle = enabled;
  }

  @override
  Future<void> setRepeat(String mode) async {
    _rec('setRepeat');
    repeat = mode;
  }

  @override
  Future<void> playQueueIndex(int index) async =>
      _rec('playQueueIndex:$index');

  @override
  Future<void> removeQueueIndex(int index) async =>
      _rec('removeQueueIndex:$index');

  @override
  Future<void> clearQueue() async => _rec('clearQueue');

  @override
  Future<void> playSong(Map<String, Object?> song,
      {bool radio = false}) async {
    _rec('playSong${radio ? ':radio' : ''}');
    songCalls.add(song);
  }

  @override
  Future<int> enqueueSong(Map<String, Object?> song) async {
    _rec('enqueueSong');
    songCalls.add(song);
    return enqueuedIndex;
  }

  @override
  Future<int> playNextSong(Map<String, Object?> song) async {
    _rec('playNextSong');
    songCalls.add(song);
    return 1;
  }

  @override
  Future<bool?> toggleFavorite() async {
    _rec('toggleFavorite');
    return favoriteResult;
  }

  @override
  Future<Map<String, Object?>> search(String query,
      {String? filter, int limit = 10}) async {
    _rec('search:$query:$filter:$limit');
    return searchResult;
  }

  @override
  Future<List<Map<String, Object?>>> listPlaylists() async {
    _rec('listPlaylists');
    return [
      {'playlistId': 'PL1', 'title': 'Mix'},
    ];
  }

  @override
  Future<Map<String, Object?>> getPlaylistOrAlbumSongs(
      {String? playlistId, String? albumId, int limit = 100}) async {
    _rec('getPlaylistOrAlbumSongs:$playlistId:$albumId:$limit');
    return {
      'tracks': [
        {'videoId': 'abc'}
      ]
    };
  }
}

void main() {
  // No TestWidgetsFlutterBinding here: the service end-to-end test needs
  // real loopback sockets, which the widget binding's HttpClient mock would
  // swallow.
  late Box box;
  late FakeMcpAppBridge bridge;
  McpServerService? svc;

  setUp(() async {
    Hive.init(
        '/tmp/doudou_mcp_test_${DateTime.now().microsecondsSinceEpoch}');
    box = await Hive.openBox('AppPrefs_mcp_test');
    bridge = FakeMcpAppBridge();
  });

  tearDown(() async {
    await svc?.stop();
    svc = null;
    await box.clear();
    await box.deleteFromDisk();
    await Hive.close();
    Get.reset();
  });

  McpServerService makeService() =>
      svc = McpServerService(prefs: box, bridge: bridge, supported: true);

  McpTool toolByName(List<McpTool> tools, String name) =>
      tools.firstWhere((t) => t.name == name);

  group('service lifecycle', () {
    test('does nothing when unsupported', () async {
      svc = McpServerService(prefs: box, bridge: bridge, supported: false);
      await box.put(McpServerService.enabledPrefsKey, true);
      svc!.onInit();
      await Future.delayed(const Duration(milliseconds: 30));
      expect(svc!.running.value, isFalse);
      expect(svc!.enabled.value, isFalse);
    });

    test('setEnabled starts and stops the listener', () async {
      makeService();
      svc!.onInit();
      svc!.port.value = 0;

      await svc!.setEnabled(true);
      expect(svc!.running.value, isTrue);
      expect(box.get(McpServerService.enabledPrefsKey), isTrue);
      expect(svc!.listenUrl, startsWith('http://127.0.0.1:'));
      expect(svc!.listenUrl, endsWith('/mcp'));

      await svc!.setEnabled(false);
      expect(svc!.running.value, isFalse);
      expect(box.get(McpServerService.enabledPrefsKey), isFalse);
    });

    test('auto starts when the enabled pref is set', () async {
      await box.put(McpServerService.enabledPrefsKey, true);
      makeService();
      svc!.port.value = 0;
      svc!.onInit();
      // onInit kicks an unawaited start; give it a beat.
      await Future.delayed(const Duration(milliseconds: 200));
      expect(svc!.running.value, isTrue);
    });

    test('end to end tools/call reaches the bridge', () async {
      makeService();
      svc!.onInit();
      svc!.port.value = 0;
      await svc!.setEnabled(true);

      final client = HttpClient();
      try {
        final uri = Uri.parse(svc!.listenUrl);
        final req =
            await client.post(uri.host, uri.port, uri.path);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'jsonrpc': '2.0',
          'id': 5,
          'method': 'tools/call',
          'params': {'name': 'get_playback_state'},
        }));
        final res = await req.close();
        expect(res.statusCode, HttpStatus.ok);
        final body =
            jsonDecode(await res.transform(utf8.decoder).join()) as Map;
        final structured = body['result']['structuredContent'] as Map;
        expect(structured['playing'], isTrue);
        expect(structured['song']['id'], 'abc');
        expect(bridge.calls, contains('playbackState'));
      } finally {
        client.close(force: true);
      }
    });

    test('setPort validates, persists and restarts a running server',
        () async {
      makeService();
      svc!.onInit();
      svc!.port.value = 0;
      await svc!.setEnabled(true);

      expect(await svc!.setPort(80), isFalse);
      expect(await svc!.setPort(70000), isFalse);
      expect(await svc!.setPort(0), isFalse);

      final probe = await ServerSocket.bind(
          InternetAddress.loopbackIPv4, 0);
      final freePort = probe.port;
      await probe.close();

      expect(await svc!.setPort(freePort), isTrue);
      expect(box.get(McpServerService.portPrefsKey), freePort);
      expect(svc!.running.value, isTrue);
      expect(svc!.listenUrl, 'http://127.0.0.1:$freePort/mcp');
    });
  });

  group('toolset', () {
    test('exposes the full tool surface', () {
      final tools = buildDoudouMcpTools(bridge);
      final names = tools.map((t) => t.name).toSet();
      expect(
          names,
          containsAll({
            'get_playback_state',
            'get_queue',
            'play',
            'pause',
            'toggle_play',
            'next',
            'previous',
            'seek',
            'set_volume',
            'set_shuffle',
            'set_repeat',
            'play_queue_item',
            'remove_queue_item',
            'clear_queue',
            'toggle_favorite',
            'search',
            'play_song',
            'enqueue_song',
            'play_next_song',
            'list_playlists',
            'get_playlist_songs',
          }));
      for (final tool in tools) {
        expect(tool.inputSchema['type'], 'object');
      }
    });

    test('playback tools delegate to the bridge', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'play').handler({});
      await toolByName(tools, 'pause').handler({});
      await toolByName(tools, 'next').handler({});
      await toolByName(tools, 'previous').handler({});
      expect(bridge.calls,
          containsAll(['play', 'pause', 'next', 'previous']));
    });

    test('toggle_play pauses while playing', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'toggle_play').handler({});
      expect(bridge.calls, contains('pause'));
      expect(bridge.calls, isNot(contains('play')));
    });

    test('seek passes milliseconds through', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'seek').handler({'position_ms': 5000});
      expect(bridge.seekPosition, 5000);
    });

    test('seek rejects missing positions', () async {
      final tools = buildDoudouMcpTools(bridge);
      expect(() => toolByName(tools, 'seek').handler({}),
          throwsA(isA<McpRpcError>()));
    });

    test('set_volume enforces the 0-100 range', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'set_volume').handler({'volume': 42});
      expect(bridge.volume, 42);
      expect(
          () => toolByName(tools, 'set_volume')
              .handler({'volume': 200}),
          throwsA(isA<McpRpcError>()));
    });

    test('set_shuffle and set_repeat reach the bridge', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'set_shuffle')
          .handler({'enabled': true});
      expect(bridge.shuffle, isTrue);
      await toolByName(tools, 'set_repeat').handler({'mode': 'all'});
      expect(bridge.repeat, 'all');
      expect(
          () => toolByName(tools, 'set_repeat')
              .handler({'mode': 'sometimes'}),
          throwsA(isA<McpRpcError>()));
    });

    test('play_queue_item rejects out of range indexes', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'play_queue_item').handler({'index': 1});
      expect(bridge.calls, contains('playQueueIndex:1'));
      expect(
          () => toolByName(tools, 'play_queue_item')
              .handler({'index': 7}),
          throwsA(isA<McpRpcError>()));
    });

    test('remove_queue_item returns the fresh queue', () async {
      final tools = buildDoudouMcpTools(bridge);
      final res = await toolByName(tools, 'remove_queue_item')
          .handler({'index': 0}) as Map;
      expect(bridge.calls, contains('removeQueueIndex:0'));
      expect(res['queue'], bridge.queue);
    });

    test('play_song forwards scalar metadata as a song map', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'play_song').handler({
        'video_id': 'vid1',
        'title': 'Title',
        'artist': 'Artist',
        'album': 'Album',
        'duration_seconds': 200,
        'thumbnail_url': 'https://x/t.jpg',
      });
      final song = bridge.songCalls.single;
      expect(song['videoId'], 'vid1');
      expect(song['title'], 'Title');
      expect(song['artists'], [
        {'name': 'Artist'}
      ]);
      expect(song['album'], {'name': 'Album'});
      expect(song['duration'], 200);
      expect(song['thumbnails'], [
        {'url': 'https://x/t.jpg'}
      ]);
      expect(bridge.calls, contains('playSong'));
    });

    test('play_song prefers a whole song object', () async {
      final tools = buildDoudouMcpTools(bridge);
      final raw = {'videoId': 'raw', 'extra': {'nested': true}};
      await toolByName(tools, 'play_song').handler({'song': raw});
      expect(bridge.songCalls.single, raw);
    });

    test('play_song requires song or video_id', () async {
      final tools = buildDoudouMcpTools(bridge);
      expect(() => toolByName(tools, 'play_song').handler({'title': 'x'}),
          throwsA(isA<McpRpcError>()));
    });

    test('play_song radio flag reaches the bridge', () async {
      final tools = buildDoudouMcpTools(bridge);
      await toolByName(tools, 'play_song')
          .handler({'video_id': 'v', 'radio': true});
      expect(bridge.calls, contains('playSong:radio'));
    });

    test('enqueue_song and play_next_song report the queue index',
        () async {
      final tools = buildDoudouMcpTools(bridge);
      final enq = await toolByName(tools, 'enqueue_song')
          .handler({'video_id': 'v'}) as Map;
      expect(enq['queue_index'], 3);
      final next = await toolByName(tools, 'play_next_song')
          .handler({'video_id': 'v'}) as Map;
      expect(next['queue_index'], 1);
    });

    test('search passes query, filter and limit', () async {
      final tools = buildDoudouMcpTools(bridge);
      final res = await toolByName(tools, 'search').handler(
          {'query': 'hello', 'filter': 'songs', 'limit': 5}) as Map;
      expect(res, bridge.searchResult);
      expect(bridge.calls, contains('search:hello:songs:5'));
    });

    test('get_playlist_songs needs exactly one id', () async {
      final tools = buildDoudouMcpTools(bridge);
      expect(() => toolByName(tools, 'get_playlist_songs').handler({}),
          throwsA(isA<McpRpcError>()));
      expect(
          () => toolByName(tools, 'get_playlist_songs')
              .handler({'playlist_id': 'a', 'album_id': 'b'}),
          throwsA(isA<McpRpcError>()));
      final res = await toolByName(tools, 'get_playlist_songs')
          .handler({'playlist_id': 'a'}) as Map;
      expect(res['tracks'], isNotEmpty);
      expect(bridge.calls,
          contains('getPlaylistOrAlbumSongs:a:null:100'));
    });

    test('toggle_favorite reports the new state', () async {
      bridge.favoriteResult = true;
      final tools = buildDoudouMcpTools(bridge);
      final res =
          await toolByName(tools, 'toggle_favorite').handler({}) as Map;
      expect(res['favorite'], isTrue);
    });

    test('resources mirror the bridge state', () async {
      final resources = buildDoudouMcpResources(bridge);
      expect(resources.map((r) => r.uri),
          containsAll(['doudou://playback/state', 'doudou://queue']));
      final state =
          await resources.firstWhere((r) => r.uri == 'doudou://queue').reader();
      expect(state, bridge.queue);
    });
  });

  group('sanitizeMcpJson', () {
    test('converts MediaItems through MediaItemBuilder', () {
      const item = MediaItem(
          id: 'x', title: 'T', extras: {'url': 'http://a/b.mp3?token=1'});
      final out = sanitizeMcpJson(item) as Map;
      expect(out['videoId'], 'x');
      expect(out['title'], 'T');
    });

    test('keeps json primitives and recurses maps and lists', () {
      final out = sanitizeMcpJson({
        'a': 1,
        'b': [true, 'x', null],
        'c': {'nested': 2.5},
      }) as Map;
      expect(out['a'], 1);
      expect(out['b'], [true, 'x', null]);
      expect(out['c'], {'nested': 2.5});
    });

    test('degrades unknown objects to strings', () {
      final out = sanitizeMcpJson({'when': DateTime.utc(2020)}) as Map;
      expect(out['when'], isA<String>());
      expect(() => jsonEncode(out), returnsNormally);
    });
  });
}
