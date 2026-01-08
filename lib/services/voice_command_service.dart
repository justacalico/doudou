import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Types of voice commands supported by Google Assistant
enum VoiceCommandType {
  /// Play music (general or with query)
  play,

  /// Play specific artist
  playArtist,

  /// Play specific album
  playAlbum,

  /// Play specific playlist
  playPlaylist,

  /// Play favorites/liked songs
  playFavorites,

  /// Shuffle all music
  shuffleAll,

  /// Search and play
  searchAndPlay,

  /// Pause playback
  pause,

  /// Resume playback
  resume,

  /// Stop playback
  stop,

  /// Skip to next track
  next,

  /// Skip to previous track
  previous,

  /// Toggle shuffle
  shuffle,

  /// Toggle repeat
  repeat,

  /// Unknown command
  unknown,
}

/// Data class representing a voice command from Google Assistant
class VoiceCommand {
  final VoiceCommandType type;
  final String? query;
  final String? artist;
  final String? album;
  final String? playlist;
  final bool shuffle;
  final DateTime timestamp;
  final String? rawUri;

  VoiceCommand({
    required this.type,
    this.query,
    this.artist,
    this.album,
    this.playlist,
    this.shuffle = false,
    DateTime? timestamp,
    this.rawUri,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'VoiceCommand(type: $type, query: $query, artist: $artist, album: $album, playlist: $playlist, shuffle: $shuffle)';
  }

  /// Check if this command requires a search
  bool get requiresSearch =>
      query != null || artist != null || album != null || playlist != null;

  /// Get the primary search term
  String? get searchTerm => query ?? artist ?? album ?? playlist;
}

/// Service to handle Google Assistant voice commands via deep links
class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  static const MethodChannel _channel = MethodChannel(
    'app.channel/voice_commands',
  );

  // Stream controller for voice commands
  final StreamController<VoiceCommand> _commandController =
      StreamController<VoiceCommand>.broadcast();

  /// Stream of voice commands
  Stream<VoiceCommand> get commandStream => _commandController.stream;

  // Track pending command for when app starts from voice command
  VoiceCommand? _pendingCommand;

  /// Get pending command (for cold start handling)
  VoiceCommand? get pendingCommand => _pendingCommand;

  /// Clear pending command after processing
  void clearPendingCommand() {
    _pendingCommand = null;
  }

  bool _isInitialized = false;

  /// Initialize the voice command service
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      print('VoiceCommandService: Initializing...');
    }

    // Set up method channel handler for incoming voice commands
    _channel.setMethodCallHandler(_handleMethodCall);

    // Check for initial intent (cold start)
    try {
      final initialUri = await _channel.invokeMethod<String>('getInitialUri');
      if (initialUri != null && initialUri.isNotEmpty) {
        if (kDebugMode) {
          print(
            'VoiceCommandService: Initial URI from cold start: $initialUri',
          );
        }
        final command = parseUri(initialUri);
        if (command.type != VoiceCommandType.unknown) {
          _pendingCommand = command;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('VoiceCommandService: Error getting initial URI: $e');
      }
    }

    _isInitialized = true;

    if (kDebugMode) {
      print('VoiceCommandService: Initialized successfully');
    }
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (kDebugMode) {
      print('VoiceCommandService: Received method call: ${call.method}');
    }

    switch (call.method) {
      case 'onVoiceCommand':
        final uri = call.arguments as String?;
        if (uri != null) {
          _handleUri(uri);
        }
        return null;

      case 'onMediaPlayFromSearch':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          _handleMediaPlayFromSearch(args);
        }
        return null;

      default:
        if (kDebugMode) {
          print('VoiceCommandService: Unknown method: ${call.method}');
        }
        return null;
    }
  }

  /// Handle incoming URI from deep link
  void _handleUri(String uri) {
    if (kDebugMode) {
      print('VoiceCommandService: Handling URI: $uri');
    }

    final command = parseUri(uri);
    if (command.type != VoiceCommandType.unknown) {
      _commandController.add(command);
    }
  }

  /// Handle MEDIA_PLAY_FROM_SEARCH intent (from Android Auto / voice search)
  void _handleMediaPlayFromSearch(Map<dynamic, dynamic> args) {
    if (kDebugMode) {
      print('VoiceCommandService: Handling media play from search: $args');
    }

    final query = args['query'] as String?;
    final mediaFocus = args['mediaFocus'] as String?;
    final artist = args['artist'] as String?;
    final album = args['album'] as String?;
    final playlist = args['playlist'] as String?;
    final title = args['title'] as String?;
    // Note: genre is parsed but not currently used in commands
    // final genre = args['genre'] as String?;

    VoiceCommand command;

    if (mediaFocus != null) {
      switch (mediaFocus) {
        case 'vnd.android.cursor.item/artist':
          command = VoiceCommand(
            type: VoiceCommandType.playArtist,
            artist: artist ?? query,
            rawUri: 'media_play_from_search',
          );
          break;

        case 'vnd.android.cursor.item/album':
          command = VoiceCommand(
            type: VoiceCommandType.playAlbum,
            album: album ?? query,
            artist: artist,
            rawUri: 'media_play_from_search',
          );
          break;

        case 'vnd.android.cursor.item/playlist':
          command = VoiceCommand(
            type: VoiceCommandType.playPlaylist,
            playlist: playlist ?? query,
            rawUri: 'media_play_from_search',
          );
          break;

        case 'vnd.android.cursor.item/audio':
          command = VoiceCommand(
            type: VoiceCommandType.searchAndPlay,
            query: title ?? query,
            artist: artist,
            album: album,
            rawUri: 'media_play_from_search',
          );
          break;

        default:
          command = VoiceCommand(
            type: VoiceCommandType.searchAndPlay,
            query: query,
            artist: artist,
            album: album,
            playlist: playlist,
            rawUri: 'media_play_from_search',
          );
      }
    } else {
      // No specific focus, general search
      command = VoiceCommand(
        type: query?.isNotEmpty == true
            ? VoiceCommandType.searchAndPlay
            : VoiceCommandType.play,
        query: query,
        artist: artist,
        album: album,
        playlist: playlist,
        rawUri: 'media_play_from_search',
      );
    }

    if (kDebugMode) {
      print('VoiceCommandService: Created command from search: $command');
    }

    _commandController.add(command);
  }

  /// Parse a URI into a VoiceCommand
  VoiceCommand parseUri(String uriString) {
    if (kDebugMode) {
      print('VoiceCommandService: Parsing URI: $uriString');
    }

    try {
      final uri = Uri.parse(uriString);

      // Check if it's our doudou:// scheme
      if (uri.scheme != 'doudou') {
        if (kDebugMode) {
          print('VoiceCommandService: Unknown scheme: ${uri.scheme}');
        }
        return VoiceCommand(type: VoiceCommandType.unknown, rawUri: uriString);
      }

      // Get the path segments
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      if (pathSegments.isEmpty) {
        return VoiceCommand(type: VoiceCommandType.play, rawUri: uriString);
      }

      final action = pathSegments.length > 0 ? pathSegments[0] : '';
      final query = uri.queryParameters;

      if (kDebugMode) {
        print('VoiceCommandService: Action: $action, Query params: $query');
      }

      switch (action) {
        case 'play':
          // Check for specific parameters
          final artist = query['artist'];
          final album = query['album'];
          final playlist = query['playlist'];
          final searchQuery = query['query'];

          if (artist != null && artist.isNotEmpty) {
            return VoiceCommand(
              type: VoiceCommandType.playArtist,
              artist: artist,
              album: album,
              rawUri: uriString,
            );
          } else if (album != null && album.isNotEmpty) {
            return VoiceCommand(
              type: VoiceCommandType.playAlbum,
              album: album,
              artist: artist,
              rawUri: uriString,
            );
          } else if (playlist != null && playlist.isNotEmpty) {
            // Check if playlist is "favorites" or similar
            if (_isFavoritesPlaylist(playlist)) {
              return VoiceCommand(
                type: VoiceCommandType.playFavorites,
                shuffle: query['shuffle'] == 'true',
                rawUri: uriString,
              );
            }
            return VoiceCommand(
              type: VoiceCommandType.playPlaylist,
              playlist: playlist,
              rawUri: uriString,
            );
          } else if (searchQuery != null && searchQuery.isNotEmpty) {
            return VoiceCommand(
              type: VoiceCommandType.searchAndPlay,
              query: searchQuery,
              rawUri: uriString,
            );
          }

          // General play command
          return VoiceCommand(type: VoiceCommandType.play, rawUri: uriString);

        case 'favorites':
          return VoiceCommand(
            type: VoiceCommandType.playFavorites,
            shuffle: query['shuffle'] == 'true',
            rawUri: uriString,
          );

        case 'shuffle':
          return VoiceCommand(
            type: VoiceCommandType.shuffle,
            rawUri: uriString,
          );

        case 'shuffle-all':
          return VoiceCommand(
            type: VoiceCommandType.shuffleAll,
            rawUri: uriString,
          );

        case 'search':
          return VoiceCommand(
            type: VoiceCommandType.searchAndPlay,
            query: query['query'],
            rawUri: uriString,
          );

        case 'pause':
          return VoiceCommand(type: VoiceCommandType.pause, rawUri: uriString);

        case 'resume':
          return VoiceCommand(type: VoiceCommandType.resume, rawUri: uriString);

        case 'stop':
          return VoiceCommand(type: VoiceCommandType.stop, rawUri: uriString);

        case 'next':
          return VoiceCommand(type: VoiceCommandType.next, rawUri: uriString);

        case 'previous':
          return VoiceCommand(
            type: VoiceCommandType.previous,
            rawUri: uriString,
          );

        case 'repeat':
          return VoiceCommand(type: VoiceCommandType.repeat, rawUri: uriString);

        default:
          if (kDebugMode) {
            print('VoiceCommandService: Unknown action: $action');
          }
          return VoiceCommand(
            type: VoiceCommandType.unknown,
            rawUri: uriString,
          );
      }
    } catch (e) {
      if (kDebugMode) {
        print('VoiceCommandService: Error parsing URI: $e');
      }
      return VoiceCommand(type: VoiceCommandType.unknown, rawUri: uriString);
    }
  }

  /// Check if playlist name refers to favorites
  bool _isFavoritesPlaylist(String playlist) {
    final normalizedPlaylist = playlist.toLowerCase().trim();
    final favoriteKeywords = [
      'favorite',
      'favorites',
      'favourite',
      'favourites',
      'liked',
      'starred',
      'loved',
      'my favorites',
      'my favourites',
      'liked songs',
      'liked music',
      'my starred',
    ];

    return favoriteKeywords.any(
      (keyword) => normalizedPlaylist.contains(keyword),
    );
  }

  /// Manually process a URI (for testing or external triggers)
  void processUri(String uri) {
    _handleUri(uri);
  }

  /// Dispose the service
  void dispose() {
    _commandController.close();
    _isInitialized = false;
  }
}
