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
import '../models/playlist.dart';
import '/services/equalizer.dart';
import '/services/stream_service.dart';
import '/models/hm_streaming_data.dart';
import '/ui/player/player_controller.dart';
import '../ui/screens/Home/home_screen_controller.dart';
import '/services/background_task.dart';
import '/services/permission_service.dart';
import '/services/backend/backend_factory.dart';
import '/services/playback_diagnostics_service.dart';
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
  // ignore: prefer_typing_uninitialized_variables
  dynamic currentIndex;
  int currentShuffleIndex = 0;
  late String? currentSongUrl;
  bool isPlayingUsingLockCachingSource = false;
  bool loopModeEnabled = false;
  bool queueLoopModeEnabled = false;
  bool shuffleModeEnabled = false;
  bool loudnessNormalizationEnabled = false;
  // var networkErrorPause = false;
  bool isSongLoading = true;
  ProcessingState? _lastLoggedProcessingState;

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

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
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
    final playerDurationOffset = GetPlatform.isWindows
        ? 200
        : GetPlatform.isLinux
            ? 700
            : GetPlatform.isIOS
                ? 500
                : 0;
    _player.positionStream.listen((value) async {
      if (_player.duration != null && _player.duration?.inSeconds != 0) {
        if (value.inMilliseconds >=
            (_player.duration!.inMilliseconds - playerDurationOffset)) {
          await _triggerNext();
        }
      }
    });
  }

  Future<void> _triggerNext() async {
    if (loopModeEnabled) {
      await _player.seek(Duration.zero);
      if (!_player.playing) {
        _player.play();
      }
      return;
    }
    skipToNext();
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
      if (currentIndex == null || currQueue.isEmpty || duration == null) return;
      final currentSong = queue.value[currentIndex];
      final usePlayerDuration = GetPlatform.isIOS ||
          currentSong.duration == null ||
          currentIndex == 0;
      if (usePlayerDuration && duration.inSeconds > 0) {
        Duration effectiveDuration = duration;
        Map<String, dynamic>? newExtras = currentSong.extras != null
            ? Map<String, dynamic>.from(currentSong.extras!)
            : null;
        if (GetPlatform.isIOS) {
          final raw = currentSong.extras?['originalDurationMs'];
          int? originalMs = raw is int ? raw : null;
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
          if (originalMs != null && originalMs > 0) {
            final playerMs = duration.inMilliseconds;
            if (playerMs >= (originalMs * 1.8).round() &&
                playerMs <= (originalMs * 2.2).round()) {
              effectiveDuration = Duration(milliseconds: originalMs);
            }
          }
        }
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
    if (currentSongUrl == null ||
        (GetPlatform.isDesktop &&
            (_player.duration == null ||
                _player.duration?.inMilliseconds == 0))) {
      await customAction("playByIndex", {'index': currentIndex});
      return;
    }
    // Workaround for network error pause in case of PlayingUsingLockCachingSource
    // if (isPlayingUsingLockCachingSource && networkErrorPause) {
    //   await _player.play();
    //   Future.delayed(const Duration(seconds: 2)).then((value) {
    //     if (_player.playing) {
    //       networkErrorPause = false;
    //     }
    //   });
    //   await _player.play();
    //   return;
    // }
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
      _player.seek(Duration.zero);
      _player.pause();
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
        await _player.dispose();
        super.stop();
        break;

      case 'playByIndex':
        final songIndex = extras!['index'];
        currentIndex = songIndex;
        final isNewUrlReq = extras['newUrl'] ?? false;
        final currentSong = queue.value[currentIndex];
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
        if (_playList.children.isNotEmpty) {
          await _playList.clear();
        }

        final songToAdd = currentSong.duration != null
            ? currentSong.copyWith(
                extras: {
                  ...?currentSong.extras,
                  'originalDurationMs': currentSong.duration!.inMilliseconds,
                },
              )
            : currentSong;
        mediaItem.add(songToAdd);
        final streamInfo = await futureStreamInfo;
        if (songIndex != currentIndex) {
          _diag.logEvent(
            category: 'player_event',
            message: 'play_by_index_aborted_index_changed',
            songId: currentSong.id,
            backendType: currentSong.extras?['backendType']?.toString(),
            activeServerType: _safeServerType(),
            data: {'requestedIndex': songIndex, 'activeIndex': currentIndex},
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
        currentSongUrl = currentSong.extras!['url'] = streamInfo.audio!.url;
        _diag.logEvent(
          category: 'stream_select',
          message: 'stream_selected',
          songId: currentSong.id,
          backendType: currentSong.extras?['backendType']?.toString(),
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
        playbackState
            .add(playbackState.value.copyWith(queueIndex: currentIndex));
        await _playList.add(_createAudioSource(currentSong));

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
          await _player.play();
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
          final songsCacheBox = Hive.box("SongsCache");
          if (!songsCacheBox.containsKey(song.id) &&
              await File("$_cacheDir/cachedSongs/${song.id}.mp3").exists()) {
            song.extras!['url'] = currentSongUrl;
            song.extras!['date'] = DateTime.now().millisecondsSinceEpoch;
            final dbStreamData = Hive.box("SongsUrlCache").get(song.id);
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
        await _playList.clear();
        mediaItem.add(currMed);
        queue.add([currMed]);
        final streamInfo = (await futureStreamInfo);
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

        await _playList.add(_createAudioSource(currMed));
        isSongLoading = false;

        // Normalize audio
        if (loudnessNormalizationEnabled && GetPlatform.isAndroid) {
          _normalizeVolume(streamInfo.audio!.loudnessDb);
        }

        await _player.play();
        break;

      case 'toggleSkipSilence':
        final enable = (extras!['enable'] as bool);
        await _player.setSkipSilenceEnabled(enable);
        break;

      case 'toggleLoudnessNormalization':
        loudnessNormalizationEnabled = (extras!['enable'] as bool);
        if (!loudnessNormalizationEnabled) {
          _player.setVolume(1.0);
          return;
        }

        if (loudnessNormalizationEnabled) {
          try {
            final currentSongId = (queue.value[currentIndex]).id;
            if (Hive.box("SongsUrlCache").containsKey(currentSongId)) {
              final songJson = Hive.box("SongsUrlCache").get(currentSongId);
              _normalizeVolume((songJson)["highQualityAudio"]["loudnessDb"]);
              return;
            }

            if (Hive.box("SongDownloads").containsKey(currentSongId)) {
              final streamInfo =
                  (Hive.box("SongDownloads").get(currentSongId))["streamInfo"];

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
        final oldIndex = extras!['oldIndex'];
        int newIndex = extras['newIndex'];

        if (oldIndex < newIndex) {
          newIndex--;
        }

        final currentQueue = queue.value;
        final currentItem = currentQueue[currentIndex];
        final item = currentQueue.removeAt(
          oldIndex,
        );
        currentQueue.insert(newIndex, item);
        currentIndex = currentQueue.indexOf(currentItem);
        queue.add(currentQueue);
        mediaItem.add(currentItem);
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
        _player.setVolume(extras!['value'] / 100);
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
        customAction("reorderQueue", {'oldIndex': currentIndex, 'newIndex': 0});
        final newQueue = queue.value;
        newQueue.removeRange(1, newQueue.length);
        queue.add(newQueue);
        originalQueue = newQueue.toList();
        if (shuffleModeEnabled) {
          shuffledQueue.clear();
          shuffledQueue.add(newQueue[0].id);
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
    // We use a factor to convert dB difference to a linear scale
    // 10^(difference / 20) converts dB difference to a linear volume factor
    final volumeAdjustment = pow(10.0, loudnessDifference / 20.0);
    printINFO(
        "loudness:$currentLoudnessDb Normalized volume: $volumeAdjustment");
    _player.setVolume(volumeAdjustment.toDouble().clamp(0, 1.0));
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
    customEvent.add({
      'eventType': 'playFromMediaId',
      'songId': mediaId,
      'libraryId': extras!['libraryId'],
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
    final backendType = extras?['backendType']?.toString();
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
    if (extras?['backendType'] == 'jellyfin' ||
        extras?['backendType'] == 'subsonic' ||
        extras?['backendType'] == 'plex') {
      try {
        final isPlex = extras?['backendType'] == 'plex';
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
          final backend = _resolveBackendForExtras(extras);
          url = await backend.getStreamUrl(songId);
          if ((url == null || url.isEmpty) && isPlex) {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            url = await backend.getStreamUrl(songId);
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
    final songDownloadsBox = Hive.box("SongDownloads");
    if (!offlineReplacementUrl &&
        (await Hive.openBox("SongsCache")).containsKey(songId)) {
      _diag.logEvent(
        category: 'stream_fetch',
        message: 'hit_songs_cache',
        songId: songId,
        backendType: backendType,
        activeServerType: _safeServerType(),
      );
      printINFO("Got Song from cachedbox ($songId)");
      // if contains stream Info
      final streamInfo = Hive.box("SongsCache").get(songId)["streamInfo"];
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
      final songsUrlCacheBox = Hive.box("SongsUrlCache");
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

  String? _safeCurrentSongId() {
    try {
      if (currentIndex == null) return null;
      if (queue.value.isEmpty) return null;
      final idx = (currentIndex as int).clamp(0, queue.value.length - 1);
      return queue.value[idx].id;
    } catch (_) {
      return null;
    }
  }

  String? _safeBackendType() {
    try {
      final songId = _safeCurrentSongId();
      if (songId == null) return null;
      final item = queue.value.firstWhereOrNull((e) => e.id == songId);
      return item?.extras?['backendType']?.toString();
    } catch (_) {
      return null;
    }
  }

  String? _safeServerType() {
    try {
      final settings = Get.find<SettingsScreenController>();
      return settings.activeServer?.type.name;
    } catch (_) {
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

  Future<List<MediaItem>> getByRootId(String id) async {
    switch (id) {
      case AudioService.browsableRootId:
        return Future.value(getRoot());
      case songsRootId:
        return getLibSongs("SongDownloads");
      case favoritesRootId:
        return getLibSongs(libFavBoxName(currentServerId()));
      case albumsRootId:
        return getAlbums();
      case playlistsRootId:
        return getPlaylists();
      case AudioService.recentRootId:
        return getLibSongs(recentlyPlayedBoxName(currentServerId()));
      default:
        return getLibSongs(id);
    }
  }

  List<MediaItem> getRoot() {
    final l10n = AppLocalizations.of(Get.context!)!;
    return [
      MediaItem(
        id: songsRootId,
        title: l10n.songs,
        playable: false,
      ),
      MediaItem(
        id: favoritesRootId,
        title: l10n.favorites,
        playable: false,
      ),
      MediaItem(
        id: albumsRootId,
        title: l10n.albums,
        playable: false,
      ),
      MediaItem(
        id: playlistsRootId,
        title: l10n.playlists,
        playable: false,
      ),
    ];
  }

  Future<List<MediaItem>> getAlbums() async {
    final box = await Hive.openBox(libraryAlbumsBoxName(currentServerId()));
    final albums =
        box.values.map((item) => Album.fromJson(item).toMediaItem()).toList();
    await box.close();
    return albums;
  }

  Future<List<MediaItem>> getPlaylists() async {
    final box = await Hive.openBox("LibraryPlaylists");
    final prefix = 's_${currentServerId()}_';
    final serverKeys = box.keys
        .where((k) => k is String && k.toString().startsWith(prefix))
        .toList();
    final playlists = [
      ...Get.find<LibraryPlaylistsController>()
          .initPlst
          .map((e) => e.toMediaItem()),
      ...serverKeys.map((k) => box.get(k.toString())).whereType<Map>().map(
          (item) =>
              Playlist.fromJson(Map<dynamic, dynamic>.from(item)).toMediaItem())
    ];
    await box.close();
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

    if (!libId.contains("SongDownloads")) {
      await box.close();
    }

    if (libId == "LIBRP" || libId.startsWith("LIBRP_s_")) {
      return songs.reversed.toList();
    }

    return songs;
  }
}
