/// `package:media_kit` bindings for `just_audio` to support Linux and Windows.
library;

import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/src/mediakit_player.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:universal_platform/universal_platform.dart';

export 'package:media_kit/media_kit.dart' show MPVLogLevel;

class JustAudioMediaKit extends JustAudioPlatform {
  JustAudioMediaKit._();

  static JustAudioMediaKit? _instance;

  /// The internal MPV player's logLevel
  static MPVLogLevel mpvLogLevel = MPVLogLevel.error;

  /// Called for every line mpv emits. Wired up by the host app to feed mpv's
  /// internal logs into playback diagnostics.
  static void Function(String level, String prefix, String text)? onLog;

  /// Sets the demuxer's cache size (in bytes)
  static int bufferSize = 32 * 1024 * 1024;

  /// How many seconds of audio mpv should buffer before starting playback.
  /// Lower values make songs start faster at the cost of more rebuffering on
  /// slow connections. Set to 0 to let mpv use its default.
  static double cacheSeconds = 1;

  /// Whether mpv writes the demuxer cache to disk. Disk caching adds I/O
  /// overhead on every stream open, which slows down song starts. Disabled by
  /// default for audio playback where in-memory caching is enough.
  static bool cacheOnDisk = false;

  /// How far ahead the demuxer reads beyond the playback position, in seconds.
  /// Lower values reduce the initial data mpv pulls before playback starts.
  static double demuxerReadaheadSeconds = 0.5;

  /// Whether mpv pauses to wait for the demuxer cache to fill. When disabled,
  /// playback resumes as soon as the demuxer is ready instead of blocking on a
  /// cache target. Combined with the small readahead above this makes songs
  /// start noticeably sooner on slow first connections.
  static bool cachePause = false;

  /// Seconds to wait when pausing for cache before resuming anyway. Only used
  /// when [cachePause] is true.
  static double cachePauseWaitSeconds = 0.5;

  /// Seconds FFmpeg spends analyzing a stream to detect its format. mpv's
  /// default is 5, which is a large part of the "buffering" delay before the
  /// first note plays. Audio streams from YouTube are standard containers and
  /// don't need much probing.
  static double demuxerLavfAnalyzeSeconds = 0.5;

  /// Whether FFmpeg probes the stream for extra info (duration, bitrate,
  /// metadata) beyond what the container header already provides. Disabling
  /// skips that probe entirely. Set to true if durations come back wrong.
  static bool demuxerLavfProbeInfo = false;

  /// The maximum number of bytes FFmpeg reads to detect the container format.
  /// mpv's default is 5 MB. For standard audio streams the header is at the
  /// start, so 64 KB is enough and avoids reading large parts of a file just
  /// for probing.
  static int demuxerLavfProbeSize = 64 * 1024;

  /// Sets the name of the underlying window & process for native backend. This is visible inside the Windows' volume mixer.
  static String title = 'JustAudioMediaKit';

  /// Sets the list of allowed protocols for native backend.
  static List<String> protocolWhitelist = const [
    'udp',
    'rtp',
    'tcp',
    'tls',
    'data',
    'file',
    'http',
    'https',
    'crypto',
  ];

  /// Enables or disables pitch shift control for native backend (with this set to false, [setPitch] won't work).
  ///
  /// This uses `scaletempo` under the hood & disables `audio-pitch-correction`.
  static bool pitch = true;

  /// Enables gapless playback via the [`--prefetch-playlist`](https://mpv.io/manual/stable/#options-prefetch-playlist) in libmpv
  ///
  /// This is highly experimental. Use at your own risk.
  ///
  /// Check [mpv's docs](https://mpv.io/manual/stable/#options-prefetch-playlist) and
  /// [the related issue](https://github.com/Pato05/just_audio_media_kit/issues/11) for more information
  static bool prefetchPlaylist = false;

  /// Path to PEM client certificate file for mTLS.
  static String? tlsCertFile;

  /// Path to PEM private key file for mTLS.
  static String? tlsKeyFile;

  static final _logger = Logger('JustAudioMediaKit');
  final _players = HashMap<String, MediaKitPlayer>();

  /// Players that are disposing (player id -> future that completes when the player is disposed)
  final _disposingPlayers = HashMap<String, Future<void>>();

  /// Initializes the plugin if the platform we're running on is marked
  /// as true, otherwise it will leave everything unchanged.
  ///
  /// Can also be safely called from Web, even though it'll have no effect
  static void ensureInitialized({
    bool linux = true,
    bool windows = true,
    bool android = false,
    bool iOS = false,
    bool macOS = false,

    /// The path to the libmpv dynamic library.
    /// The name of the library is generally `libmpv.so` on GNU/Linux and `libmpv-2.dll` on Windows.
    String? libmpv,
  }) {
    if ((UniversalPlatform.isLinux && linux) ||
        (UniversalPlatform.isWindows && windows) ||
        (UniversalPlatform.isAndroid && android) ||
        (UniversalPlatform.isIOS && iOS) ||
        (UniversalPlatform.isMacOS && macOS)) {
      registerWith();
      MediaKit.ensureInitialized(libmpv: libmpv);
    }
  }

  /// Registers the plugin with [JustAudioPlatform]
  static void registerWith() {
    _instance ??= JustAudioMediaKit._();
    JustAudioPlatform.instance = _instance!;
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (_players.containsKey(request.id)) {
      throw PlatformException(
          code: 'error', message: 'Player ${request.id} already exists!');
    }

    _logger.fine('instantiating new player ${request.id}');
    final player = MediaKitPlayer(request.id);
    _players[request.id] = player;
    await player.ready();
    _logger.fine('player ready! (players: $_players)');
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    _logger.fine('disposing player ${request.id}');

    // temporary workaround because disposePlayer is called more than once
    if (_disposingPlayers.containsKey(request.id)) {
      _logger.fine('disposePlayer() called more than once!');
      await _disposingPlayers[request.id]!;
      return DisposePlayerResponse();
    }

    if (!_players.containsKey(request.id)) {
      throw PlatformException(
          code: 'error', message: 'Player ${request.id} doesn\'t exist.');
    }

    final future = _players[request.id]!.release();
    _players.remove(request.id);
    _disposingPlayers[request.id] = future;
    await future;
    _disposingPlayers.remove(request.id);

    _logger.fine('player ${request.id} disposed!');
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    _logger.fine('disposing of all players...');
    if (_players.isNotEmpty) {
      await Future.wait(_players.values.map((e) => e.release()));
      _players.clear();
    }
    return DisposeAllPlayersResponse();
  }
}
