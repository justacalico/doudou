import 'dart:async';
import 'dart:convert';
import '/l10n/app_localizations.dart';
import 'package:flutter_lyric/lyric_ui/ui_netease.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../../models/playling_from.dart';
import '../../services/downloader.dart';
import '../screens/Playlist/playlist_screen_controller.dart';
import '../widgets/snackbar.dart';
import '/services/synced_lyrics_service.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/navigator.dart';
import '/models/server.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/windows_audio_service.dart';
import '../../services/audio_handler.dart';
import '/services/discord_rpc_service.dart';
import '/services/playback_diagnostics_service.dart';
import '../../utils/helper.dart';
import '../../utils/server_storage.dart';
import '/models/media_Item_builder.dart';
import '../screens/Home/home_screen_controller.dart';
import '../screens/Library/library_controller.dart';
import '../widgets/sliding_up_panel.dart';
import '/models/durationstate.dart';
import '/services/music_service.dart';

class SyncedLyricLine {
  SyncedLyricLine({required this.timestamp, required this.text});
  final Duration timestamp;
  final String text;
}

class PlayerController extends GetxController
    with GetSingleTickerProviderStateMixin
    implements PlayerStateProvider {
  final _audioHandler = Get.find<AudioHandler>();
  final _musicServices = Get.find<MusicServices>();
  final _diag = Get.find<PlaybackDiagnosticsService>();
  final currentQueue = <MediaItem>[].obs;

  final playerPaneOpacity = (1.0).obs;
  final isPlayerpanelTopVisible = true.obs;
  final isPanelGTHOpened = false.obs;
  final playerPanelMinHeight = 0.0.obs;
  bool initFlagForPlayer = true;
  final isQueueReorderingInProcess = false.obs;
  PanelController playerPanelController = PanelController();
  PanelController queuePanelController = PanelController();
  AnimationController? gesturePlayerStateAnimationController;
  Animation<double>? gesturePlayerStateAnimation;
  bool isRadioModeOn = false;
  String? radioContinuationParam;
  dynamic radioInitiatorItem;
  bool _isAddingRadioContinuation = false;
  String? _lastContinuationParamUsed;
  Timer? sleepTimer;
  int timerDuration = 0;
  final timerDurationLeft = 0.obs;
  final isSleepTimerActive = false.obs;
  final isSleepEndOfSongActive = false.obs;
  final volume = 100.obs;
  static const int _minInternalAudibleVolume = 20;
  int _lastNonZeroVolume = 100;

  final progressBarStatus = ProgressBarState(
          buffered: Duration.zero, current: Duration.zero, total: Duration.zero)
      .obs;

  final currentSongIndex = (0).obs;
  final isFirstSong = true;
  final isLastSong = true;
  final isQueueLoopModeEnabled = false.obs;
  final isLoopModeEnabled = false.obs;
  final isShuffleModeEnabled = false.obs;
  final currentSong = Rxn<MediaItem>();
  final isCurrentSongFav = false.obs;
  final playinfrom = PlaylingFrom(type: PlaylingFromType.SELECTION).obs;
  final showLyricsflag = false.obs;
  final isLyricsLoading = false.obs;
  final lyricsMode = 0.obs;
  bool isDesktopLyricsDialogOpen = false;
  // 0 for play, 1 for pause, 2 for blank
  final gesturePlayerVisibleState = 2.obs;
  final lyricUi =
      UINetease(highlight: true, defaultSize: 20, defaultExtSize: 12);
  RxMap<String, dynamic> lyrics =
      <String, dynamic>{"synced": "", "plainLyrics": ""}.obs;
  ScrollController scrollController = ScrollController();
  final GlobalKey<ScaffoldState> homeScaffoldkey = GlobalKey<ScaffoldState>();

  final buttonState = PlayButtonState.paused.obs;

  // track whether wakelock is currently enabled to avoid repeated calls
  bool _wakelockActive = false;
  bool _wakelockUnavailable = false;
  bool _wakelockUnavailableLogged = false;

  var _newSongFlag = true;
  final isCurrentSongBuffered = false.obs;

  List<SyncedLyricLine> _syncedLyricLines = [];
  Color? _lastLyricsColor;
  bool _isTemporaryLyricAccentActive = false;

  List<SyncedLyricLine> get syncedLyricLines =>
      List<SyncedLyricLine>.unmodifiable(_syncedLyricLines);

  late StreamSubscription<bool> keyboardSubscription;

  @override
  onInit() {
    _init();
    super.onInit();
  }

  @override
  void onReady() {
    if (GetPlatform.isWindows) {
      Get.put(WindowsAudioService());
    }
    _restorePrevSession();
    super.onReady();
  }

  void _init() async {
    //_createAppDocDir();
    _listenForChangesInPlayerState();
    _listenForChangesInPosition();
    _listenForChangesInBufferedPosition();
    _listenForChangesInDuration();
    _listenForPlaylistChange();
    _listenForKeyboardActivity();
    _setInitLyricsMode();
    final appPrefs = Hive.box("AppPrefs");
    isLoopModeEnabled.value = appPrefs.get("isLoopModeEnabled") ?? false;
    isShuffleModeEnabled.value = appPrefs.get("isShuffleModeEnabled") ?? false;
    isQueueLoopModeEnabled.value =
        appPrefs.get("queueLoopModeEnabled") ?? false;

    if (GetPlatform.isDesktop) {
      setVolume(appPrefs.get("volume") ?? 100);
    }

    if ((appPrefs.get("playerUi") ?? 0) == 1) {
      initGesturePlayerStateAnimationController();
    }

    // only for android auto
    if (GetPlatform.isAndroid) {
      _listenForCustomEvents();
    }
  }

  void initGesturePlayerStateAnimationController() {
    gesturePlayerStateAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    gesturePlayerStateAnimation = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
            parent: gesturePlayerStateAnimationController!,
            curve: Curves.easeIn));
  }

  void _setInitLyricsMode() {
    lyricsMode.value = Hive.box("AppPrefs").get("lyricsMode") ?? 0;
  }

  void panellistener(double x) {
    if (x >= 0 && x <= 0.2) {
      playerPaneOpacity.value = 1 - (x * 5);
      isPlayerpanelTopVisible.value = true;
    } else if (x > 0.2) {
      isPlayerpanelTopVisible.value = false;
    }

    if (x > 0.6) {
      isPanelGTHOpened.value = true;
    } else {
      isPanelGTHOpened.value = false;
    }
  }

  void _listenForKeyboardActivity() {
    var keyboardVisibilityController = KeyboardVisibilityController();
    keyboardSubscription =
        keyboardVisibilityController.onChange.listen((bool visible) {
      visible ? playerPanelController.hide() : playerPanelController.show();
    });
  }

  void _listenForChangesInPlayerState() {
    _audioHandler.playbackState.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      if (processingState == AudioProcessingState.loading) {
        buttonState.value = PlayButtonState.loading;
      } else if (processingState == AudioProcessingState.buffering) {
        buttonState.value = PlayButtonState.loading;
      } else if (!isPlaying ||
          processingState == AudioProcessingState.error ||
          processingState == AudioProcessingState.completed) {
        buttonState.value = PlayButtonState.paused;
      } else {
        buttonState.value = PlayButtonState.playing;
      }

      final settings = Get.find<SettingsScreenController>();
      // Keep the screen awake whenever playback is active and the setting is enabled.
      final shouldEnable = settings.keepScreenAwake.isTrue && isPlaying;
      unawaited(_setWakelock(shouldEnable));
    });
  }

  Future<void> _setWakelock(bool enable) async {
    if (_wakelockUnavailable) {
      _wakelockActive = enable;
      return;
    }
    if (_wakelockActive == enable) return; // no-op if already in desired state

    try {
      if (enable) {
        printINFO("Enabling wakelock");
        await WakelockPlus.enable();
        _wakelockActive = true;
      } else {
        printINFO("Disabling wakelock");
        await WakelockPlus.disable();
        _wakelockActive = false;
      }
    } catch (e) {
      final err = e.toString();
      final isLinuxDbusUnavailable = GetPlatform.isLinux &&
          (err.contains('org.freedesktop.DBus.Error.ServiceUnknown') ||
              err.contains('name is not activatable'));
      if (isLinuxDbusUnavailable) {
        _wakelockUnavailable = true;
        _wakelockActive = enable;
        if (!_wakelockUnavailableLogged) {
          _wakelockUnavailableLogged = true;
          printERROR(
              "Wakelock unavailable on this Linux session (DBus ServiceUnknown); disabling wakelock attempts.");
        }
        return;
      }
      printERROR(e);
    }
  }

  void _listenForChangesInPosition() {
    AudioService.position.listen((position) {
      final oldState = progressBarStatus.value;
      if (isSleepEndOfSongActive.isTrue) {
        timerDurationLeft.value = oldState.total.inSeconds - position.inSeconds;
        if (timerDurationLeft.value == 1) {
          pause();
          cancelSleepTimer();
        }
      }
      final clampedCurrent =
          oldState.total.inMilliseconds > 0 && position > oldState.total
              ? oldState.total
              : position;
      progressBarStatus.update((val) {
        val!.current = clampedCurrent;
        val.buffered = oldState.buffered;
        val.total = oldState.total;
      });
      _updateDynamicColorFromLyrics(clampedCurrent);
    });
  }

  void _listenForChangesInBufferedPosition() {
    _audioHandler.playbackState.listen((playbackState) {
      final oldState = progressBarStatus.value;
      if (progressBarStatus.value.total.inSeconds != 0 &&
          playbackState.bufferedPosition.inSeconds /
                  progressBarStatus.value.total.inSeconds >=
              0.98) {
        if (_newSongFlag) {
          _audioHandler.customAction(
              "checkWithCacheDb", {'mediaItem': currentSong.value!});
          _newSongFlag = false;
        }
      }
      progressBarStatus.update((val) {
        val!.buffered = playbackState.bufferedPosition;
        val.current = oldState.current;
        val.total = oldState.total;
      });
    });
  }

  void _listenForChangesInDuration() {
    _audioHandler.mediaItem.listen((mediaItem) async {
      final oldState = progressBarStatus.value;
      progressBarStatus.update((val) {
        val!.total = mediaItem?.duration ?? Duration.zero;
        val.current = oldState.current;
        val.buffered = oldState.buffered;
      });
      if (mediaItem != null) {
        printINFO(mediaItem.title);
        _newSongFlag = true;
        isCurrentSongBuffered.value = false;
        currentSong.value = mediaItem;
        final queueIndex = _audioHandler.playbackState.value.queueIndex;
        if (queueIndex != null &&
            queueIndex >= 0 &&
            queueIndex < currentQueue.length) {
          currentSongIndex.value = queueIndex;
        } else {
          currentSongIndex.value = currentQueue
              .indexWhere((element) => element.id == currentSong.value!.id);
        }
        await _checkFav();
        await _addToRP(currentSong.value!);
        // Pre-fetch radio continuation when approaching end of queue.
        // Skip while the queue is still a single seed track — pushSongToQueue /
        // _fetchAndAddRadioSongs load the first radio page; with length 1 the
        // old check (index >= length - 2) is always true and duplicated fetches.
        if (radioInitiatorItem != null && currentQueue.length >= 2) {
          final currentIndex = currentQueue
              .indexWhere((element) => element.id == mediaItem.id);
          if (currentIndex >= 0 &&
              currentIndex >= currentQueue.length - 2) {
            // Enable radio mode if not already enabled
            if (!isRadioModeOn) {
              isRadioModeOn = true;
              playinfrom.value = PlaylingFrom(
                  type: PlaylingFromType.SELECTION,
                  name: AppLocalizations.of(Get.context!)!.startRadio);
              // Disable queue loop mode if it's enabled
              if (isQueueLoopModeEnabled.isTrue) {
                toggleQueueLoopMode(showMessage: false);
              }
              printINFO('Radio mode enabled for continuation');
            }
            // Skip if already adding continuation to prevent race condition
            if (!_isAddingRadioContinuation) {
              printINFO('Radio continuation triggered: currentIndex=$currentIndex, queueLength=${currentQueue.length}');
              await _addRadioContinuation(radioInitiatorItem!);
            }
          }
        }
        _clearTemporaryLyricAccent();
        lyrics.value = {"synced": "", "plainLyrics": ""};
        showLyricsflag.value = false;
        unawaited(_loadLyricsForCurrentSong());
        if (isDesktopLyricsDialogOpen) {
          ScreenNavigationSetup.popOverlayIfOpen();
        }

        // reset player visible state when player is in gesture mode
        if (Get.find<SettingsScreenController>().playerUi.value == 1) {
          gesturePlayerVisibleState.value = 2;
        }
      } else {
        currentSong.value = null;
      }
    });
  }

  void _listenForPlaylistChange() {
    _audioHandler.queue.listen((queue) {
      currentQueue.value = queue;
      currentQueue.refresh();
    });
  }

  Future<void> _restorePrevSession() async {
    final restrorePrevSessionEnabled =
        Hive.box("AppPrefs").get("restrorePlaybackSession") ?? false;
    if (restrorePrevSessionEnabled) {
      final prevSessionData =
          await Hive.openBox(prevSessionDataBoxName(currentServerId()));
      if (prevSessionData.keys.isNotEmpty) {
        final songList = (prevSessionData.get("queue") as List)
            .map((e) => MediaItemBuilder.fromJson(e))
            .toList();
        final int currentIndex = prevSessionData.get("index");
        final int position = prevSessionData.get("position");
        prevSessionData.close();
        await _audioHandler.addQueueItems(songList);
        _playerPanelCheck(restoreSession: true);
        await _audioHandler.customAction("playByIndex", {
          "index": currentIndex,
          "position": position,
          "restoreSession": true
        });
      }
    }
  }

  void _listenForCustomEvents() {
    _audioHandler.customEvent.listen((event) {
      if (event['eventType'] == 'playFromMediaId') {
        _playViaAndroidAuto(event['songId'], event['libraryId']);
      }
    });
  }

  ///pushSongToPlaylist method clear previous song queue, plays the tapped song and push related
  ///songs into Queue
  Future<void> pushSongToQueue(MediaItem? mediaItem,
      {String? playlistid, bool radio = false}) async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTube = server?.type == ServerType.youtubeMusic;

    // Auto-start radio for single songs on YouTube Music if enabled
    if (!radio && isYouTube && playlistid == null) {
      final autoRadioEnabled = Hive.box("AppPrefs").get("autoRadioEnabled") ?? true;
      if (autoRadioEnabled) {
        radio = true;
        printINFO('Auto-radio enabled for pushSongToQueue: ${mediaItem?.title}');
      }
    }

    /// update playing from value
    playinfrom.value = PlaylingFrom(
        type: PlaylingFromType.SELECTION,
        name: radio
            ? AppLocalizations.of(Get.context!)!.startRadio
            : AppLocalizations.of(Get.context!)!.randomSelection);

    /// set global radio mode flag
    isRadioModeOn = radio;

    // Set radio initiator for continuation
    if (radio) {
      radioInitiatorItem = mediaItem ?? playlistid;
      _lastContinuationParamUsed = null;
      printINFO('Radio initiator set: ${mediaItem?.title ?? playlistid}');
    }

    Future.delayed(
      Duration.zero,
      () async {
        final content = await _musicServices.getWatchPlaylist(
            videoId: mediaItem?.id ?? "", radio: radio, playlistId: playlistid);
        radioContinuationParam = content['additionalParamsForNext'];
        printINFO('Radio continuation param set: $radioContinuationParam');
        final tracks = List<MediaItem>.from(content['tracks']);
        
        if (radio) {
          // For radio mode, add tracks to existing queue instead of replacing
          // Remove current song from radio tracks to avoid duplicate
          final filteredTracks = tracks.where((t) => t.id != mediaItem?.id).toList();
          printINFO('Radio: adding ${filteredTracks.length} tracks to queue without replacing');
          await enqueueSongList(filteredTracks);
        } else {
          // For non-radio, replace the queue
          await _audioHandler.updateQueue(tracks);
          printINFO('Queue updated with ${tracks.length} tracks');
          if (isShuffleModeEnabled.isTrue) {
            await _audioHandler.customAction("shuffleCmd", {"index": 0});
          }
        }

        // added here to broadcast current mediaitem via Audio Service as list is updated
        // if radio is started on current playing song
        if (radio && (currentSong.value?.id == mediaItem?.id)) {
          _audioHandler
              .customAction("upadateMediaItemInAudioService", {"index": 0});
        }
      },
    ).then((value) async {
      if (playlistid != null) {
        _playerPanelCheck();
        await _audioHandler.customAction("playByIndex", {"index": 0});
      } else {
        if (Hive.box("AppPrefs").get("discoverContentType") == "BOLI") {
          Get.find<HomeScreenController>()
              .changeDiscoverContent("BOLI", songId: mediaItem!.id);
        }
      }
    });

    if (playlistid != null ||
        (radio && (currentSong.value?.id == mediaItem?.id))) {
      return;
    }

    //currentSong.value = mediaItem;
    _playerPanelCheck();
    await _audioHandler
        .customAction("setSourceNPlay", {'mediaItem': mediaItem});

    // disable queue loop mode when radio is started
    if (radio &&
        isQueueLoopModeEnabled.isTrue &&
        isShuffleModeEnabled.isFalse) {
      toggleQueueLoopMode();
    }
  }

  Future<void> playPlayListSong(List<MediaItem> mediaItems, int index,
      {PlaylingFrom? playfrom}) async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTube = server?.type == ServerType.youtubeMusic;
    final autoRadioEnabled = Hive.box("AppPrefs").get("autoRadioEnabled") ?? true;

    isRadioModeOn = false;
    //open player pane,set current song and push first song into playing list,

    /// update playing from value
    playinfrom.value =
        playfrom ?? PlaylingFrom(type: PlaylingFromType.SELECTION);

    //for changing home content based on last interation
    Future.delayed(const Duration(seconds: 3), () {
      if (Hive.box("AppPrefs").get("discoverContentType") == "BOLI") {
        Get.find<HomeScreenController>()
            .changeDiscoverContent("BOLI", songId: mediaItems[index].id);
      }
    });

    _playerPanelCheck();
    await _audioHandler.updateQueue(mediaItems);
    if (isShuffleModeEnabled.value) {
      await _audioHandler.customAction("shuffleCmd", {"index": index});
    }
    final playIndex = isShuffleModeEnabled.value ? 0 : index;
    await _audioHandler.customAction("playByIndex", {"index": playIndex});

    // Auto-start radio for single songs on YouTube Music if enabled
    // Start after song begins playing to prevent loading delay
    if (isYouTube && autoRadioEnabled && mediaItems.length == 1) {
      printINFO('Auto-radio will start for single song: ${mediaItems[index].title}');
      // Wait for song to start playing before starting radio
      _listenForPlaybackToStartRadio(mediaItems[index]);
    }

    // Enable radio mode for albums/playlists to continue after last song
    if (isYouTube && autoRadioEnabled && mediaItems.length > 1) {
      // Set radio initiator to last song for continuation
      radioInitiatorItem = mediaItems.last;
      // Don't set isRadioModeOn yet - will be set when reaching last song
      printINFO('Radio mode prepared for album: ${playfrom?.nameString}, will continue after last song');
    }
  }

  void _listenForPlaybackToStartRadio(MediaItem mediaItem) {
    // Listen for playback state to start radio after song begins
    StreamSubscription? subscription;
    subscription = _audioHandler.playbackState.listen((state) {
      if (state.playing && state.processingState == AudioProcessingState.ready) {
        subscription?.cancel();
        // Start radio mode after song is playing without interrupting
        printINFO('Auto-starting radio for song: ${mediaItem.title}');
        radioInitiatorItem = mediaItem;
        isRadioModeOn = true;
        playinfrom.value = PlaylingFrom(
          type: PlaylingFromType.SELECTION,
          name: AppLocalizations.of(Get.context!)!.startRadio);
        // Disable queue loop mode if it's enabled
        if (isQueueLoopModeEnabled.isTrue) {
          toggleQueueLoopMode(showMessage: false);
        }
        // Fetch and add radio songs to existing queue
        _fetchAndAddRadioSongs(mediaItem);
      }
    });
  }

  Future<void> _fetchAndAddRadioSongs(MediaItem mediaItem) async {
    _lastContinuationParamUsed = null;
    try {
      final content = await _musicServices.getWatchPlaylist(
          videoId: mediaItem.id,
          radio: true,
          limit: 24);
      radioContinuationParam = content['additionalParamsForNext'];
      final tracks = List<MediaItem>.from(content['tracks']);
      // Remove current song from tracks to avoid duplicate
      final filteredTracks = tracks.where((t) => t.id != mediaItem.id).toList();
      printINFO('Radio: fetched ${filteredTracks.length} tracks to add to queue');
      await enqueueSongList(filteredTracks);
    } catch (e) {
      printERROR('Radio fetch failed: $e');
      isRadioModeOn = false;
    }
  }

  Future<void> startRadio(MediaItem? mediaItem, {String? playlistid}) async {
    radioInitiatorItem = mediaItem ?? playlistid;
    await pushSongToQueue(mediaItem, playlistid: playlistid, radio: true);
  }

  Future<void> _addRadioContinuation(dynamic item) async {
    printINFO('Radio continuation: called, isAdding=$_isAddingRadioContinuation, currentParam=$radioContinuationParam, lastParam=$_lastContinuationParamUsed');
    if (_isAddingRadioContinuation) {
      printINFO('Radio continuation: already in progress, skipping');
      return;
    }
    // Skip only when both are set and match; null == null must not block a fetch.
    if (radioContinuationParam != null &&
        _lastContinuationParamUsed != null &&
        radioContinuationParam == _lastContinuationParamUsed) {
      printINFO('Radio continuation: same continuation param as last, skipping');
      return;
    }
    _isAddingRadioContinuation = true;
    _lastContinuationParamUsed = radioContinuationParam;
    printINFO('Radio continuation: starting fetch with param=$radioContinuationParam');
    try {
      final isSong = item.runtimeType.toString() == "MediaItem";
      final content = await _musicServices.getWatchPlaylist(
          videoId: isSong ? item.id : "",
          radio: true,
          limit: 24,
          playlistId: isSong ? null : item,
          additionalParamsNext: radioContinuationParam);
      radioContinuationParam = content['additionalParamsForNext'];
      final tracks = List<MediaItem>.from(content['tracks']);
      printINFO('Radio continuation: fetched ${tracks.length} tracks, newParam=$radioContinuationParam');
      if (tracks.isNotEmpty) {
        // Remove the current song from tracks if it's the first call to avoid duplicate
        final filteredTracks = isSong && radioContinuationParam == null
            ? tracks.where((t) => t.id != item.id).toList()
            : tracks;
        printINFO('Radio continuation: adding ${filteredTracks.length} tracks to queue');
        await enqueueSongList(filteredTracks);
      } else {
        // No more tracks available, stop radio mode
        printINFO('Radio continuation: no more tracks, stopping radio mode');
        isRadioModeOn = false;
        radioContinuationParam = null;
      }
    } catch (e) {
      printERROR('Radio continuation failed: $e');
      // Stop radio mode on error to prevent infinite retry loops
      isRadioModeOn = false;
      radioContinuationParam = null;
    } finally {
      printINFO('Radio continuation: completed, resetting flag');
      _isAddingRadioContinuation = false;
    }
  }

  ///enqueueSong   append a song to current queue
  ///if current queue is empty, push the song into Queue and play that song
  Future<void> enqueueSong(MediaItem mediaItem) async {
    if (currentQueue.isEmpty) {
      await playPlayListSong([mediaItem], 0);
      return;
    }
    //check if song is available in queue and if not add it to queue
    if (!currentQueue.contains(mediaItem)) {
      _audioHandler.addQueueItem(mediaItem);
    }
  }

  ///enqueueSongList method add song List to current queue
  Future<void> enqueueSongList(List<MediaItem> mediaItems) async {
    if (currentQueue.isEmpty) {
      await playPlayListSong(mediaItems, 0);
      return;
    }
    final existingIds = currentQueue.map((e) => e.id).toSet();
    final listToEnqueue = <MediaItem>[];
    for (MediaItem item in mediaItems) {
      if (!existingIds.contains(item.id)) {
        listToEnqueue.add(item);
        existingIds.add(item.id);
      }
    }
    if (listToEnqueue.isNotEmpty) {
      printINFO('enqueueSongList: adding ${listToEnqueue.length} unique items (filtered ${mediaItems.length - listToEnqueue.length} duplicates)');
      _audioHandler.addQueueItems(listToEnqueue);
    } else {
      printINFO('enqueueSongList: all items already in queue, skipping');
    }
  }

  void _playViaAndroidAuto(String songId, String libraryId) {
    _playFromContext(songId, libraryId);
  }

  Future<void> _playFromContext(String songId, String libraryId) async {
    // 1. Try Hive box with this ID (works for SongDownloads, LIBRP, LIBFAV,
    //    and cached album/playlist boxes)
    if (await _playFromLibraryBox(songId, libraryId)) return;

    // 2. If libraryId is a known root (home, albums, etc.) or an
    //    album/playlist browse ID, fetch songs via MediaLibrary
    if (libraryId.isNotEmpty) {
      try {
        final songs = await (_audioHandler as MyAudioHandler).mediaLibrary.getByRootId(libraryId);
        final idx = songs.indexWhere((s) => s.id == songId);
        if (idx >= 0 && songs.isNotEmpty) {
          playPlayListSong(songs, idx);
          return;
        }
      } catch (e) {
        printINFO('[player] _playFromContext getByRootId failed: $e');
      }
    }

    // 3. Fallback: search known boxes
    await _playFromAnyBox(songId);
  }

  Future<bool> _playFromLibraryBox(String songId, String libraryId) async {
    if (libraryId.isEmpty) return false;
    try {
      final box = await Hive.openBox(libraryId);
      final songJson = box.values.toList();
      List<MediaItem> songList = [];
      int songIndex = -1;
      for (int i = 0; i < songJson.length; i++) {
        final song = MediaItemBuilder.fromJson(songJson[i]);
        if (song.id == songId) {
          songIndex = i;
        }
        songList.add(song);
      }
      if (songIndex >= 0 && songList.isNotEmpty) {
        playPlayListSong(songList, songIndex);
        return true;
      }
    } catch (e) {
      printINFO('[player] _playFromLibraryBox failed for $libraryId: $e');
    }
    return false;
  }

  Future<void> _playFromAnyBox(String songId) async {
    final sid = currentServerId();
    // Try known library boxes first
    final boxNames = [
      songDownloadsBoxName(sid),
      recentlyPlayedBoxName(sid),
      libFavBoxName(sid),
    ];
    for (final name in boxNames) {
      final found = await _playFromLibraryBox(songId, name);
      if (found) return;
    }
    // Try library songs controller
    try {
      if (Get.isRegistered<LibrarySongsController>()) {
        final ctrl = Get.find<LibrarySongsController>();
        final songs = ctrl.librarySongsList.toList();
        final idx = songs.indexWhere((s) => s.id == songId);
        if (idx >= 0) {
          playPlayListSong(songs, idx);
          return;
        }
      }
    } catch (e) {
      printINFO('[player] _playFromAnyBox library songs failed: $e');
    }
    printINFO('[player] could not find song $songId in any box');
  }

  void playNext(MediaItem song) {
    if (currentQueue.isEmpty) {
      enqueueSong(song);
      return;
    }
    int index = -1;
    for (int i = 0; i < currentQueue.length; i++) {
      if (song.id == (currentQueue[i]).id) {
        index = i;
        break;
      }
    }
    final currentIndx = currentSongIndex.value;
    if (index == currentIndx) {
      return;
    }
    if (index != -1) {
      if (currentQueue.length == 1 ||
          (currentQueue.length == 2 && index == 1)) {
        return;
      }
      onReorder(index, currentSongIndex.value + 1);
    } else {
      //Will add song just below the current song
      (currentIndx == currentQueue.length - 1)
          ? enqueueSong(song)
          : _audioHandler.customAction("addPlayNextItem", {"mediaItem": song});
    }
  }

  void _playerPanelCheck({bool restoreSession = false}) {
    final isWideScreen = Get.size.width > 800;
    // Removed auto-open on mobile to match desktop behavior
    if (initFlagForPlayer) {
      final miniPlayerHeight = isWideScreen ? 105.0 : 75.0;
      final useBottomNav = Get.find<ShellController>().useBottomNav.value;
      if (!useBottomNav || getCurrentRouteName() != '/homeScreen') {
        playerPanelMinHeight.value =
            miniPlayerHeight + Get.mediaQuery.viewPadding.bottom;
      } else {
        playerPanelMinHeight.value = miniPlayerHeight;
      }
      initFlagForPlayer = false;
    }
  }

  void removeFromQueue(MediaItem song) {
    _audioHandler.removeQueueItem(song);
  }

  void clearQueue() {
    _audioHandler.customAction("clearQueue");
  }

  void shuffleQueue() {
    _audioHandler.customAction("shuffleQueue");
  }

  Future<void> toggleShuffleMode() async {
    final shuffleModeEnabled = isShuffleModeEnabled.value;
    shuffleModeEnabled
        ? _audioHandler.setShuffleMode(AudioServiceShuffleMode.none)
        : _audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
    isShuffleModeEnabled.value = !shuffleModeEnabled;
    await Hive.box("AppPrefs").put("isShuffleModeEnabled", !shuffleModeEnabled);
  }

  void onReorder(int oldIndex, int newIndex) {
    _audioHandler.customAction(
        "reorderQueue", {"oldIndex": oldIndex, "newIndex": newIndex});
  }

  void onReorderStart(int index) {
    isQueueReorderingInProcess.value = true;
  }

  void onReorderEnd(int index) {
    isQueueReorderingInProcess.value = false;
  }

  void play() {
    _diag.logEvent(
      category: 'player_event',
      message: 'ui_play_pressed',
      songId: currentSong.value?.id,
      backendType: currentSong.value?.extras?['backendType']?.toString(),
    );
    _audioHandler.play();
  }

  void pause() {
    _diag.logEvent(
      category: 'player_event',
      message: 'ui_pause_pressed',
      songId: currentSong.value?.id,
      backendType: currentSong.value?.extras?['backendType']?.toString(),
    );
    _audioHandler.pause();
  }

  void playPause() {
    if (initFlagForPlayer) return;
    _audioHandler.playbackState.value.playing ? pause() : play();
    // for gesture player
    if (Get.find<SettingsScreenController>().playerUi.value == 1) {
      gesturePlayerVisibleState.value =
          _audioHandler.playbackState.value.playing ? 0 : 1;
      gesturePlayerStateAnimationController?.reset();
      gesturePlayerStateAnimationController?.forward();
    }
  }

  void prev() {
    _audioHandler.skipToPrevious();
  }

  Future<void> next() async {
    _diag.logEvent(
      category: 'player_event',
      message: 'ui_next_pressed',
      songId: currentSong.value?.id,
      backendType: currentSong.value?.extras?['backendType']?.toString(),
    );
    await _audioHandler.skipToNext();
  }

  void seek(Duration position) {
    _audioHandler.seek(position);
  }

  void seekByIndex(int index) {
    _diag.logEvent(
      category: 'player_event',
      message: 'ui_seek_by_index',
      songId: currentSong.value?.id,
      backendType: currentSong.value?.extras?['backendType']?.toString(),
      data: {'index': index},
    );
    _audioHandler.customAction("playByIndex", {"index": index});
  }

  void toggleSkipSilence(bool enable) {
    _audioHandler.customAction("toggleSkipSilence", {"enable": enable});
  }

  void toggleLoudnessNormalization(bool enable) {
    _audioHandler
        .customAction("toggleLoudnessNormalization", {"enable": enable});
  }

  Future<void> toggleLoopMode() async {
    isLoopModeEnabled.isFalse
        ? _audioHandler.setRepeatMode(AudioServiceRepeatMode.one)
        : _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
    isLoopModeEnabled.value = !isLoopModeEnabled.value;
    await Hive.box("AppPrefs")
        .put("isLoopModeEnabled", isLoopModeEnabled.value);
  }

  Future<void> toggleQueueLoopMode({bool showMessage = true}) async {
    if (isShuffleModeEnabled.isTrue && isQueueLoopModeEnabled.isTrue) {
      if (!showMessage) return;
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.queueLoopNotDisMsg1,
          size: SnackBarSize.BIG, duration: const Duration(seconds: 2)));
      return;
    }

    if (isRadioModeOn && isQueueLoopModeEnabled.isFalse) {
      if (!showMessage) return;
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.queueLoopNotDisMsg2,
          size: SnackBarSize.BIG, duration: const Duration(seconds: 2)));
      return;
    }

    isQueueLoopModeEnabled.value = !isQueueLoopModeEnabled.value;
    await _audioHandler.customAction(
        "toggleQueueLoopMode", {"enable": isQueueLoopModeEnabled.value});
    await Hive.box("AppPrefs")
        .put("queueLoopModeEnabled", isQueueLoopModeEnabled.value);
  }

  Future<void> setVolume(int value) async {
    final uiVolume = value.clamp(0, 100);
    if (uiVolume > 0) {
      _lastNonZeroVolume = uiVolume;
    }
    final internalVolume = uiVolume == 0
        ? 0
        : (_minInternalAudibleVolume + (uiVolume * 0.8))
            .round()
            .clamp(_minInternalAudibleVolume, 100);
    _audioHandler.customAction("setVolume", {"value": internalVolume});
    volume.value = uiVolume;
    await Hive.box("AppPrefs").put("volume", uiVolume);
  }

  Future<void> mute() async {
    int vol;
    if (volume.value != 0) {
      vol = 0;
    } else {
      vol = await Hive.box("AppPrefs").get("volume", defaultValue: 100);
      if (vol == 0) {
        vol = _lastNonZeroVolume > 0 ? _lastNonZeroVolume : 100;
      }
    }
    await setVolume(vol);
  }

  Future<void> _checkFav() async {
    final song = currentSong.value;
    if (song == null) {
      isCurrentSongFav.value = false;
      return;
    }

    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTube = server?.type == ServerType.youtubeMusic;

    if (isYouTube) {
      final favBox = await Hive.openBox(libFavBoxName(currentServerId()));
      isCurrentSongFav.value = favBox.containsKey(song.id);
      return;
    }

    try {
      final favorites = await settings.currentBackend.getFavoriteSongs();
      isCurrentSongFav.value =
          favorites.any((e) => e['videoId']?.toString() == song.id);
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=player.syncCurrentSongFavorite.remote] Failed to fetch favorites for songId=${song.id}: $e\n$st');
      isCurrentSongFav.value = false;
    }
  }

  Future<void> toggleFavourite() async {
    final currMediaItem = currentSong.value!;
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTube = server?.type == ServerType.youtubeMusic;

    if (isYouTube) {
      final box = await Hive.openBox(libFavBoxName(currentServerId()));
      isCurrentSongFav.isFalse
          ? box.put(currMediaItem.id, MediaItemBuilder.toJson(currMediaItem))
          : box.delete(currMediaItem.id);
      try {
        final playlistController = Get.find<PlaylistScreenController>(
            tag: const Key("LIBFAV").hashCode.toString());
        isCurrentSongFav.isFalse
            ? playlistController.addNRemoveItemsinList(currMediaItem,
                action: 'add', index: 0)
            : playlistController.addNRemoveItemsinList(currMediaItem,
                action: 'remove');
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=player.toggleFavorite.updateLocalFavPlaylist] Failed to sync LIBFAV controller for songId=${currMediaItem.id}: $e\n$st');
      }
      isCurrentSongFav.value = !isCurrentSongFav.value;
      if (Get.isRegistered<HomeScreenController>()) {
        final homeCtrl = Get.find<HomeScreenController>();
        if (isCurrentSongFav.isTrue) {
          homeCtrl.favoriteCount.value++;
        } else {
          homeCtrl.favoriteCount.value--;
        }
      }
      if (settings.autoDownloadFavoriteSongEnabled.isTrue &&
          isCurrentSongFav.isTrue) {
        Get.find<Downloader>().download(currMediaItem);
      }
      return;
    }

    final newValue = !isCurrentSongFav.value;
    isCurrentSongFav.value = newValue;
    await settings.currentBackend.setSongFavorite(currMediaItem.id, newValue);
  }

  // ignore: prefer_typing_uninitialized_variables
  var recentItem;

  /// This function is used to add a mediaItem/Song to Recently played playlist
  Future<void> _addToRP(MediaItem mediaItem) async {
    if (recentItem != mediaItem) {
      final box = await Hive.openBox(recentlyPlayedBoxName(currentServerId()));
      String? removedSongId;
      if (box.keys.length >= 30) {
        removedSongId = box.getAt(0)['videoId'];
        box.deleteAt(0);
      }
      final valuesCopy = box.values.toList();
      for (int i = valuesCopy.length - 1; i >= 0; i--) {
        if (valuesCopy[i]['videoId'] == mediaItem.id) {
          box.deleteAt(i);
        }
      }
      box.add(MediaItemBuilder.toJson(mediaItem));
      try {
        final playlistController = Get.find<PlaylistScreenController>(
            tag: const Key("LIBRP").hashCode.toString());
        if (removedSongId != null) {
          playlistController.songList
              .removeWhere((element) => element.id == removedSongId);
        }
        // removes current duplicate item from list
        playlistController.songList
            .removeWhere((element) => element.id == mediaItem.id);
        // adds current item to list
        playlistController.addNRemoveItemsinList(mediaItem,
            action: 'add', index: 0);
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=player.addToRecentlyPlayed.syncPlaylistController] Failed to sync LIBRP controller for songId=${mediaItem.id}: $e\n$st');
      }
    }
    recentItem = mediaItem;
  }

  static final RegExp _lrcLineRegex = RegExp(
      r'^\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\]\s*(.*)$',
      multiLine: true);

  void _parseSyncedLyrics(String raw) {
    _syncedLyricLines = [];
    _clearTemporaryLyricAccent();
    if (raw.isEmpty) return;
    final lines = raw.split('\n');
    for (final line in lines) {
      final m = _lrcLineRegex.firstMatch(line);
      if (m == null) continue;
      final minutes = int.tryParse(m.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(m.group(2) ?? '') ?? 0;
      final frac = m.group(3) ?? '';
      int ms = 0;
      if (frac.isNotEmpty) {
        final n = int.tryParse(frac.length >= 3 ? frac.substring(0, 3) : frac);
        ms = n != null ? (frac.length == 2 ? n * 10 : n) : 0;
      }
      final text = (m.group(4) ?? '').trim();
      if (text.isEmpty) continue;
      final timestamp =
          Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
      _syncedLyricLines.add(SyncedLyricLine(timestamp: timestamp, text: text));
    }
    _syncedLyricLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  int currentSyncedLyricLineIndex(Duration position) {
    if (_syncedLyricLines.isEmpty) return -1;
    int i = -1;
    for (var j = 0; j < _syncedLyricLines.length; j++) {
      if (_syncedLyricLines[j].timestamp <= position) {
        i = j;
      } else {
        break;
      }
    }
    return i;
  }

  void _updateDynamicColorFromLyrics(Duration position) {
    // Global accent updates at lyric cadence cause noisy rebuilds and stutter.
    // Keep this stable; lyrics can still render and animate locally.
    return;
  }

  void _clearTemporaryLyricAccent() {
    if (!_isTemporaryLyricAccentActive && _lastLyricsColor == null) return;
    _isTemporaryLyricAccentActive = false;
    _lastLyricsColor = null;
  }

  void _syncLyricsModeWithAvailability() {
    final hasSynced = (lyrics['synced']?.toString() ?? '').trim().isNotEmpty;
    final plain = (lyrics['plainLyrics']?.toString() ?? '').trim();
    final hasPlain = plain.isNotEmpty && plain != 'NA';

    if (hasSynced && lyricsMode.value != 0) {
      lyricsMode.value = 0;
      return;
    }

    if (!hasSynced && hasPlain && lyricsMode.value != 1) {
      lyricsMode.value = 1;
    }
  }

  Future<void> _loadLyricsForCurrentSong() async {
    if (currentSong.value == null) return;
    isLyricsLoading.value = true;
    try {
      final Map<String, dynamic>? lyricsR =
          await SyncedLyricsService.getSyncedLyrics(
              currentSong.value!, progressBarStatus.value.total.inSeconds);
      if (lyricsR != null) {
        lyrics.value = lyricsR;
        final synced = lyricsR['synced']?.toString() ?? '';
        if (synced.isNotEmpty) {
          _parseSyncedLyrics(synced);
        } else {
          _syncedLyricLines = [];
          _clearTemporaryLyricAccent();
        }
        _syncLyricsModeWithAvailability();
        isLyricsLoading.value = false;
        return;
      }
      final backendType = currentSong.value?.extras?['backendType']?.toString();
      final isNonYouTube = backendType == 'jellyfin' ||
          backendType == 'subsonic' ||
          backendType == 'plex';
      if (!isNonYouTube) {
        final related = await _musicServices.getWatchPlaylist(
            videoId: currentSong.value!.id, onlyRelated: true);
        final relatedLyricsId = related['lyrics'];
        if (relatedLyricsId != null) {
          final lyrics_ = await _musicServices.getLyrics(relatedLyricsId);
          lyrics.value = {"synced": "", "plainLyrics": lyrics_};
        } else {
          lyrics.value = {"synced": "", "plainLyrics": "NA"};
        }
      } else {
        lyrics.value = {"synced": "", "plainLyrics": "NA"};
      }
      _syncedLyricLines = [];
      _clearTemporaryLyricAccent();
      _syncLyricsModeWithAvailability();
    } catch (e) {
      lyrics.value = {"synced": "", "plainLyrics": "NA"};
      _syncedLyricLines = [];
      _clearTemporaryLyricAccent();
      _syncLyricsModeWithAvailability();
    }
    isLyricsLoading.value = false;
  }

  Future<void> showLyrics() async {
    showLyricsflag.value = !showLyricsflag.value;
    if ((lyrics["synced"].isEmpty && lyrics['plainLyrics'].isEmpty) &&
        showLyricsflag.value) {
      await _loadLyricsForCurrentSong();
    }
  }

  Future<void> ensureLyricsLoadedForSheet() async {
    if (currentSong.value == null) return;
    if (lyrics["synced"].isEmpty && lyrics['plainLyrics'].isEmpty) {
      await _loadLyricsForCurrentSong();
    }
  }

  void changeLyricsMode(int? val) {
    Hive.box("AppPrefs").put("lyricsMode", val);
    lyricsMode.value = val!;
  }

  void sleepEndOfSong() {
    isSleepTimerActive.value = true;
    isSleepEndOfSongActive.value = true;
  }

  void startSleepTimer(int minutes) {
    timerDuration = minutes * 60;
    isSleepTimerActive.value = true;
    if ((sleepTimer != null && !sleepTimer!.isActive) || sleepTimer == null) {
      sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (timer.tick == timerDuration) {
          sleepTimer?.cancel();
          pause();
          isSleepTimerActive.value = false;
          timerDuration = 0;
          timerDurationLeft.value = 0;
        } else {
          timerDurationLeft.value = timerDuration - timer.tick;
        }
      });
    }
  }

  void addFiveMinutes() {
    timerDuration += 300;
  }

  void cancelSleepTimer() {
    if (isSleepEndOfSongActive.isTrue) {
      isSleepEndOfSongActive.value = false;
    }
    sleepTimer?.cancel();
    isSleepTimerActive.value = false;
    timerDuration = 0;
    timerDurationLeft.value = 0;
  }

  Future<void> openEqualizer() async {
    await _audioHandler.customAction("openEqualizer");
  }

  /// Called from audio handler in case audio is not playable
  /// or returned streamInfo null due to network error
  void notifyPlayError(String message) {
    _diag.logEvent(
      category: 'ui_error',
      message: 'notify_play_error',
      songId: currentSong.value?.id,
      backendType: currentSong.value?.extras?['backendType']?.toString(),
      data: {'status': message},
    );
    final displayMessage = _formatPlayErrorMessage(message);
    final ctx = Get.context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
        .showSnackBar(snackbar(ctx, displayMessage, size: SnackBarSize.MEDIUM));
  }

  String _formatPlayErrorMessage(String raw) {
    final ctx = Get.context;
    if (raw.startsWith('networkError')) {
      return ctx != null
          ? AppLocalizations.of(ctx)!.networkError
          : 'Network error while starting playback.';
    }

    var message = raw.trim();
    if (message.isEmpty) {
      return 'Unable to start playback.';
    }

    // Handle errors returned as a JSON object, e.g. from custom backends.
    if (message.startsWith('{') && message.endsWith('}')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map && decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      } catch (_) {
        // fall through to other handlers
      }
    }

    if (message.contains('TrackNotFound')) {
      return 'Track is no longer available on the server.';
    }

    if (message.startsWith('DioException')) {
      final m = RegExp(r'status code of (\d+)').firstMatch(message);
      final code = m?.group(1);
      return code != null
          ? 'Server error $code while starting playback.'
          : 'Server error while starting playback.';
    }

    // Clamp any remaining message to a sane length for the snackbar.
    const maxLen = 180;
    if (message.length > maxLen) {
      return '${message.substring(0, maxLen - 1)}…';
    }
    return message;
  }

  @override
  void dispose() {
    _audioHandler.customAction('dispose');
    keyboardSubscription.cancel();
    scrollController.dispose();
    gesturePlayerStateAnimationController?.dispose();
    sleepTimer?.cancel();
    if (GetPlatform.isWindows) {
      Get.delete<WindowsAudioService>();
    }
    // ensure wakelock disabled when player controller disposed
    try {
      unawaited(_setWakelock(false));
    } catch (e) {
      printERROR(e);
    }
    super.dispose();
  }
}

enum PlayButtonState { paused, playing, loading }
