import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '/utils/app_l10n.dart';
import '/ui/screens/Library/library_controller.dart';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';

import '/models/album.dart';
import '/models/server.dart';
import '../models/playlist.dart';
import '/services/equalizer.dart';
import '/services/stream_service.dart';
import '/models/hm_streaming_data.dart';
import '/ui/player/player_controller.dart';
import '../ui/screens/Home/home_screen_controller.dart';
import '/services/background_task.dart';
import '/services/permission_service.dart';
import '/services/playback_wakelock_service.dart';
import '/services/backend/backend_factory.dart';
import '/services/playback_diagnostics_service.dart';
import '/services/playback_recovery.dart';
import '/services/playback_transition_utils.dart';
import '../utils/helper.dart';
import '../utils/server_storage.dart';
import '/models/media_Item_builder.dart';
import '/services/utils.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';

part 'audio_handler_media_library.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationIcon: 'mipmap/ic_launcher_monochrome',
      androidNotificationChannelId: 'com.mycompany.myapp.audio',
      androidNotificationChannelName: 'Doudou Notification',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with GetxServiceMixin {
  // ignore: prefer_typing_uninitialized_variables
  late final _cacheDir;
  AudioPlayer _player;
  final AudioPlayer Function() _playerFactory;
  final StreamReachabilityCheck _reachabilityCheck;
  final Future<void> Function(Duration) _recoveryDelay;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  final MediaLibrary _mediaLibrary;
  final PlaybackDiagnosticsService _diag;
  final bool _testable;
  MediaLibrary get mediaLibrary => _mediaLibrary;
  // ignore: prefer_typing_uninitialized_variables
  dynamic currentIndex;
  int currentShuffleIndex = 0;
  late String? currentSongUrl;
  bool isPlayingUsingLockCachingSource = false;
  bool loopModeEnabled = false;
  bool queueLoopModeEnabled = false;
  bool shuffleModeEnabled = false;
  bool loudnessNormalizationEnabled = false;
  double _userVolume = 1.0;
  // var networkErrorPause = false;
  bool isSongLoading = true;
  ProcessingState? _lastLoggedProcessingState;
  final AutoAdvanceGuard _autoAdvanceGuard = AutoAdvanceGuard();
  int _playRequestSeq = 0;
  int _activePlayRequestId = 0;
  int _suppressAutoAdvanceUntilMs = 0;
  // Recovery state for platform player errors. Native connection failures
  // (e.g. iOS -1004) can leave the underlying AVPlayer/ExoPlayer session
  // permanently broken, so retries are capped, spaced out and escalate to
  // rebuilding the player instance instead of only refreshing the URL.
  int _consecutivePlayerFailures = 0;
  String _lastPlayerFailureSongId = '';
  int _lastPlayerFailureAtMs = 0;
  bool _playerRecoveryRunning = false;
  _PendingPlayerRecovery? _pendingPlayerRecovery;
  // Real track duration per song id, resolved at play time. Used as a
  // baseline on iOS/macOS where AVPlayer can report ~2x the real duration and
  // the queue item's own duration may be missing or polluted by that bug.
  final Map<String, int> _knownBaselineMs = {};

  int? get _safeCurrentIndex =>
      currentIndex is int ? currentIndex as int : null;

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  int _startPlayRequest({int suppressAutoAdvanceMs = 1800}) {
    final requestId = ++_playRequestSeq;
    _activePlayRequestId = requestId;
    _suppressAutoAdvanceUntilMs = _nowMs() + suppressAutoAdvanceMs;
    return requestId;
  }

  bool _isStalePlayRequest(int requestId) => requestId != _activePlayRequestId;

  // list of shuffled queue songs ids
  List<String> shuffledQueue = [];
  // keeps insertion/original order while shuffle is enabled
  List<MediaItem> originalQueue = [];

  ConcatenatingAudioSource _playList =
      ConcatenatingAudioSource(children: [], useLazyPreparation: false);
  late Future<void> _audioSourceReady;

  static AudioPlayer _createDefaultPlayer() {
    if (GetPlatform.isWindows || GetPlatform.isLinux) {
      JustAudioMediaKit.title = 'Doudou';
      JustAudioMediaKit.protocolWhitelist = const ['http', 'https', 'file'];
      JustAudioMediaKit.ensureInitialized();
    }
    return AudioPlayer(
      handleAudioSessionActivation:
          !GetPlatform.isLinux && !GetPlatform.isWindows,
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 50),
          maxBufferDuration: Duration(seconds: 120),
          bufferForPlaybackDuration: Duration(milliseconds: 50),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        ),
      ),
    );
  }

  MyAudioHandler({
    AudioPlayer? player,
    AudioPlayer Function()? playerFactory,
    MediaLibrary? mediaLibrary,
    PlaybackDiagnosticsService? diagnostics,
    StreamReachabilityCheck? reachabilityCheck,
    Future<void> Function(Duration)? recoveryDelay,
  })  : _testable = player != null || playerFactory != null,
        _playerFactory = playerFactory ?? _createDefaultPlayer,
        _reachabilityCheck = reachabilityCheck ?? canReachStreamHost,
        _recoveryDelay = recoveryDelay ?? Future.delayed,
        _player = player ?? (playerFactory ?? _createDefaultPlayer)(),
        _mediaLibrary = mediaLibrary ?? MediaLibrary(),
        _diag = diagnostics ?? Get.find<PlaybackDiagnosticsService>() {
    if (_testable) {
      _cacheDir = '';
      _audioSourceReady = Future.value();
    } else {
      _createCacheDir();
      _addEmptyList();
      _attachPlayerListeners();
    }
    final appPrefsBox = Hive.box("AppPrefs");
    _player
        .setSkipSilenceEnabled(appPrefsBox.get("skipSilenceEnabled") ?? false);
    loopModeEnabled = appPrefsBox.get("isLoopModeEnabled") ?? false;
    shuffleModeEnabled = appPrefsBox.get("isShuffleModeEnabled") ?? false;
    queueLoopModeEnabled =
        Hive.box("AppPrefs").get("queueLoopModeEnabled") ?? false;
    loudnessNormalizationEnabled =
        appPrefsBox.get("loudnessNormalizationEnabled") ?? false;
  }

  Future<void> _createCacheDir() async {
    _cacheDir = (await getTemporaryDirectory()).path;
    if (!Directory("$_cacheDir/cachedSongs/").existsSync()) {
      Directory("$_cacheDir/cachedSongs/").createSync(recursive: true);
    }
  }

  void _addEmptyList() {
    _audioSourceReady = _player.setAudioSource(_playList).catchError((r) {
      printERROR(r.toString());
      return null;
    });
  }

  void _attachPlayerListeners() {
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPlaybackForNextSong();
    _listenForSequenceStateChanges();
    _listenForDurationChanges();
    if (GetPlatform.isAndroid) {
      _listenSessionIdStream();
    }
  }

  void _listenSessionIdStream() {
    _playerSubscriptions
        .add(_player.androidAudioSessionIdStream.listen((int? id) {
      if (id != null) {
        try {
          EqualizerService.initAudioEffect(id);
        } catch (e, st) {
          printERROR('Equalizer init failed: $e\n$st');
        }
      }
    }));
  }

  void _syncPlaybackWakeLock(bool playing) {
    if (!GetPlatform.isAndroid) return;
    final state = _player.processingState;
    final shouldHold =
        playing && state != ProcessingState.completed && state != ProcessingState.idle;
    try {
      final svc = Get.find<PlaybackWakeLockService>();
      if (shouldHold) {
        unawaited(svc.acquire());
      } else {
        unawaited(svc.release());
      }
    } catch (_) {
      // service not registered (non-Android or before init) - ignore
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _playerSubscriptions.add(_player.playbackEventStream.listen(
      _onPlaybackEvent,
      onError: _handlePlaybackStreamError,
    ));
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    final playing = _player.playing;
    _syncPlaybackWakeLock(playing);
    if (_lastLoggedProcessingState != _player.processingState) {
      _lastLoggedProcessingState = _player.processingState;
      if (_player.processingState == ProcessingState.ready) {
        _resetPlayerRecoveryBudget();
      }
      _diag.logEvent(
        category: 'player_event',
        message: 'processing_state_changed',
        songId: _safeCurrentSongId(),
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {
          'processingState': _player.processingState.name,
          'playing': playing,
          'queueIndex': currentIndex,
          'positionMs': _player.position.inMilliseconds,
          'bufferedMs': _player.bufferedPosition.inMilliseconds,
        },
      );
      if (_player.processingState == ProcessingState.completed) {
        unawaited(_triggerNext(reason: 'processing_completed'));
      }
    }
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: isSongLoading
          ? AudioProcessingState.loading
          : const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState]!,
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
      shuffleMode: (shuffleModeEnabled)
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: currentIndex,
    ));

    //print("set ${playbackState.value.queueIndex},${event.currentIndex}");
  }

  Future<void> _handlePlaybackStreamError(Object e, StackTrace st) async {
    try {
      if (e is PlayerException) {
        _diag.logEvent(
          category: 'player_error',
          message: 'player_exception',
          songId: _safeCurrentSongId(),
          backendType: _safeBackendType(),
          activeServerType: _safeServerType(),
          data: {'code': e.code, 'error': e.message},
        );
        printERROR('Error code: ${e.code}');
        printERROR('Error message: ${e.message}');
        final currentQueue = queue.value;
        if (currentQueue.isNotEmpty) {
          final nextIndex = _getNextSongIndex();
          if (nextIndex != currentIndex) {
            await customAction("playByIndex", {'index': nextIndex});
          }
        }
      } else {
        _diag.logEvent(
          category: 'player_error',
          message: 'playback_event_stream_error',
          songId: _safeCurrentSongId(),
          backendType: _safeBackendType(),
          activeServerType: _safeServerType(),
          data: {'error': e.toString()},
        );
        printERROR('An error occurred: $e');
        final curPos = _safePosition();
        try {
          await _player.stop();
        } catch (stopError, stopSt) {
          printWarning(
              '[RECOVERABLE][opId=audio.streamError.stop] Failed to stop player after stream error: $stopError\n$stopSt');
        }

        //Workaround when 403 error encountered
        // customAction("playByIndex", {'index': currentIndex, 'newUrl': true})
        //     .whenComplete(() async {
        //   await _player.stop();
        //   if (currentSongUrl == null) {
        //     networkErrorPause = true;
        //   } else {
        //     _player.play();
        //   }
        // });
        await _recoverPlaybackError(
          _PendingPlayerRecovery(
            error: e,
            resumePosition: curPos,
            resumeSameSource: isPlayingUsingLockCachingSource &&
                e.toString().contains("Connection closed while receiving data"),
            songId: _safeCurrentSongId(),
            requestId: _activePlayRequestId,
          ),
        );
      }
    } catch (handlerError, handlerSt) {
      printWarning(
          '[RECOVERABLE][opId=audio.streamError] Playback error handler failed: $handlerError\n$handlerSt');
    }
  }

  @visibleForTesting
  Future<void> debugHandlePlaybackStreamError(Object error) =>
      _handlePlaybackStreamError(error, StackTrace.current);

  @visibleForTesting
  AudioPlayer get debugPlayer => _player;

  @visibleForTesting
  int get debugConsecutivePlayerFailures => _consecutivePlayerFailures;

  void _resetPlayerRecoveryBudget() {
    _consecutivePlayerFailures = 0;
    _lastPlayerFailureSongId = '';
    _lastPlayerFailureAtMs = 0;
  }

  Duration _safePosition() {
    try {
      return _player.position;
    } catch (_) {
      return Duration.zero;
    }
  }

  String? _safeCurrentSongUrl() {
    try {
      return currentSongUrl;
    } catch (_) {
      return null;
    }
  }

  /// Serializes recovery runs. Errors that arrive while a recovery is already
  /// in flight are coalesced into [_pendingPlayerRecovery] and picked up by
  /// the running loop, so each failure still consumes an attempt without two
  /// recoveries fighting each other.
  Future<void> _recoverPlaybackError(_PendingPlayerRecovery pending) async {
    _pendingPlayerRecovery = pending;
    if (_playerRecoveryRunning) {
      _diag.logEvent(
        category: 'recovery',
        message: 'player_recovery_queued',
        songId: pending.songId,
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
      );
      return;
    }
    _playerRecoveryRunning = true;
    try {
      while (_pendingPlayerRecovery != null) {
        final next = _pendingPlayerRecovery!;
        _pendingPlayerRecovery = null;
        await _runPlayerRecoveryAttempt(next);
      }
    } finally {
      _playerRecoveryRunning = false;
    }
  }

  Future<void> _runPlayerRecoveryAttempt(
      _PendingPlayerRecovery pending) async {
    final isConnectionError = isPlayerConnectionError(pending.error);
    final songKey = pending.songId ?? '';
    final now = _nowMs();
    if (_lastPlayerFailureSongId != songKey ||
        now - _lastPlayerFailureAtMs > playerRecoveryWindowMs) {
      _consecutivePlayerFailures = 0;
    }
    _consecutivePlayerFailures++;
    _lastPlayerFailureSongId = songKey;
    _lastPlayerFailureAtMs = now;
    final attempt = _consecutivePlayerFailures;

    // The signed URL resolved fine (see stream_fetch events) before the
    // platform player reported this failure. This event marks "player could
    // not connect with a valid URL", distinct from "URL fetch failed".
    _diag.logEvent(
      category: 'player_error',
      message: 'player_failed_with_valid_url',
      songId: pending.songId,
      backendType: _safeBackendType(),
      activeServerType: _safeServerType(),
      data: {
        'attempt': attempt,
        'maxAttempts': maxPlayerRecoveryAttempts,
        'isConnectionError': isConnectionError,
        'resumeSameSource': pending.resumeSameSource,
        'errorCode': platformErrorCode(pending.error),
        'error': pending.error.toString(),
        'url': PlaybackDiagnosticsService.sanitizeUrl(_safeCurrentSongUrl()),
        'resumePositionMs': pending.resumePosition.inMilliseconds,
      },
    );

    if (attempt > maxPlayerRecoveryAttempts) {
      _diag.logEvent(
        category: 'recovery',
        message: 'player_recovery_exhausted',
        songId: pending.songId,
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {
          'attempts': maxPlayerRecoveryAttempts,
          'error': pending.error.toString(),
        },
      );
      _surfacePlaybackRecoveryFailure(pending.error, isConnectionError);
      return;
    }

    if (isConnectionError && !await _checkStreamReachable()) {
      _diag.logEvent(
        category: 'recovery',
        message: 'player_recovery_aborted_offline',
        songId: pending.songId,
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {'attempt': attempt},
      );
      _surfacePlaybackRecoveryFailure(pending.error, isConnectionError,
          offline: true);
      return;
    }

    final delayMs = playerRecoveryBackoffMs(attempt);
    _diag.logEvent(
      category: 'recovery',
      message: 'player_recovery_backoff',
      songId: pending.songId,
      backendType: _safeBackendType(),
      activeServerType: _safeServerType(),
      data: {'attempt': attempt, 'delayMs': delayMs},
    );
    await _recoveryDelay(Duration(milliseconds: delayMs));

    if (_isStalePlayRequest(pending.requestId) ||
        pending.songId != _safeCurrentSongId()) {
      _diag.logEvent(
        category: 'recovery',
        message: 'player_recovery_superseded',
        songId: pending.songId,
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {'attempt': attempt, 'requestId': pending.requestId},
      );
      return;
    }

    var recreatedPlayer = false;
    if (isConnectionError && shouldRecreatePlayerForAttempt(attempt)) {
      recreatedPlayer = true;
      await _recreatePlayer(reason: 'connection_error_attempt_$attempt');
    }

    if (pending.resumeSameSource && !recreatedPlayer) {
      _diag.logEvent(
        category: 'recovery',
        message: 'retry_current_from_cache_source',
        songId: pending.songId,
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {
          'positionMs': pending.resumePosition.inMilliseconds,
          'attempt': attempt,
        },
      );
      try {
        await _player.seek(pending.resumePosition, index: 0);
        await _player.play();
      } catch (retryError, retrySt) {
        printWarning(
            '[RECOVERABLE][opId=audio.recovery.cacheRetry] Failed to resume cache source: $retryError\n$retrySt');
        _surfacePlaybackRecoveryFailure(pending.error, isConnectionError);
      }
      return;
    }

    final index = _safeCurrentIndex;
    if (index == null) {
      _diag.logEvent(
        category: 'recovery',
        message: 'player_recovery_no_index',
        songId: pending.songId,
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {'attempt': attempt},
      );
      _surfacePlaybackRecoveryFailure(pending.error, isConnectionError);
      return;
    }

    _diag.logEvent(
      category: 'recovery',
      message: 'force_new_url_for_current_song',
      songId: pending.songId,
      backendType: _safeBackendType(),
      activeServerType: _safeServerType(),
      data: {
        'attempt': attempt,
        'positionMs': pending.resumePosition.inMilliseconds,
        'recreatedPlayer': recreatedPlayer,
      },
    );
    try {
      await customAction('playByIndex',
          {'index': index, 'newUrl': true, 'recoveryRetry': true});
      if (queue.value.isNotEmpty) {
        await _player.seek(pending.resumePosition, index: 0);
      }
    } catch (retryError, retrySt) {
      printWarning(
          '[RECOVERABLE][opId=audio.recovery.retry] Recovery playByIndex failed: $retryError\n$retrySt');
      _surfacePlaybackRecoveryFailure(pending.error, isConnectionError);
    }
  }

  Future<bool> _checkStreamReachable() async {
    try {
      return await _reachabilityCheck(_safeCurrentSongUrl());
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=audio.reachability] Reachability check failed, allowing retry: $e\n$st');
      return true;
    }
  }

  /// Disposes the current player and builds a fresh one from [_playerFactory].
  /// A connection error that keeps coming back with fresh signed URLs points
  /// at a wedged native session (AVPlayer/NSURLSession on iOS, ExoPlayer's
  /// connection pool on Android), not at the URL. Rebuilding the player
  /// discards that session along with its sockets.
  Future<void> _recreatePlayer({required String reason}) async {
    final oldPlayer = _player;
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _playerSubscriptions.clear();
    try {
      await oldPlayer.dispose();
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=audio.recreatePlayer.dispose] Failed to dispose wedged player: $e\n$st');
    }
    _player = _playerFactory();
    _playList =
        ConcatenatingAudioSource(children: [], useLazyPreparation: false);
    if (!_testable) {
      _addEmptyList();
      _attachPlayerListeners();
    }
    try {
      final appPrefsBox = Hive.box("AppPrefs");
      await _player.setSkipSilenceEnabled(
          appPrefsBox.get("skipSilenceEnabled") ?? false);
      await _player.setVolume(_userVolume);
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=audio.recreatePlayer.settings] Failed to reapply player settings: $e\n$st');
    }
    // Any play request still in flight was built on the dead player, force
    // the next consumer to start a fresh request.
    _startPlayRequest();
    _diag.logEvent(
      category: 'recovery',
      message: 'player_instance_recreated',
      songId: _safeCurrentSongId(),
      backendType: _safeBackendType(),
      activeServerType: _safeServerType(),
      data: {'reason': reason},
    );
  }

  void _surfacePlaybackRecoveryFailure(Object error, bool isConnectionError,
      {bool offline = false}) {
    isSongLoading = false;
    currentSongUrl = null;
    final message = offline
        ? 'networkError: no internet connection'
        : isConnectionError
            ? 'networkError: player could not connect after retries'
            : '${error.runtimeType}: $error';
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.error,
      errorCode: platformErrorCode(error) ?? (offline ? -1009 : -1),
      errorMessage: message,
    ));
    try {
      if (Get.isRegistered<PlayerController>()) {
        Get.find<PlayerController>().notifyPlayError(message);
      }
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=audio.recovery.notifyError] Failed to surface playback error: $e\n$st');
    }
  }

  void _listenToPlaybackForNextSong() {
    final playerDurationOffset = autoAdvanceLeadMsForPlatform(
      isWindows: GetPlatform.isWindows,
      isLinux: GetPlatform.isLinux,
      isIOS: GetPlatform.isIOS,
    );
    _playerSubscriptions.add(_player.positionStream.listen((value) async {
      if (shouldSuppressAutoAdvance(
        isSongLoading: isSongLoading,
        nowMs: _nowMs(),
        suppressUntilMs: _suppressAutoAdvanceUntilMs,
      )) {
        return;
      }
      if (!_player.playing) return;
      final effectiveDuration = _effectiveCurrentTrackDuration();
      if (effectiveDuration == null) return;
      if (shouldAutoAdvanceAtPosition(
        position: value,
        effectiveDuration: effectiveDuration,
        leadMs: playerDurationOffset,
      )) {
        await _triggerNext(reason: 'position_threshold');
      }
    }));
  }

  // 'length' is the API-provided "m:ss" label. Unlike the duration field it
  // is never overwritten with a player-reported value, so it stays a
  // trustworthy baseline even for cache entries written while the iOS
  // doubled-duration bug was active.
  int? _lengthLabelMs(MediaItem song) {
    final raw = song.extras?['length'];
    if (raw == null) return null;
    final parsed = MediaItemBuilder.toDuration(raw.toString());
    if (parsed == null || parsed.inMilliseconds <= 0) return null;
    return parsed.inMilliseconds;
  }

  List<int?> _extraBaselinesFor(MediaItem song) => [
        _lengthLabelMs(song),
        _knownBaselineMs[song.id],
      ];

  Duration? _effectiveCurrentTrackDuration() {
    final queueSnapshot = queue.value;
    final idx = _safeCurrentIndex;
    if (idx == null || queueSnapshot.isEmpty) return _player.duration;
    if (idx < 0 || idx >= queueSnapshot.length) {
      return _player.duration;
    }
    final currentSong = queueSnapshot[idx];
    final rawOriginalMs = currentSong.extras?['originalDurationMs'];
    final originalMs = rawOriginalMs is int ? rawOriginalMs : null;
    return resolveEffectiveTrackDuration(
      playerDuration: _player.duration,
      mediaDuration: currentSong.duration,
      originalDurationMs: originalMs,
      extraBaselineMs: _extraBaselinesFor(currentSong),
    );
  }

  String _currentTrackGuardKey() {
    final queueSnapshot = queue.value;
    final idx = _safeCurrentIndex;
    if (idx == null || queueSnapshot.isEmpty) return '';
    if (idx < 0 || idx >= queueSnapshot.length) return '';
    return queueSnapshot[idx].id;
  }

  Future<void> _triggerNext({required String reason}) async {
    if (shouldSuppressAutoAdvance(
      isSongLoading: isSongLoading,
      nowMs: _nowMs(),
      suppressUntilMs: _suppressAutoAdvanceUntilMs,
    )) {
      final message = isSongLoading
          ? 'auto_advance_suppressed_loading'
          : 'auto_advance_suppressed_transition_window';
      _diag.logEvent(
        category: 'auto_advance',
        message: message,
        songId: _safeCurrentSongId(),
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {
          'reason': reason,
          'isSongLoading': isSongLoading,
          'suppressUntilMs': _suppressAutoAdvanceUntilMs,
          'nowMs': _nowMs(),
        },
      );
      return;
    }

    final guardSongId = _currentTrackGuardKey();
    final guardIndex = currentIndex is int ? currentIndex as int : -1;
    if (guardSongId.isNotEmpty && guardIndex >= 0) {
      final acquired = _autoAdvanceGuard.tryAcquire(
        songId: guardSongId,
        queueIndex: guardIndex,
      );
      if (!acquired) {
        _diag.logEvent(
          category: 'auto_advance',
          message: 'auto_advance_skipped_duplicate',
          songId: guardSongId,
          backendType: _safeBackendType(),
          activeServerType: _safeServerType(),
          data: {'reason': reason, 'index': guardIndex},
        );
        return;
      }
      _diag.logEvent(
        category: 'auto_advance',
        message: 'auto_advance_decision',
        songId: guardSongId,
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {
          'reason': reason,
          'index': guardIndex,
          'positionMs': _player.position.inMilliseconds,
          'effectiveDurationMs':
              _effectiveCurrentTrackDuration()?.inMilliseconds,
        },
      );
    }

    if (loopModeEnabled) {
      await _player.seek(Duration.zero);
      if (!_player.playing) {
        await _player.play();
      }
      _autoAdvanceGuard.reset();
      return;
    }
    await skipToNext();
  }

  void _listenForSequenceStateChanges() {
    _playerSubscriptions.add(
        _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
    }));
  }

  void _listenForDurationChanges() {
    _playerSubscriptions.add(_player.durationStream.listen((duration) async {
      final currQueue = queue.value;
      final idx = _safeCurrentIndex;
      if (idx == null || currQueue.isEmpty || duration == null) return;
      final currentSong = queue.value[idx];
      // Only iOS always follows the player duration stream. Everywhere else,
      // use it only when the MediaItem has no duration yet. Including idx==0
      // on desktop broke YT Music after radio/album play: just_audio often
      // reports ~2× the real length for the first queued source, which then
      // overwrote correct metadata and doubled the progress bar total.
      final meta = currentSong.duration;
      final missingMeta = meta == null || meta.inMilliseconds <= 0;
      final usePlayerDuration = GetPlatform.isIOS || missingMeta;
      if (usePlayerDuration && duration.inSeconds > 0) {
        Map<String, dynamic>? newExtras = currentSong.extras != null
            ? Map<String, dynamic>.from(currentSong.extras!)
            : null;
        final extraBaselines = _extraBaselinesFor(currentSong);
        final rawOriginalMs = currentSong.extras?['originalDurationMs'];
        int? originalMs = rawOriginalMs is int ? rawOriginalMs : null;
        if (Platform.isIOS || Platform.isMacOS) {
          final baselineMs = pickBaselineDurationMs([
            currentSong.duration?.inMilliseconds,
            originalMs,
            ...extraBaselines,
          ]);
          // Persist the cleaned baseline so later reads don't trust a
          // duration that was polluted by the doubled-duration bug.
          if (baselineMs != null && originalMs != baselineMs) {
            newExtras ??= {};
            newExtras['originalDurationMs'] = baselineMs;
          }
          originalMs ??= baselineMs;
        }
        final effectiveDuration = resolveEffectiveTrackDuration(
          playerDuration: duration,
          mediaDuration: currentSong.duration,
          originalDurationMs: originalMs,
          extraBaselineMs: extraBaselines,
        );
        if (effectiveDuration == null) return;
        final newMediaItem = currentSong.copyWith(
          duration: effectiveDuration,
          extras: newExtras ?? currentSong.extras,
        );
        mediaItem.add(newMediaItem);
      }
    }));
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final newQueue = queue.value.toList()..addAll(mediaItems);
    queue.add(newQueue);
    if (shuffleModeEnabled) {
      originalQueue.addAll(mediaItems);
      final effectiveQueue = newQueue.toList();
      final insertItems = mediaItems.toList()..shuffle();
      final insertAt =
          ((currentIndex ?? 0) + 1).clamp(0, effectiveQueue.length);
      effectiveQueue
        ..removeWhere((item) => insertItems.contains(item))
        ..insertAll(insertAt, insertItems);
      queue.add(effectiveQueue);
      shuffledQueue = effectiveQueue.map((item) => item.id).toList();
    } else {
      originalQueue = newQueue.toList();
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    final newQueue = this.queue.value
      ..replaceRange(0, this.queue.value.length, queue);
    this.queue.add(newQueue);
    originalQueue = queue.toList();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = queue.value.toList()..add(mediaItem);
    queue.add(newQueue);
    if (shuffleModeEnabled) {
      originalQueue.add(mediaItem);
      final effectiveQueue = newQueue.toList();
      final insertAt =
          ((currentIndex ?? 0) + 1).clamp(0, effectiveQueue.length);
      effectiveQueue
        ..remove(mediaItem)
        ..insert(insertAt, mediaItem);
      queue.add(effectiveQueue);
      shuffledQueue = effectiveQueue.map((item) => item.id).toList();
    } else {
      originalQueue = newQueue.toList();
    }
  }

  // On iOS/macOS, AVPlayer misreads the container of some streams and reports
  // roughly double the real duration, then keeps playing silence for the
  // phantom tail. Clipping the source to the known duration makes the player
  // report and complete at the real end. StreamAudioSource variants (e.g.
  // LockCachingAudioSource) can't be clipped, so they keep the metadata-level
  // correction in _listenForDurationChanges instead.
  AudioSource _audioSourceFor(MediaItem mediaItem, int? baselineMs) {
    final source = _createAudioSource(mediaItem);
    if ((GetPlatform.isIOS || GetPlatform.isMacOS) &&
        baselineMs != null &&
        source is UriAudioSource) {
      return ClippingAudioSource(
        child: source,
        end: Duration(milliseconds: baselineMs),
        tag: mediaItem,
      );
    }
    return source;
  }

  AudioSource _createAudioSource(MediaItem mediaItem) {
    final url = mediaItem.extras!['url'] as String;
    if (url.contains('/cache') ||
        (Get.find<SettingsScreenController>().cacheSongs.isTrue &&
            url.contains("http"))) {
      _diag.logEvent(
        category: 'audio_source',
        message: 'using_lock_caching_audio_source',
        songId: mediaItem.id,
        backendType: mediaItem.extras?['backendType']?.toString(),
        activeServerType: _safeServerType(),
        data: {
          'url': PlaybackDiagnosticsService.sanitizeUrl(url),
        },
      );
      printINFO("Playing Using LockCaching");
      isPlayingUsingLockCachingSource = true;
      // ignore: experimental_member_use
      return LockCachingAudioSource(
        Uri.parse(url),
        cacheFile: File("$_cacheDir/cachedSongs/${mediaItem.id}.mp3"),
        headers: _youtubeStreamHeaders(url),
        tag: mediaItem,
      );
    }

    _diag.logEvent(
      category: 'audio_source',
      message: 'using_audio_source_uri',
      songId: mediaItem.id,
      backendType: mediaItem.extras?['backendType']?.toString(),
      activeServerType: _safeServerType(),
      data: {
        'url': PlaybackDiagnosticsService.sanitizeUrl(url),
      },
    );
    printINFO("Playing Using AudioSource.uri");
    isPlayingUsingLockCachingSource = false;
    return AudioSource.uri(
      Uri.tryParse(url)!,
      headers: _youtubeStreamHeaders(url),
      tag: mediaItem,
    );
  }

  Map<String, String>? _youtubeStreamHeaders(String url) {
    if (!url.contains('googlevideo.com')) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final client = uri.queryParameters['c'];
    const uaMap = {
      'IOS':
          'com.google.ios.youtube/21.24.3 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X;)',
      'ANDROID_VR':
          'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      'ANDROID':
          'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      'ANDROID_MUSIC':
          'com.google.android.youtube/19.29.1 (Linux; U; Android 11) gzip',
      'TVHTML5':
          'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version,gzip(gfe)',
      'MWEB':
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      'MEDIA_CONNECT_FRONTEND':
          'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      'WEB':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)',
      'VISIONOS':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
    };
    final ua = uaMap[client];
    if (ua == null) return null;
    return {
      'User-Agent': ua,
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com/',
    };
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<void> removeQueueItem(MediaItem mediaItem_) async {
    originalQueue.removeWhere((item) => item.id == mediaItem_.id);

    final currentQueue = queue.value;
    final currentSong = mediaItem.value;
    final itemIndex = currentQueue.indexOf(mediaItem_);
    if (currentIndex > itemIndex) {
      currentIndex -= 1;
    }
    currentQueue.remove(mediaItem_);
    queue.add(currentQueue);
    mediaItem.add(currentSong);
    shuffledQueue = queue.value.map((item) => item.id).toList();
  }

  @override
  Future<void> play() async {
    if (currentSongUrl == null) {
      await customAction("playByIndex", {'index': currentIndex});
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await customAction("playByIndex", {'index': index});
  }

  int _getNextSongIndex() {
    if (queue.value.isEmpty) return currentIndex ?? 0;
    currentIndex ??= 0;
    if (shuffleModeEnabled) {
      final nextIndex = currentIndex + 1;
      if (nextIndex < queue.value.length) {
        return nextIndex;
      }
      if (queueLoopModeEnabled) {
        _reshuffleKeepingCurrentFirst();
        return queue.value.length > 1 ? 1 : 0;
      }
      return currentIndex;
    }

    if (queue.value.length > currentIndex + 1) {
      return currentIndex + 1;
    } else if (queueLoopModeEnabled) {
      return 0;
    } else {
      return currentIndex;
    }
  }

  int _getPrevSongIndex() {
    if (queue.value.isEmpty) return currentIndex ?? 0;
    currentIndex ??= 0;
    if (shuffleModeEnabled) {
      if (currentIndex - 1 >= 0) {
        return currentIndex - 1;
      }
      if (queueLoopModeEnabled) {
        return queue.value.length - 1;
      }
      return currentIndex;
    }

    if (currentIndex - 1 >= 0) {
      return currentIndex - 1;
    } else {
      return currentIndex;
    }
  }

  @override
  Future<void> skipToNext() async {
    final index = _getNextSongIndex();
    if (index != currentIndex) {
      if (_player.position != Duration.zero) _player.seek(Duration.zero);
      await customAction("playByIndex", {'index': index});
    } else {
      _diag.logEvent(
        category: 'auto_advance',
        message: 'auto_advance_queue_end',
        songId: _safeCurrentSongId(),
        backendType: _safeBackendType(),
        activeServerType: _safeServerType(),
        data: {'index': currentIndex},
      );
      _player.seek(Duration.zero);
      _player.pause();
      _autoAdvanceGuard.reset();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inMilliseconds > 5000) {
      _player.seek(Duration.zero);
      return;
    }
    _player.seek(Duration.zero);
    final index = _getPrevSongIndex();
    if (index != currentIndex) {
      await customAction("playByIndex", {'index': index});
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (repeatMode == AudioServiceRepeatMode.none) {
      loopModeEnabled = false;
    } else {
      loopModeEnabled = true;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      shuffleModeEnabled = false;
      shuffledQueue.clear();
      _restoreOriginalQueue();
    } else {
      _shuffleCmd(currentIndex ?? 0);
      shuffleModeEnabled = true;
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'dispose':
        _syncPlaybackWakeLock(false);
        for (final subscription in _playerSubscriptions) {
          unawaited(subscription.cancel());
        }
        _playerSubscriptions.clear();
        await _player.dispose();
        super.stop();
        break;

      case 'playByIndex':
        final songIndex = extras!['index'] as int;
        final requestId = _startPlayRequest();
        _autoAdvanceGuard.reset();
        if (extras['recoveryRetry'] != true) {
          _resetPlayerRecoveryBudget();
        }
        if (songIndex < 0 || songIndex >= queue.value.length) {
          _diag.logEvent(
            category: 'player_error',
            message: 'play_by_index_invalid_index',
            songId: _safeCurrentSongId(),
            backendType: _safeBackendType(),
            activeServerType: _safeServerType(),
            data: {'index': songIndex, 'queueLength': queue.value.length},
          );
          return;
        }
        currentIndex = songIndex;
        final isNewUrlReq = extras['newUrl'] ?? false;
        final currentSong = queue.value[currentIndex];
        final requestedSongId = currentSong.id;
        _diag.logEvent(
          category: 'player_event',
          message: 'play_by_index_start',
          songId: currentSong.id,
          backendType: currentSong.extras?['backendType']?.toString(),
          activeServerType: _safeServerType(),
          data: {
            'index': songIndex,
            'newUrl': isNewUrlReq,
            'restoreSession': extras['restoreSession'] ?? false,
          },
        );
        final futureStreamInfo = checkNGetUrl(currentSong.id,
            generateNewUrl: isNewUrlReq, extras: currentSong.extras);
        final bool restoreSession = extras['restoreSession'] ?? false;
        isSongLoading = true;
        playbackState.add(playbackState.value
            .copyWith(processingState: AudioProcessingState.loading));
        _diag.logEvent(
          category: 'player_event',
          message: 'stop_before_playlist_clear',
          songId: requestedSongId,
          backendType: currentSong.extras?['backendType']?.toString(),
          activeServerType: _safeServerType(),
          data: {
            'processingState': _player.processingState.name,
            'playing': _player.playing,
          },
        );
        // Only stop when the player is in completed state. Calling stop()
        // unconditionally on desktop breaks media_kit: after stop + clear +
        // open(new source), the subsequent play() call doesn't start playback
        // because the platform's load() pauses the player at the wrong time.
        // The original stop() was added to fix auto-advance getting stuck in
        // completed state, so we only need it in that case.
        if (_player.processingState == ProcessingState.completed) {
          await _player.stop();
        }
        if (_playList.children.isNotEmpty) {
          await _playList.clear();
        }
        if (_isStalePlayRequest(requestId)) {
          _diag.logEvent(
            category: 'recovery',
            message: 'play_request_stale_ignored',
            songId: requestedSongId,
            backendType: currentSong.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'stage': 'after_playlist_clear', 'requestId': requestId},
          );
          return;
        }
        final streamInfo = await futureStreamInfo;
        if (_isStalePlayRequest(requestId)) {
          _diag.logEvent(
            category: 'recovery',
            message: 'play_request_stale_ignored',
            songId: requestedSongId,
            backendType: currentSong.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'stage': 'after_stream_fetch', 'requestId': requestId},
          );
          return;
        }
        final currentQueue = queue.value;
        final idx = _safeCurrentIndex;
        final hasRequestedSongAtIndex = idx != null &&
            idx >= 0 &&
            idx < currentQueue.length &&
            currentQueue[idx].id == requestedSongId;
        if (songIndex != currentIndex || !hasRequestedSongAtIndex) {
          _diag.logEvent(
            category: 'recovery',
            message: 'play_by_index_aborted_stale_request',
            songId: currentSong.id,
            backendType: currentSong.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {
              'requestId': requestId,
              'requestedIndex': songIndex,
              'activeIndex': currentIndex,
              'hasRequestedSongAtIndex': hasRequestedSongAtIndex,
            },
          );
          return;
        }
        if (!streamInfo.playable) {
          _diag.logEvent(
            category: 'player_error',
            message: 'stream_not_playable',
            songId: currentSong.id,
            backendType: currentSong.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'status': streamInfo.statusMSG},
          );
          currentSongUrl = null;
          isSongLoading = false;
          Get.find<PlayerController>().notifyPlayError(streamInfo.statusMSG);
          playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.error,
              errorCode: 404,
              errorMessage: streamInfo.statusMSG));

          final currentQueue = queue.value;
          if (currentQueue.isNotEmpty) {
            final nextIndex = _getNextSongIndex();
            if (nextIndex != currentIndex) {
              await customAction("playByIndex", {'index': nextIndex});
            }
          }
          return;
        }
        final activeSong = currentQueue[currentIndex];
        currentSongUrl = activeSong.extras!['url'] = streamInfo.audio!.url;
        _diag.logEvent(
          category: 'stream_select',
          message: 'stream_selected',
          songId: activeSong.id,
          backendType: activeSong.extras?['backendType']?.toString(),
          activeServerType: _safeServerType(),
          data: {
            'itag': streamInfo.audio?.itag,
            'codec': streamInfo.audio?.audioCodec.name,
            'bitrate': streamInfo.audio?.bitrate,
            'url':
                PlaybackDiagnosticsService.sanitizeUrl(streamInfo.audio?.url),
            'fromCache': !isNewUrlReq,
          },
        );
        final streamEstimateMs = streamDurationEstimateMs(
          sizeBytes: streamInfo.audio?.size ?? 0,
          bitrateBps: streamInfo.audio?.bitrate ?? 0,
        );
        final baselineMs = pickBaselineDurationMs([
          activeSong.duration?.inMilliseconds,
          _lengthLabelMs(activeSong),
          streamEstimateMs,
        ]);
        if (baselineMs != null) {
          _knownBaselineMs[activeSong.id] = baselineMs;
        }
        final songToAdd = baselineMs != null
            ? activeSong.copyWith(
                duration: Duration(milliseconds: baselineMs),
                extras: {
                  ...?activeSong.extras,
                  'originalDurationMs': baselineMs,
                },
              )
            : activeSong;
        mediaItem.add(songToAdd);
        playbackState
            .add(playbackState.value.copyWith(queueIndex: currentIndex));
        if (_isStalePlayRequest(requestId)) {
          _diag.logEvent(
            category: 'recovery',
            message: 'play_request_stale_ignored',
            songId: activeSong.id,
            backendType: activeSong.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'stage': 'before_add_audio_source', 'requestId': requestId},
          );
          return;
        }
        await _audioSourceReady;
        await _playList.add(_audioSourceFor(activeSong, baselineMs));

        isSongLoading = false;
        if (loudnessNormalizationEnabled && GetPlatform.isAndroid) {
          _normalizeVolume(streamInfo.audio!.loudnessDb);
        }

        if (restoreSession) {
          if (!GetPlatform.isDesktop) {
            final position = extras['position'];
            await _player.load();
            await _player.seek(
              Duration(
                milliseconds: position,
              ),
            );
            await _player.seek(
              Duration(
                milliseconds: position,
              ),
            );
          }
        } else {
          await _player.seek(Duration.zero);
          await _player.play();
          _ensurePlaybackStarted();
        }
        _diag.logEvent(
          category: 'player_event',
          message: 'play_by_index_complete',
          songId: currentSong.id,
          backendType: currentSong.extras?['backendType']?.toString(),
          activeServerType: _safeServerType(),
          data: {'playing': _player.playing},
        );
        break;

      case 'checkWithCacheDb':
        if (isPlayingUsingLockCachingSource) {
          final song = extras!['mediaItem'] as MediaItem;
          final songsCacheBox = Hive.box(songsCacheBoxName(currentServerId()));
          if (!songsCacheBox.containsKey(song.id) &&
              await File("$_cacheDir/cachedSongs/${song.id}.mp3").exists()) {
            song.extras!['url'] = currentSongUrl;
            song.extras!['date'] = DateTime.now().millisecondsSinceEpoch;
            final dbStreamData = Hive.box(songsUrlCacheBoxName(currentServerId())).get(song.id);
            final jsonData = MediaItemBuilder.toJson(song);
            // Never persist the raw player duration: on iOS/macOS AVPlayer can
            // report ~2x the real length, which would corrupt the stored
            // duration and later defeat the doubled-duration correction.
            jsonData['duration'] =
                (_effectiveCurrentTrackDuration() ?? song.duration)
                    ?.inSeconds;
            // playbility status and info
            jsonData['streamInfo'] = dbStreamData != null
                ? [
                    true,
                    dbStreamData[
                        Hive.box('AppPrefs').get('streamingQuality') == 0
                            ? 'lowQualityAudio'
                            : "highQualityAudio"]
                  ]
                : null;
            songsCacheBox.put(song.id, jsonData);
            LibrarySongsController librarySongsController =
                Get.find<LibrarySongsController>();
            if (!librarySongsController.isClosed) {
              librarySongsController.librarySongsList.value =
                  librarySongsController.librarySongsList.toList() + [song];
            }
          }
        }
        break;

      case 'setSourceNPlay':
        final currMed = (extras!['mediaItem'] as MediaItem);
        final requestId = _startPlayRequest();
        _autoAdvanceGuard.reset();
        _resetPlayerRecoveryBudget();
        _diag.logEvent(
          category: 'player_event',
          message: 'set_source_n_play_start',
          songId: currMed.id,
          backendType: currMed.extras?['backendType']?.toString(),
          activeServerType: _safeServerType(),
        );
        final futureStreamInfo =
            checkNGetUrl(currMed.id, extras: currMed.extras);
        isSongLoading = true;
        currentIndex = 0;
        if (_player.processingState == ProcessingState.completed) {
          await _player.stop();
        }
        await _playList.clear();
        if (_isStalePlayRequest(requestId)) {
          _diag.logEvent(
            category: 'recovery',
            message: 'set_source_stale_ignored',
            songId: currMed.id,
            backendType: currMed.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'stage': 'after_playlist_clear', 'requestId': requestId},
          );
          return;
        }
        final streamInfo = (await futureStreamInfo);
        if (_isStalePlayRequest(requestId)) {
          _diag.logEvent(
            category: 'recovery',
            message: 'set_source_stale_ignored',
            songId: currMed.id,
            backendType: currMed.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'stage': 'after_stream_fetch', 'requestId': requestId},
          );
          return;
        }
        if (!streamInfo.playable) {
          _diag.logEvent(
            category: 'player_error',
            message: 'set_source_n_play_stream_not_playable',
            songId: currMed.id,
            backendType: currMed.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'status': streamInfo.statusMSG},
          );
          currentSongUrl = null;
          isSongLoading = false;
          Get.find<PlayerController>().notifyPlayError(streamInfo.statusMSG);
          playbackState.add(playbackState.value
              .copyWith(processingState: AudioProcessingState.error));
          return;
        }
        final singleBaselineMs = pickBaselineDurationMs([
          currMed.duration?.inMilliseconds,
          _lengthLabelMs(currMed),
          streamDurationEstimateMs(
            sizeBytes: streamInfo.audio?.size ?? 0,
            bitrateBps: streamInfo.audio?.bitrate ?? 0,
          ),
        ]);
        if (singleBaselineMs != null) {
          _knownBaselineMs[currMed.id] = singleBaselineMs;
        }
        queue.add([currMed]);
        mediaItem.add(singleBaselineMs != null
            ? currMed.copyWith(
                duration: Duration(milliseconds: singleBaselineMs),
                extras: {
                  ...?currMed.extras,
                  'originalDurationMs': singleBaselineMs,
                },
              )
            : currMed);
        currentSongUrl = currMed.extras!['url'] = streamInfo.audio!.url;
        _diag.logEvent(
          category: 'stream_select',
          message: 'set_source_n_play_stream_selected',
          songId: currMed.id,
          backendType: currMed.extras?['backendType']?.toString(),
          activeServerType: _safeServerType(),
          data: {
            'itag': streamInfo.audio?.itag,
            'codec': streamInfo.audio?.audioCodec.name,
            'bitrate': streamInfo.audio?.bitrate,
            'url':
                PlaybackDiagnosticsService.sanitizeUrl(streamInfo.audio?.url),
          },
        );

        if (_isStalePlayRequest(requestId)) {
          _diag.logEvent(
            category: 'recovery',
            message: 'set_source_stale_ignored',
            songId: currMed.id,
            backendType: currMed.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'stage': 'before_add_audio_source', 'requestId': requestId},
          );
          return;
        }
        await _audioSourceReady;
        await _playList.add(_audioSourceFor(currMed, singleBaselineMs));
        isSongLoading = false;

        // Normalize audio
        if (loudnessNormalizationEnabled && GetPlatform.isAndroid) {
          _normalizeVolume(streamInfo.audio!.loudnessDb);
        }

        await _player.seek(Duration.zero);
        await _player.play();
        _ensurePlaybackStarted();
        break;

      case 'toggleSkipSilence':
        final enable = (extras!['enable'] as bool);
        await _player.setSkipSilenceEnabled(enable);
        break;

      case 'toggleLoudnessNormalization':
        loudnessNormalizationEnabled = (extras!['enable'] as bool);
        if (!loudnessNormalizationEnabled) {
          _player.setVolume(_userVolume);
          return;
        }

        if (loudnessNormalizationEnabled) {
          try {
            final currentSongId = (queue.value[currentIndex]).id;
            if (Hive.box(songsUrlCacheBoxName(currentServerId())).containsKey(currentSongId)) {
              final songJson = Hive.box(songsUrlCacheBoxName(currentServerId())).get(currentSongId);
              _normalizeVolume((songJson)["highQualityAudio"]["loudnessDb"]);
              return;
            }

            if (Hive.box(songDownloadsBoxName(currentServerId())).containsKey(currentSongId)) {
              final streamInfo =
                  (Hive.box(songDownloadsBoxName(currentServerId())).get(currentSongId))["streamInfo"];

              _normalizeVolume(
                  streamInfo == null ? 0 : streamInfo[1]["loudnessDb"]);
            }
          } catch (e) {
            printERROR(e);
          }
        }
        break;

      case 'shuffleQueue':
        final currentQueue = queue.value;
        final currentItem = currentQueue[currentIndex];
        currentQueue.remove(currentItem);
        currentQueue.shuffle();
        currentQueue.insert(0, currentItem);
        queue.add(currentQueue);
        mediaItem.add(currentItem);
        currentIndex = 0;
        originalQueue = currentQueue.toList();
        shuffledQueue = currentQueue.map((item) => item.id).toList();
        break;

      case 'reorderQueue':
        final oldIndex = extras!['oldIndex'] as int?;
        int? newIndex = extras['newIndex'] as int?;

        if (oldIndex == null || newIndex == null) break;
        if (oldIndex < 0 || newIndex < 0) break;

        final currentQueue = queue.value;
        if (currentQueue.isEmpty || oldIndex >= currentQueue.length) break;

        if (oldIndex < newIndex) {
          newIndex--;
        }

        final safeCurrentIndex = _safeCurrentIndex;
        final currentItem = safeCurrentIndex != null &&
                safeCurrentIndex >= 0 &&
                safeCurrentIndex < currentQueue.length
            ? currentQueue[safeCurrentIndex]
            : null;
        final item = currentQueue.removeAt(oldIndex);
        currentQueue.insert(newIndex.clamp(0, currentQueue.length), item);
        if (currentItem != null) {
          currentIndex = currentQueue.indexOf(currentItem);
        }
        queue.add(currentQueue);
        if (currentItem != null) {
          mediaItem.add(currentItem);
        }
        if (!shuffleModeEnabled) {
          originalQueue = currentQueue.toList();
        }
        break;

      case 'addPlayNextItem':
        final song = extras!['mediaItem'] as MediaItem;
        final currentQueue = queue.value;
        currentQueue.insert(currentIndex + 1, song);
        queue.add(currentQueue);
        if (shuffleModeEnabled) {
          originalQueue.add(song);
          shuffledQueue = currentQueue.map((item) => item.id).toList();
        } else {
          originalQueue = currentQueue.toList();
        }
        break;

      case 'openEqualizer':
        EqualizerService.openEqualizer(_player.androidAudioSessionId!);
        break;

      case 'saveSession':
        await saveSessionData();
        break;

      case 'setVolume':
        _userVolume = (extras!['value'] as num).toDouble();
        _player.setVolume(_userVolume);
        break;

      case 'shuffleCmd':
        final songIndex = extras!['index'];
        _shuffleCmd(songIndex);
        break;

      case 'upadateMediaItemInAudioService':
        //added to update media item from player controller
        final songIndex = extras!['index'];
        currentIndex = songIndex;
        mediaItem.add(queue.value[currentIndex]);
        break;

      case 'toggleQueueLoopMode':
        queueLoopModeEnabled = extras!['enable'];
        break;

      case 'clearQueue':
        if (currentIndex is int && currentIndex > 0) {
          customAction(
              "reorderQueue", {'oldIndex': currentIndex, 'newIndex': 0});
        }
        final newQueue = queue.value;
        if (newQueue.length > 1) {
          newQueue.removeRange(1, newQueue.length);
        }
        queue.add(newQueue);
        originalQueue = newQueue.toList();
        if (shuffleModeEnabled) {
          shuffledQueue.clear();
          if (newQueue.isNotEmpty) {
            shuffledQueue.add(newQueue[0].id);
          }
          currentShuffleIndex = 0;
        }
        break;
      default:
        break;
    }
  }

  void _shuffleCmd(int index) {
    if (!shuffleModeEnabled) {
      originalQueue = queue.value.toList();
    }
    final currentQueue = queue.value.toList();
    if (currentQueue.isEmpty) return;
    final safeIndex = index.clamp(0, currentQueue.length - 1);
    final currentSong = currentQueue.removeAt(safeIndex);
    currentQueue.shuffle();
    final shuffled = [currentSong, ...currentQueue];
    queue.add(shuffled);
    currentIndex = 0;
    mediaItem.add(currentSong);
    shuffledQueue = shuffled.map((item) => item.id).toList();
    currentShuffleIndex = 0;
  }

  void _reshuffleKeepingCurrentFirst() {
    final currentQueue = queue.value.toList();
    if (currentQueue.isEmpty) return;
    final activeIndex = (currentIndex ?? 0).clamp(0, currentQueue.length - 1);
    final currentSong = currentQueue.removeAt(activeIndex);
    currentQueue.shuffle();
    final reshuffled = [currentSong, ...currentQueue];
    queue.add(reshuffled);
    currentIndex = 0;
    mediaItem.add(currentSong);
    shuffledQueue = reshuffled.map((item) => item.id).toList();
    currentShuffleIndex = 0;
  }

  void _restoreOriginalQueue() {
    if (originalQueue.isEmpty) return;
    final currentSong = mediaItem.value;
    final restoredQueue = originalQueue.toList();
    int restoredIndex = 0;
    if (currentSong != null) {
      final idx = restoredQueue.indexWhere((item) => item.id == currentSong.id);
      if (idx != -1) restoredIndex = idx;
    }
    queue.add(restoredQueue);
    currentIndex = restoredIndex.clamp(0, restoredQueue.length - 1);
    mediaItem.add(restoredQueue[currentIndex]);
  }

  void _normalizeVolume(double currentLoudnessDb) {
    double loudnessDifference = -5 - currentLoudnessDb;

    // Converted loudness difference to a volume multiplier
    // 10^(difference / 20) converts dB difference to a linear volume factor
    final volumeAdjustment = pow(10.0, loudnessDifference / 20.0);
    // Multiply by the user's volume preference so the slider still works
    // when loudness normalization is enabled
    final adjustedVolume =
        (_userVolume * volumeAdjustment).toDouble().clamp(0.0, 1.0);
    printINFO(
        "loudness:$currentLoudnessDb Normalized volume: $adjustedVolume (user: $_userVolume, adj: $volumeAdjustment)");
    _player.setVolume(adjustedVolume);
  }

  /// Guards against a race condition in just_audio_media_kit where the
  /// platform's load() sends a pause command without awaiting it. If that
  /// pause lands after our play() call, the player ends up paused even though
  /// we asked it to play. This re-issues play() after a short delay on
  /// desktop platforms where media_kit is used.
  void _ensurePlaybackStarted() {
    if (!GetPlatform.isDesktop) return;
    final expectedRequestId = _activePlayRequestId;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isStalePlayRequest(expectedRequestId)) return;
      if (isSongLoading) return;
      if (_player.processingState == ProcessingState.completed ||
          _player.processingState == ProcessingState.idle) {
        return;
      }
      if (!_player.playing) {
        _diag.logEvent(
          category: 'recovery',
          message: 're_issue_play_after_race',
          songId: _safeCurrentSongId(),
          backendType: _safeBackendType(),
          activeServerType: _safeServerType(),
          data: {
            'processingState': _player.processingState.name,
            'playing': _player.playing,
          },
        );
        _player.play();
      }
    });
  }

  Future<void> saveSessionData() async {
    if (Get.find<SettingsScreenController>().restorePlaybackSession.isFalse) {
      return;
    }
    final currQueue = queue.value;
    if (currQueue.isNotEmpty) {
      final queueData =
          currQueue.map((e) => MediaItemBuilder.toJson(e)).toList();
      final currIndex = currentIndex ?? 0;
      final position = _player.position.inMilliseconds;
      final prevSessionData =
          await Hive.openBox(prevSessionDataBoxName(currentServerId()));
      await prevSessionData.clear();
      await prevSessionData.putAll(
          {"queue": queueData, "position": position, "index": currIndex});
      await prevSessionData.close();
      printINFO("Saved session data");
    }
  }

  /// Android Auto
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    return _mediaLibrary.getByRootId(parentMediaId);
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    return Stream.fromFuture(
            _mediaLibrary.getByRootId(parentMediaId).then((items) => items))
        .map((_) => <String, dynamic>{})
        .shareValue();
  }

  // only for Android Auto
  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    // Handle direct-play buttons from the More menu — use the same
    // HomeScreenController methods the mobile app uses for instant playback
    if (mediaId == MediaLibrary.moreShuffleAllId) {
      final l10n = l10nFromPrefs();
      await Get.find<HomeScreenController>().shuffleAll(
        emptyMessage: l10n.noSongsInLibrary,
        playFromName: l10n.shuffleAll,
      );
      return;
    }
    if (mediaId == MediaLibrary.moreFavoritesId) {
      final l10n = l10nFromPrefs();
      await Get.find<HomeScreenController>().shuffleFavorites(
        emptyMessage: l10n.favoritesEmpty,
        playFromName: l10n.favorites,
      );
      return;
    }

    // Handle server switching from Settings -> Servers
    if (mediaId.startsWith('server_switch_')) {
      final idStr = mediaId.substring('server_switch_'.length);
      final id = int.tryParse(idStr);
      if (id != null) {
        Get.find<SettingsScreenController>().setActiveServer(id);
      }
      return;
    }

    // About items are display-only — no action on tap
    if (mediaId.startsWith('about_')) {
      return;
    }

    // extras from native Android Auto are usually null, so fall back
    // to the last browsed album/playlist ID tracked by MediaLibrary
    final libraryId = extras?['libraryId']?.toString() ??
        _mediaLibrary._lastBrowseId;
    printINFO('playFromMediaId: mediaId=$mediaId, libraryId=$libraryId');
    customEvent.add({
      'eventType': 'playFromMediaId',
      'songId': mediaId,
      'libraryId': libraryId,
    });
  }

  @override
  Future<void> onTaskRemoved() async {
    final stopForegroundService =
        Get.find<SettingsScreenController>().stopPlyabackOnSwipeAway.value;
    if (stopForegroundService) {
      await Get.find<HomeScreenController>().cachedHomeScreenData();
      await saveSessionData();
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

// Work around used [useNewInstanceOfExplode = false] to Fix Connection closed before full header was received issue
  Future<HMStreamingData> checkNGetUrl(String songId,
      {bool generateNewUrl = false,
      bool offlineReplacementUrl = false,
      Map<String, dynamic>? extras}) async {
    final resolvedBackend = _resolveBackendForExtras(extras);
    final inferredServerType = _serverTypeForExtras(extras);
    final inferredBackendType = inferredServerType == null ||
            inferredServerType == ServerType.youtubeMusic
        ? null
        : inferredServerType.name;
    final backendType =
        extras?['backendType']?.toString() ?? inferredBackendType;
    final isNonYouTubeBackend = inferredServerType != null &&
        inferredServerType != ServerType.youtubeMusic;
    _diag.logEvent(
      category: 'stream_fetch',
      message: 'check_n_get_url_start',
      songId: songId,
      backendType: backendType,
      activeServerType: _safeServerType(),
      data: {
        'generateNewUrl': generateNewUrl,
        'offlineReplacementUrl': offlineReplacementUrl,
      },
    );
    printINFO("Requested id : $songId");
    if (isNonYouTubeBackend) {
      try {
        final isPlex = inferredServerType == ServerType.plex;
        final existingUrl = extras?['url']?.toString();
        String? url;
        if (!isPlex &&
            !generateNewUrl &&
            existingUrl != null &&
            existingUrl.isNotEmpty &&
            existingUrl.startsWith('http')) {
          _diag.logEvent(
            category: 'stream_fetch',
            message: 'using_existing_backend_url',
            songId: songId,
            backendType: backendType,
            activeServerType: _safeServerType(),
            data: {'url': PlaybackDiagnosticsService.sanitizeUrl(existingUrl)},
          );
          url = existingUrl;
        } else {
          url = await resolvedBackend.getStreamUrl(songId);
          if ((url == null || url.isEmpty) && isPlex) {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            url = await resolvedBackend.getStreamUrl(songId);
          }
        }
        if (url != null && url.isNotEmpty) {
          final audio = Audio(
              itag: 0,
              audioCodec: Codec.opus,
              bitrate: 0,
              duration: 0,
              loudnessDb: 0,
              url: url,
              size: 0);
          return HMStreamingData(
              playable: true,
              statusMSG: 'OK',
              highQualityAudio: audio,
              lowQualityAudio: audio);
        }
      } catch (e) {
        logPlaybackDebugError('checkNGetUrl($songId)', e);
        _diag.logEvent(
          category: 'stream_fetch',
          message: 'backend_stream_url_failed',
          songId: songId,
          backendType: backendType,
          activeServerType: _safeServerType(),
          data: {'error': e.toString()},
        );
        return HMStreamingData(playable: false, statusMSG: e.toString());
      }
    }
    final songDownloadsBox = Hive.box(songDownloadsBoxName(currentServerId()));
    if (!offlineReplacementUrl &&
        (await Hive.openBox(songsCacheBoxName(currentServerId()))).containsKey(songId)) {
      _diag.logEvent(
        category: 'stream_fetch',
        message: 'hit_songs_cache',
        songId: songId,
        backendType: backendType,
        activeServerType: _safeServerType(),
      );
      printINFO("Got Song from cachedbox ($songId)");
      // if contains stream Info
      final streamInfo = Hive.box(songsCacheBoxName(currentServerId())).get(songId)["streamInfo"];
      Audio? cacheAudioPlaceholder;
      if (streamInfo != null && streamInfo.isNotEmpty) {
        streamInfo[1]['url'] = "file://$_cacheDir/cachedSongs/$songId.mp3";
        cacheAudioPlaceholder = Audio.fromJson(streamInfo[1]);
      } else {
        cacheAudioPlaceholder = Audio(
            audioCodec: Codec.mp4a,
            bitrate: 0,
            loudnessDb: 0,
            duration: 0,
            size: 0,
            url: "file://$_cacheDir/cachedSongs/$songId.mp3",
            itag: 0);
      }

      return HMStreamingData(
          playable: true,
          statusMSG: "OK",
          lowQualityAudio: cacheAudioPlaceholder,
          highQualityAudio: cacheAudioPlaceholder);
    } else if (!offlineReplacementUrl && songDownloadsBox.containsKey(songId)) {
      _diag.logEvent(
        category: 'stream_fetch',
        message: 'hit_downloads_box',
        songId: songId,
        backendType: backendType,
        activeServerType: _safeServerType(),
      );
      final song = songDownloadsBox.get(songId);
      final streamInfoJson = song["streamInfo"];
      Audio? audio;
      final dynamic rawPath = song['url'] ??
          (song['extras'] != null ? song['extras']['url'] : null);
      if (rawPath is! String || rawPath.isEmpty) {
        _diag.logEvent(
          category: 'stream_fetch',
          message: 'downloaded_path_missing_fallback_online',
          songId: songId,
          backendType: backendType,
          activeServerType: _safeServerType(),
        );
        return checkNGetUrl(songId, offlineReplacementUrl: true);
      }
      final path = rawPath;
      if (streamInfoJson != null && streamInfoJson.isNotEmpty) {
        streamInfoJson[1]['url'] = "file://$path";
        audio = Audio.fromJson(streamInfoJson[1]);
      } else {
        audio = Audio(
            itag: 140,
            audioCodec: Codec.mp4a,
            bitrate: 0,
            duration: 0,
            loudnessDb: 0,
            url: "file://$path",
            size: 0);
      }

      final streamInfo = HMStreamingData(
          playable: true,
          statusMSG: "OK",
          highQualityAudio: audio,
          lowQualityAudio: audio);

      if (path.contains(
          "${Get.find<SettingsScreenController>().supportDirPath}/Music")) {
        return streamInfo;
      }
      //check file access and if file exist in storage
      final status = await PermissionService.getExtStoragePermission();
      if (status && await File(path).exists()) {
        return streamInfo;
      }
      _diag.logEvent(
        category: 'stream_fetch',
        message: 'downloaded_file_missing_fallback_online',
        songId: songId,
        backendType: backendType,
        activeServerType: _safeServerType(),
      );
      //in case file doesnot found in storage, song will be played online
      return checkNGetUrl(songId, offlineReplacementUrl: true);
    } else {
      //check if song stream url is cached and allocate url accordingly
      final songsUrlCacheBox = await Hive.openBox(songsUrlCacheBoxName(currentServerId()));
      final qualityIndex = Hive.box('AppPrefs').get('streamingQuality') ?? 1;
      HMStreamingData? streamInfo;
      if (songsUrlCacheBox.containsKey(songId) && !generateNewUrl) {
        final streamInfoJson = songsUrlCacheBox.get(songId);
        if (streamInfoJson.runtimeType.toString().contains("Map") &&
            !isExpired(url: (streamInfoJson['lowQualityAudio']['url']))) {
          _diag.logEvent(
            category: 'stream_fetch',
            message: 'hit_url_cache',
            songId: songId,
            backendType: backendType,
            activeServerType: _safeServerType(),
          );
          printINFO("Got cached Url ($songId)");
          streamInfo = HMStreamingData.fromJson(streamInfoJson);
        }
      }

      if (streamInfo == null) {
        _diag.logEvent(
          category: 'stream_fetch',
          message: 'fetching_stream_info',
          songId: songId,
          backendType: backendType,
          activeServerType: _safeServerType(),
        );
        final startedAt = DateTime.now();
        final token = RootIsolateToken.instance;
        final streamInfoJson =
            await Isolate.run(() => getStreamInfo(songId, token));
        streamInfo = HMStreamingData.fromJson(streamInfoJson);
        _diag.logEvent(
          category: 'stream_fetch',
          message: 'fetched_stream_info',
          songId: songId,
          backendType: backendType,
          activeServerType: _safeServerType(),
          data: {
            'playable': streamInfo.playable,
            'status': streamInfo.statusMSG,
            'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
          },
        );
        if (streamInfo.playable) songsUrlCacheBox.put(songId, streamInfoJson);
      }

      streamInfo.setQualityIndex(qualityIndex as int);
      return streamInfo;
    }
  }

  dynamic _resolveBackendForExtras(Map<String, dynamic>? extras) {
    final settings = Get.find<SettingsScreenController>();
    final rawServerId = extras?['serverId'];
    int? serverId;
    if (rawServerId is int) {
      serverId = rawServerId;
    } else if (rawServerId is String) {
      serverId = int.tryParse(rawServerId);
    }
    if (serverId != null) {
      for (final server in settings.servers) {
        if (server.id == serverId) {
          return createBackend(server);
        }
      }
    }
    return settings.currentBackend;
  }

  ServerType? _serverTypeForExtras(Map<String, dynamic>? extras) {
    // YouTube Music is the default backend and never tags its songs with a
    // serverId. Only resolve a server type when the song explicitly carries
    // one, otherwise fall back to YouTube Music so untagged songs aren't
    // misrouted through whatever non-YouTube server happens to be active.
    final settings = Get.find<SettingsScreenController>();
    final rawServerId = extras?['serverId'];
    int? serverId;
    if (rawServerId is int) {
      serverId = rawServerId;
    } else if (rawServerId is String) {
      serverId = int.tryParse(rawServerId);
    }
    if (serverId != null) {
      for (final server in settings.servers) {
        if (server.id == serverId) return server.type;
      }
    }
    return null;
  }

  String? _safeCurrentSongId() {
    try {
      if (currentIndex == null) return null;
      if (queue.value.isEmpty) return null;
      final idx = (currentIndex as int).clamp(0, queue.value.length - 1);
      return queue.value[idx].id;
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=audio.safeCurrentSongId] Failed to resolve current song id: $e\n$st');
      return null;
    }
  }

  String? _safeBackendType() {
    try {
      final songId = _safeCurrentSongId();
      if (songId == null) return null;
      final item = queue.value.firstWhereOrNull((e) => e.id == songId);
      return item?.extras?['backendType']?.toString();
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=audio.safeBackendType] Failed to resolve backend type: $e\n$st');
      return null;
    }
  }

  String? _safeServerType() {
    try {
      final settings = Get.find<SettingsScreenController>();
      return settings.activeServer?.type.name;
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=audio.safeServerType] Failed to resolve active server type: $e\n$st');
      return null;
    }
  }
}

class UrlError extends Error {
  String message() => 'Unable to fetch url';
}

/// One queued recovery attempt for a platform player failure. Captures the
/// context at the moment the error arrived so the serialized recovery loop
/// can still abort when playback state moved on in the meantime.
class _PendingPlayerRecovery {
  _PendingPlayerRecovery({
    required this.error,
    required this.resumePosition,
    required this.resumeSameSource,
    required this.songId,
    required this.requestId,
  });

  final Object error;
  final Duration resumePosition;
  final bool resumeSameSource;
  final String? songId;
  final int requestId;
}

// for Android Auto
