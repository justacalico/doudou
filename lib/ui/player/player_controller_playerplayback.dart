part of 'player_controller.dart';

mixin _PlayerPlaybackMixin on _PlayerControllerBase {
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

  void _playViaAndroidAuto(String songId, String libraryId) {
    _playFromContext(songId, libraryId);
  }

}
