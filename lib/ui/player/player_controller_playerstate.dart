part of 'player_controller.dart';

mixin _PlayerStateMixin on _PlayerControllerBase {
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

  void _playerPanelCheck({bool restoreSession = false}) {
    // On desktop the now playing panel is a side panel, not a bottom bar.
    // The app_shell build method handles setting playerPanelMinHeight to 0
    // via desiredMinHeight, so we just skip the mobile height calc here.
    if (GetPlatform.isDesktop) {
      if (initFlagForPlayer) {
        initFlagForPlayer = false;
      }
      return;
    }
    final isWideScreen = Get.size.width > 800;
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
