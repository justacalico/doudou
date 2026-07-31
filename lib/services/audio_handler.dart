import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '/l10n/app_localizations.dart';
import '/ui/screens/Library/library_controller.dart';
import 'dart:math';

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
import '/services/playback_transition_utils.dart';
import '../utils/helper.dart';
import '../utils/server_storage.dart';
import '/models/media_Item_builder.dart';
import '/services/utils.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
// ignore: unused_import, implementation_imports, depend_on_referenced_packages
import "package:media_kit/src/player/platform_player.dart" show MPVLogLevel;

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
  late AudioPlayer _player;
  late MediaLibrary _mediaLibrary;
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

  final _playList =
      ConcatenatingAudioSource(children: [], useLazyPreparation: false);

  PlaybackDiagnosticsService get _diag =>
      Get.find<PlaybackDiagnosticsService>();

  MyAudioHandler() {
    if (GetPlatform.isWindows || GetPlatform.isLinux) {
      JustAudioMediaKit.title = 'Doudou';
      JustAudioMediaKit.protocolWhitelist = const ['http', 'https', 'file'];
    }
    _mediaLibrary = MediaLibrary();
    _player = AudioPlayer(
        audioLoadConfiguration: const AudioLoadConfiguration(
            androidLoadControl: AndroidLoadControl(
      minBufferDuration: Duration(seconds: 50),
      maxBufferDuration: Duration(seconds: 120),
      bufferForPlaybackDuration: Duration(milliseconds: 50),
      bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
    )));
    _createCacheDir();
    _addEmptyList();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPlaybackForNextSong();
    _listenForSequenceStateChanges();
    final appPrefsBox = Hive.box("AppPrefs");
    _player
        .setSkipSilenceEnabled(appPrefsBox.get("skipSilenceEnabled") ?? false);
    loopModeEnabled = appPrefsBox.get("isLoopModeEnabled") ?? false;
    shuffleModeEnabled = appPrefsBox.get("isShuffleModeEnabled") ?? false;
    queueLoopModeEnabled =
        Hive.box("AppPrefs").get("queueLoopModeEnabled") ?? false;
    loudnessNormalizationEnabled =
        appPrefsBox.get("loudnessNormalizationEnabled") ?? false;
    _listenForDurationChanges();
    if (GetPlatform.isAndroid) {
      _listenSessionIdStream();
    }
  }

  Future<void> _createCacheDir() async {
    _cacheDir = (await getTemporaryDirectory()).path;
    if (!Directory("$_cacheDir/cachedSongs/").existsSync()) {
      Directory("$_cacheDir/cachedSongs/").createSync(recursive: true);
    }
  }

  void _addEmptyList() {
    try {
      _player.setAudioSource(_playList);
    } catch (r) {
      printERROR(r.toString());
    }
  }

  void _listenSessionIdStream() {
    _player.androidAudioSessionIdStream.listen((int? id) {
      if (id != null) {
        try {
          EqualizerService.initAudioEffect(id);
        } catch (e, st) {
          printERROR('Equalizer init failed: $e\n$st');
        }
      }
    });
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
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      _syncPlaybackWakeLock(playing);
      if (_lastLoggedProcessingState != _player.processingState) {
        _lastLoggedProcessingState = _player.processingState;
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
    }, onError: (Object e, StackTrace st) async {
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
        Duration curPos = _player.position;
        await _player.stop();

        if (isPlayingUsingLockCachingSource &&
            e.toString().contains("Connection closed while receiving data")) {
          _diag.logEvent(
            category: 'recovery',
            message: 'retry_current_from_cache_source',
            songId: _safeCurrentSongId(),
            backendType: _safeBackendType(),
            activeServerType: _safeServerType(),
            data: {'positionMs': curPos.inMilliseconds},
          );
          await _player.seek(curPos, index: 0);
          await _player.play();
          return;
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
        _diag.logEvent(
          category: 'recovery',
          message: 'force_new_url_for_current_song',
          songId: _safeCurrentSongId(),
          backendType: _safeBackendType(),
          activeServerType: _safeServerType(),
          data: {'positionMs': curPos.inMilliseconds},
        );
        customAction("playByIndex", {'index': currentIndex, 'newUrl': true});
        await _player.seek(curPos, index: 0);
      }
    });
  }

  void _listenToPlaybackForNextSong() {
    final playerDurationOffset = autoAdvanceLeadMsForPlatform(
      isWindows: GetPlatform.isWindows,
      isLinux: GetPlatform.isLinux,
      isIOS: GetPlatform.isIOS,
    );
    _player.positionStream.listen((value) async {
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
    });
  }

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
    _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) async {
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
        final rawOriginalMs = currentSong.extras?['originalDurationMs'];
        int? originalMs = rawOriginalMs is int ? rawOriginalMs : null;
        if (Platform.isIOS || Platform.isMacOS) {
          if (originalMs == null || originalMs <= 0) {
            if (currentSong.duration != null &&
                currentSong.duration!.inMilliseconds > 0) {
              originalMs = currentSong.duration!.inMilliseconds;
              newExtras ??= {};
              newExtras['originalDurationMs'] = originalMs;
            }
          }
          if (originalMs != null &&
              originalMs > 0 &&
              newExtras != null &&
              !newExtras.containsKey('originalDurationMs')) {
            newExtras['originalDurationMs'] = originalMs;
          }
        }
        final effectiveDuration = resolveEffectiveTrackDuration(
          playerDuration: duration,
          mediaDuration: currentSong.duration,
          originalDurationMs: originalMs,
        );
        if (effectiveDuration == null) return;
        final newMediaItem = currentSong.copyWith(
          duration: effectiveDuration,
          extras: newExtras ?? currentSong.extras,
        );
        mediaItem.add(newMediaItem);
      }
    });
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
      tag: mediaItem,
    );
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
        await _player.dispose();
        super.stop();
        break;

      case 'playByIndex':
        final songIndex = extras!['index'] as int;
        final requestId = _startPlayRequest();
        _autoAdvanceGuard.reset();
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
        final songToAdd = activeSong.duration != null
            ? activeSong.copyWith(
                extras: {
                  ...?activeSong.extras,
                  'originalDurationMs': activeSong.duration!.inMilliseconds,
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
        await _playList.add(_createAudioSource(activeSong));

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
            jsonData['duration'] = _player.duration!.inSeconds;
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
        queue.add([currMed]);
        mediaItem.add(currMed);
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
        await _playList.add(_createAudioSource(currMed));
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
      final ctx = Get.context;
      final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
      await Get.find<HomeScreenController>().shuffleAll(
        emptyMessage: l10n?.noSongsInLibrary ?? 'No songs in library',
        playFromName: l10n?.shuffleAll ?? 'Shuffle all',
      );
      return;
    }
    if (mediaId == MediaLibrary.moreFavoritesId) {
      final ctx = Get.context;
      final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
      await Get.find<HomeScreenController>().shuffleFavorites(
        emptyMessage: l10n?.favoritesEmpty ?? 'Favourites is empty',
        playFromName: l10n?.favorites ?? 'Favourites',
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

// for Android Auto
class MediaLibrary {
  static const albumsRootId = 'albums';
  static const songsRootId = 'songs';
  static const favoritesRootId = "LIBFAV";
  static const playlistsRootId = 'playlists';
  static const recentlyPlayedRootId = 'recentlyPlayed';

  static const homeRootId = 'home';
  static const moreRootId = 'more';
  static const morePlaylistsId = 'more_playlists';
  static const moreShuffleAllId = 'more_shuffleAll';
  static const moreFavoritesId = 'more_favorites';
  static const moreSettingsId = 'more_settings';
  static const moreSettingsServersId = 'more_settings_servers';
  static const moreSettingsAboutId = 'more_settings_about';

  // Track the last browsed album/playlist so playFromMediaId knows
  // which song list to queue up
  String _lastBrowseId = '';

  Future<List<MediaItem>> getByRootId(String id) async {
    printINFO('MediaLibrary: getByRootId "$id"');
    switch (id) {
      case AudioService.browsableRootId:
        return Future.value(getRoot());
      case homeRootId:
        _lastBrowseId = homeRootId;
        return getHomeItems();
      case songsRootId:
        _lastBrowseId = songsRootId;
        return getSongs();
      case favoritesRootId:
        _lastBrowseId = favoritesRootId;
        return getLibSongs(libFavBoxName(currentServerId()));
      case albumsRootId:
        _lastBrowseId = albumsRootId;
        return getAlbums();
      case moreRootId:
        return getMoreMenu();
      case morePlaylistsId:
        _lastBrowseId = morePlaylistsId;
        return getPlaylists();
      case moreSettingsId:
        return getSettingsMenu();
      case moreSettingsServersId:
        return getServersList();
      case moreSettingsAboutId:
        return getAboutInfo();
      case playlistsRootId:
        _lastBrowseId = playlistsRootId;
        return getPlaylists();
      case recentlyPlayedRootId:
        _lastBrowseId = recentlyPlayedRootId;
        return getLibSongs(recentlyPlayedBoxName(currentServerId()));
      case AudioService.recentRootId:
        _lastBrowseId = recentlyPlayedRootId;
        return getLibSongs(recentlyPlayedBoxName(currentServerId()));
      default:
        // Browsing into a specific album/playlist — track it
        _lastBrowseId = id;
        return getLibSongs(id).then((songs) async {
          if (songs.isNotEmpty) return songs;
          return _fetchFromBackend(id);
        });
    }
  }

  List<MediaItem> getRoot() {
    final ctx = Get.context;
    if (ctx == null) {
      return [
        const MediaItem(id: homeRootId, title: 'Home', playable: false),
        const MediaItem(id: albumsRootId, title: 'Albums', playable: false),
        const MediaItem(id: moreRootId, title: 'More', playable: false),
      ];
    }
    final l10n = AppLocalizations.of(ctx)!;
    return [
      MediaItem(id: homeRootId, title: l10n.home, playable: false),
      MediaItem(id: albumsRootId, title: l10n.albums, playable: false),
      MediaItem(id: moreRootId, title: l10n.more, playable: false),
    ];
  }

  /// More menu — shows Shuffle All, Favorites, Playlists, and Settings
  List<MediaItem> getMoreMenu() {
    final ctx = Get.context;
    final l10n = ctx != null ? AppLocalizations.of(ctx)! : null;
    return [
      MediaItem(
        id: moreShuffleAllId,
        title: l10n?.shuffleAll ?? 'Shuffle all',
        playable: true,
      ),
      MediaItem(
        id: moreFavoritesId,
        title: l10n?.favorites ?? 'Favourites',
        playable: true,
      ),
      MediaItem(
        id: morePlaylistsId,
        title: l10n?.playlists ?? 'Playlists',
        playable: false,
      ),
      MediaItem(
        id: moreSettingsId,
        title: l10n?.settings ?? 'Settings',
        playable: false,
      ),
    ];
  }

  /// Settings submenu — Servers and About
  List<MediaItem> getSettingsMenu() {
    final ctx = Get.context;
    final l10n = ctx != null ? AppLocalizations.of(ctx)! : null;
    return [
      MediaItem(
        id: moreSettingsServersId,
        title: l10n?.servers ?? 'Servers',
        playable: false,
      ),
      MediaItem(
        id: moreSettingsAboutId,
        title: l10n?.about ?? 'About',
        playable: false,
      ),
    ];
  }

  /// Servers list — allows switching active server (read-only, no add/edit/remove)
  List<MediaItem> getServersList() {
    final settings = Get.find<SettingsScreenController>();
    final activeId = settings.activeServerId.value;
    return settings.servers.map((s) {
      final isActive = s.id == activeId;
      final title = isActive ? '${s.name} ✓' : s.name;
      final subtitle = s.serverUrl ?? s.type.name;
      return MediaItem(
        id: 'server_switch_${s.id}',
        title: title,
        artist: subtitle,
        playable: true,
      );
    }).toList();
  }

  /// About info — pulled from SettingsScreenController
  List<MediaItem> getAboutInfo() {
    final settings = Get.find<SettingsScreenController>();
    final activeServer = settings.activeServer;
    final ctx = Get.context;
    final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
    return [
      MediaItem(
        id: 'about_app_name',
        title: 'Doudou',
        artist: 'v${settings.currentVersion}',
        playable: true,
      ),
      MediaItem(
        id: 'about_active_server',
        title: l10n?.servers ?? 'Servers',
        artist: activeServer?.name ?? 'None',
        playable: true,
      ),
      MediaItem(
        id: 'about_server_type',
        title: 'Server type',
        artist: activeServer?.type.name ?? 'Unknown',
        playable: true,
      ),
    ];
  }

  /// Pull home items from HomeScreenController — aggregates quick picks,
  /// continue listening, fresh picks, and based-on-favorites, same as
  /// the app's home screen.
  Future<List<MediaItem>> getHomeItems() async {
    try {
      if (Get.isRegistered<HomeScreenController>()) {
        final homeCtrl = Get.find<HomeScreenController>();
        for (int i = 0; i < 20; i++) {
          if (homeCtrl.isContentFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final allSongs = <MediaItem>[];

        // 1. Quick picks (discover content from backend)
        final quickPicks = homeCtrl.quickPicks.value.songList;
        printINFO('MediaLibrary: getHomeItems quick picks: ${quickPicks.length}');
        allSongs.addAll(quickPicks);

        // 2. Home library sections
        try {
          final sections = await homeCtrl.loadHomeLibrarySections();
          printINFO('MediaLibrary: getHomeItems sections - continueListening=${sections.continueListening.length}, freshPicks=${sections.freshPicks.length}, basedOnFavorites=${sections.basedOnFavorites.length}');

          // Skip continueListening (recently played) — too much space in car UI
          for (final item in sections.freshPicks) {
            if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
          }
          for (final item in sections.basedOnFavorites) {
            if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
          }
          for (final item in sections.favoriteSongs) {
            if (!allSongs.any((s) => s.id == item.id)) allSongs.add(item);
          }
        } catch (e) {
          printWarning('MediaLibrary: getHomeItems sections failed: $e');
        }

        printINFO('MediaLibrary: getHomeItems total: ${allSongs.length}');
        if (allSongs.isNotEmpty) {
          return allSongs.map((s) => MediaItem(
            id: s.id,
            title: s.title,
            artist: s.artist,
            artUri: s.artUri,
            extras: {'libraryId': songDownloadsBoxName(currentServerId())},
            playable: true,
          )).toList();
        }
      }
    } catch (e) {
      printWarning('MediaLibrary: getHomeItems failed: $e');
    }
    // Fallback to songs
    return getSongs();
  }

  /// Pull songs from LibrarySongsController's in-memory list —
  /// this has both backend-fetched and local songs merged together.
  Future<List<MediaItem>> getSongs() async {
    try {
      if (Get.isRegistered<LibrarySongsController>()) {
        final ctrl = Get.find<LibrarySongsController>();
        // Wait for fetch to complete (up to 10s)
        for (int i = 0; i < 20; i++) {
          if (ctrl.isSongFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        final songs = ctrl.librarySongsList.toList();
        printINFO('MediaLibrary: getSongs from controller: ${songs.length}');
        return songs.map((s) => MediaItem(
          id: s.id,
          title: s.title,
          artist: s.artist,
          artUri: s.artUri,
          extras: {'libraryId': songDownloadsBoxName(currentServerId())},
          playable: true,
        )).toList();
      }
    } catch (e) {
      printWarning('MediaLibrary: getSongs from controller failed: $e');
    }
    // Fallback to Hive box
    return getLibSongs(songDownloadsBoxName(currentServerId()));
  }

  Future<List<MediaItem>> getAlbums() async {
    try {
      if (Get.isRegistered<LibraryAlbumsController>()) {
        final ctrl = Get.find<LibraryAlbumsController>();
        for (int i = 0; i < 20; i++) {
          if (ctrl.isContentFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        final albums = ctrl.libraryAlbums.toList();
        printINFO('MediaLibrary: getAlbums from controller: ${albums.length}');
        return albums.map((a) => a.toMediaItem()).toList();
      }
    } catch (e) {
      printWarning('MediaLibrary: getAlbums from controller failed: $e');
    }
    // Fallback to Hive box
    final box = await Hive.openBox(libraryAlbumsBoxName(currentServerId()));
    final albums =
        box.values.map((item) => Album.fromJson(item).toMediaItem()).toList();
    printINFO('MediaLibrary: getAlbums from box: ${albums.length}');
    return albums;
  }

  Future<List<MediaItem>> getPlaylists() async {
    try {
      if (Get.isRegistered<LibraryPlaylistsController>()) {
        final ctrl = Get.find<LibraryPlaylistsController>();
        for (int i = 0; i < 20; i++) {
          if (ctrl.isContentFetched.value) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        // Filter out LIBFAV — Favorites has its own button in the More menu
        final playlists = ctrl.libraryPlaylists
            .where((p) => p.playlistId != 'LIBFAV')
            .toList();
        printINFO('MediaLibrary: getPlaylists from controller: ${playlists.length}');
        return playlists.map((p) => p.toMediaItem()).toList();
      }
    } catch (e) {
      printWarning('MediaLibrary: getPlaylists from controller failed: $e');
    }
    // Fallback to Hive box
    final box = await Hive.openBox("LibraryPlaylists");
    final prefix = 's_${currentServerId()}_';
    final serverKeys = box.keys
        .where((k) => k is String && k.toString().startsWith(prefix))
        .toList();
    final playlists = [
      ...Get.find<LibraryPlaylistsController>()
          .initPlst
          .where((e) => e.playlistId != 'LIBFAV')
          .map((e) => e.toMediaItem()),
      ...serverKeys.map((k) => box.get(k.toString())).whereType<Map>().map(
          (item) =>
              Playlist.fromJson(Map<dynamic, dynamic>.from(item)).toMediaItem())
    ];
    printINFO('MediaLibrary: getPlaylists from box: ${playlists.length}');
    return playlists;
  }

  Future<List<MediaItem>> getLibSongs(String libId) async {
    Box<dynamic> box;
    try {
      box = await Hive.openBox(libId);
    } catch (e) {
      box = await Hive.openBox(libId);
    }
    final songs = box.values.toList().map((e) {
      final song = MediaItemBuilder.fromJson(e);
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artUri: song.artUri,
        extras: {"libraryId": libId},
        playable: true,
      );
    }).toList();

    // Don't close — boxes are shared with library controllers

    if (libId == "LIBRP" || libId.startsWith("LIBRP_s_")) {
      return songs.reversed.toList();
    }

    printINFO('MediaLibrary: getLibSongs from $libId: ${songs.length}');
    return songs;
  }

  /// Fetch album/playlist songs from backend when not cached locally
  Future<List<MediaItem>> _fetchFromBackend(String id) async {
    try {
      final settings = Get.find<SettingsScreenController>();
      final backend = settings.currentBackend;
      final result = await backend.getPlaylistOrAlbumSongs(
        albumId: id,
        playlistId: id,
      );
      final tracks = (result['tracks'] as List?) ?? [];
      final songs = tracks
          .map((item) => MediaItemBuilder.fromJson(item))
          .whereType<MediaItem>()
          .map((song) => MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            artUri: song.artUri,
            extras: {'libraryId': id},
            playable: true,
          ))
          .toList();
      printINFO('MediaLibrary: _fetchFromBackend for $id: ${songs.length}');
      return songs;
    } catch (e) {
      printWarning('MediaLibrary: _fetchFromBackend failed for $id: $e');
      return [];
    }
  }
}
