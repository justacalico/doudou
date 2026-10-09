import '../../mcp/mcp_protocol.dart';
import '../../mcp/mcp_tools.dart';
import 'mcp_app_bridge.dart';

/// Builds the tool and resource surface the MCP server exposes. All app
/// access goes through [McpAppBridge], so this file stays free of service
/// locators and is fully testable with a fake bridge.

const _noArgs = <String, Object?>{'type': 'object', 'properties': {}};

/// Song reference shared by play_song, enqueue_song and play_next_song. A
/// caller either passes a whole `song` object copied from a search/playlist
/// result, or scalar fields with at least `video_id`.
Map<String, Object?> _songArgsSchema({bool withRadio = false}) => {
      'type': 'object',
      'properties': {
        'song': {
          'type': 'object',
          'description': 'Song object copied from a search or playlist '
              'result. Preferred over the scalar fields below.',
        },
        'video_id': {'type': 'string', 'description': 'Song/video id'},
        'title': {'type': 'string'},
        'artist': {'type': 'string'},
        'album': {'type': 'string'},
        'duration_seconds': {'type': 'integer'},
        'thumbnail_url': {'type': 'string'},
        if (withRadio)
          'radio': {
            'type': 'boolean',
            'description': 'Start a radio seeded by this song instead of '
                'playing just the song (YouTube Music only).',
          },
      },
    };

Map<String, Object?> _songJsonFromArgs(Map<String, Object?> args) {
  final song = McpArgs.object(args, 'song');
  if (song != null) return song;
  final videoId = McpArgs.string(args, 'video_id');
  final artist = McpArgs.optString(args, 'artist');
  final album = McpArgs.optString(args, 'album');
  final duration = McpArgs.optInteger(args, 'duration_seconds', min: 0);
  final thumbnail = McpArgs.optString(args, 'thumbnail_url');
  return {
    'videoId': videoId,
    'title': McpArgs.optString(args, 'title') ?? videoId,
    if (artist != null)
      'artists': [
        {'name': artist}
      ],
    if (album != null)
      'album': {'name': album},
    if (duration != null) 'duration': duration,
    if (thumbnail != null)
      'thumbnails': [
        {'url': thumbnail}
      ],
  };
}

int _queueIndexArg(Map<String, Object?> args, McpAppBridge bridge) {
  final index = McpArgs.integer(args, 'index', min: 0);
  final length = bridge.queueState()['length'] as int? ?? 0;
  if (index >= length) {
    throw McpRpcError.invalidParams(
        '"index" $index is out of range, queue has $length items');
  }
  return index;
}

Map<String, Object?> _ok(McpAppBridge bridge) =>
    {'ok': true, 'playback': bridge.playbackState()};

List<McpTool> buildDoudouMcpTools(McpAppBridge bridge) => [
      McpTool(
        name: 'get_playback_state',
        description: 'Current playback status: playing flag, position, '
            'volume, shuffle, repeat mode and the playing song.',
        inputSchema: _noArgs,
        handler: (_) async => bridge.playbackState(),
      ),
      McpTool(
        name: 'get_queue',
        description: 'List the playback queue with each item\'s index, title, '
            'artist and whether it is the current item.',
        inputSchema: _noArgs,
        handler: (_) async => bridge.queueState(),
      ),
      McpTool(
        name: 'play',
        description: 'Resume playback.',
        inputSchema: _noArgs,
        handler: (_) async {
          await bridge.play();
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'pause',
        description: 'Pause playback.',
        inputSchema: _noArgs,
        handler: (_) async {
          await bridge.pause();
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'toggle_play',
        description: 'Toggle between play and pause.',
        inputSchema: _noArgs,
        handler: (_) async {
          final playing = bridge.playbackState()['playing'] == true;
          playing ? await bridge.pause() : await bridge.play();
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'next',
        description: 'Skip to the next song in the queue.',
        inputSchema: _noArgs,
        handler: (_) async {
          await bridge.next();
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'previous',
        description: 'Skip to the previous song in the queue.',
        inputSchema: _noArgs,
        handler: (_) async {
          await bridge.previous();
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'seek',
        description: 'Seek the current song to a position.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'position_ms': {
              'type': 'integer',
              'minimum': 0,
              'description': 'Position in milliseconds',
            },
          },
          'required': ['position_ms'],
        },
        handler: (args) async {
          await bridge.seek(McpArgs.integer(args, 'position_ms', min: 0));
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'set_volume',
        description: 'Set playback volume.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'volume': {
              'type': 'integer',
              'minimum': 0,
              'maximum': 100,
              'description': 'Volume percent, 0 to 100',
            },
          },
          'required': ['volume'],
        },
        handler: (args) async {
          await bridge
              .setVolume(McpArgs.integer(args, 'volume', min: 0, max: 100));
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'set_shuffle',
        description: 'Turn shuffle mode on or off.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'enabled': {'type': 'boolean'},
          },
          'required': ['enabled'],
        },
        handler: (args) async {
          await bridge.setShuffle(McpArgs.boolean(args, 'enabled'));
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'set_repeat',
        description: 'Set the repeat mode: "off" plays the queue once, "one" '
            'repeats the current song, "all" loops the whole queue.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'mode': {
              'type': 'string',
              'enum': ['off', 'one', 'all'],
            },
          },
          'required': ['mode'],
        },
        handler: (args) async {
          await bridge
              .setRepeat(McpArgs.enumValue(args, 'mode', ['off', 'one', 'all']));
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'play_queue_item',
        description: 'Play the queue item at the given index.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'index': {
              'type': 'integer',
              'minimum': 0,
              'description': 'Queue index from get_queue',
            },
          },
          'required': ['index'],
        },
        handler: (args) async {
          await bridge.playQueueIndex(_queueIndexArg(args, bridge));
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'remove_queue_item',
        description: 'Remove the queue item at the given index.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'index': {'type': 'integer', 'minimum': 0},
          },
          'required': ['index'],
        },
        handler: (args) async {
          await bridge.removeQueueIndex(_queueIndexArg(args, bridge));
          return {'ok': true, 'queue': bridge.queueState()};
        },
      ),
      McpTool(
        name: 'clear_queue',
        description: 'Remove every queue item except the current song.',
        inputSchema: _noArgs,
        handler: (_) async {
          await bridge.clearQueue();
          return {'ok': true, 'queue': bridge.queueState()};
        },
      ),
      McpTool(
        name: 'toggle_favorite',
        description: 'Toggle the favourite/like flag on the current song.',
        inputSchema: _noArgs,
        handler: (_) async => {'favorite': await bridge.toggleFavorite()},
      ),
      McpTool(
        name: 'search',
        description: 'Search the active music server. Returns matching songs, '
            'albums, artists and playlists that can be passed to play_song, '
            'enqueue_song or get_playlist_songs.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'Search text'},
            'filter': {
              'type': 'string',
              'enum': [
                'songs',
                'videos',
                'albums',
                'artists',
                'playlists',
                'community_playlists',
                'featured_playlists',
              ],
              'description': 'Optional result filter',
            },
            'limit': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 25,
              'description': 'Max results per category (default 10)',
            },
          },
          'required': ['query'],
        },
        handler: (args) async => bridge.search(
          McpArgs.string(args, 'query'),
          filter: McpArgs.optString(args, 'filter'),
          limit: McpArgs.optInteger(args, 'limit', min: 1, max: 25) ?? 10,
        ),
      ),
      McpTool(
        name: 'play_song',
        description: 'Play a song immediately, replacing the queue like '
            'tapping it in the app. Pass a song object from search results or '
            'at least video_id plus metadata.',
        inputSchema: _songArgsSchema(withRadio: true),
        handler: (args) async {
          await bridge.playSong(_songJsonFromArgs(args),
              radio: McpArgs.optBoolean(args, 'radio'));
          return _ok(bridge);
        },
      ),
      McpTool(
        name: 'enqueue_song',
        description: 'Append a song to the end of the queue.',
        inputSchema: _songArgsSchema(),
        handler: (args) async {
          final index =
              await bridge.enqueueSong(_songJsonFromArgs(args));
          return {'ok': true, 'queue_index': index};
        },
      ),
      McpTool(
        name: 'play_next_song',
        description: 'Insert a song right after the current one so it plays '
            'next.',
        inputSchema: _songArgsSchema(),
        handler: (args) async {
          final index =
              await bridge.playNextSong(_songJsonFromArgs(args));
          return {'ok': true, 'queue_index': index};
        },
      ),
      McpTool(
        name: 'list_playlists',
        description: 'List the library playlists: the built-in local ones '
            '(Recently Played, Favourites, Cached/Offline, Downloads) plus '
            'the playlists on the active music server.',
        inputSchema: _noArgs,
        handler: (_) async => {'playlists': await bridge.listPlaylists()},
      ),
      McpTool(
        name: 'get_playlist_songs',
        description: 'Get the songs of a playlist or album by id, e.g. a '
            'playlistId from list_playlists or search results. Built-in '
            'playlist ids LIBRP, LIBFAV, SongsCache and SongDownloads read '
            'the local boxes.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'playlist_id': {'type': 'string'},
            'album_id': {'type': 'string'},
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 500},
          },
        },
        handler: (args) async {
          final playlistId = McpArgs.optString(args, 'playlist_id');
          final albumId = McpArgs.optString(args, 'album_id');
          if ((playlistId == null) == (albumId == null)) {
            throw McpRpcError.invalidParams(
                'Pass exactly one of "playlist_id" or "album_id"');
          }
          return bridge.getPlaylistOrAlbumSongs(
            playlistId: playlistId,
            albumId: albumId,
            limit: McpArgs.optInteger(args, 'limit', min: 1, max: 500) ?? 100,
          );
        },
      ),
    ];

List<McpResource> buildDoudouMcpResources(McpAppBridge bridge) => [
      McpResource(
        uri: 'doudou://playback/state',
        name: 'Playback state',
        description: 'Current playback status and song.',
        reader: () async => bridge.playbackState(),
      ),
      McpResource(
        uri: 'doudou://queue',
        name: 'Playback queue',
        description: 'The current playback queue.',
        reader: () async => bridge.queueState(),
      ),
    ];
