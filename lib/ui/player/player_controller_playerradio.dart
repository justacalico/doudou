part of 'player_controller.dart';

mixin _PlayerRadioMixin on _PlayerControllerBase {
  void _listenForPlaybackToStartRadio(MediaItem mediaItem) {
    // Listen for playback state to start radio after song begins
    StreamSubscription? subscription;
    subscription = _audioHandler.playbackState.listen((state) {
      if (state.playing && state.processingState == AudioProcessingState.ready) {
        subscription?.cancel();
        // Start radio mode after song is playing without interrupting
        printINFO('Auto-starting radio for song: ${mediaItem.title}');
        _diag.logEvent(
          category: 'radio',
          message: 'radio_auto_start_after_play',
          songId: mediaItem.id,
          backendType: mediaItem.extras?['backendType']?.toString(),
          activeServerType: _activeServerTypeName,
        );
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
    _diag.logEvent(
      category: 'radio',
      message: 'radio_fetch_start',
      songId: mediaItem.id,
      backendType: mediaItem.extras?['backendType']?.toString(),
      activeServerType: _activeServerTypeName,
    );
    try {
      _radio.initFromSeed(mediaItem.id, excludeIds: {mediaItem.id});
      final tracks = await _radio.fetchInitial();
      printINFO('Radio: fetched ${tracks.length} tracks to add to queue');
      _diag.logEvent(
        category: 'radio',
        message: 'radio_tracks_appended',
        songId: mediaItem.id,
        backendType: mediaItem.extras?['backendType']?.toString(),
        activeServerType: _activeServerTypeName,
        data: {
          'trackCount': tracks.length,
          'hasContinuation': _radio.lastContinuationToken != null,
        },
      );
      await enqueueSongList(tracks);
    } catch (e) {
      printERROR('Radio fetch failed: $e');
      _diag.logEvent(
        category: 'radio',
        message: 'radio_fetch_failed',
        songId: mediaItem.id,
        backendType: mediaItem.extras?['backendType']?.toString(),
        activeServerType: _activeServerTypeName,
        data: {'error': e.toString()},
      );
      isRadioModeOn = false;
    }
  }

  Future<void> startRadio(MediaItem? mediaItem, {String? playlistid}) async {
    _diag.logEvent(
      category: 'radio',
      message: 'radio_start_requested',
      songId: mediaItem?.id,
      backendType: mediaItem?.extras?['backendType']?.toString(),
      activeServerType: _activeServerTypeName,
      data: {
        'playlistId': playlistid,
        'seedIsCurrentSong': currentSong.value?.id == mediaItem?.id,
      },
    );
    radioInitiatorItem = mediaItem ?? playlistid;
    await pushSongToQueue(mediaItem, playlistid: playlistid, radio: true);
  }

  Future<void> _addRadioContinuation(dynamic item) async {
    printINFO('Radio continuation: called, isAdding=$_isAddingRadioContinuation, lastParam=${_radio.lastContinuationToken}');
    if (_isAddingRadioContinuation) {
      printINFO('Radio continuation: already in progress, skipping');
      _diag.logEvent(
        category: 'radio',
        message: 'radio_continuation_skipped',
        activeServerType: _activeServerTypeName,
        data: {'reason': 'in_progress'},
      );
      return;
    }
    _isAddingRadioContinuation = true;
    printINFO('Radio continuation: starting fetch');
    _diag.logEvent(
      category: 'radio',
      message: 'radio_continuation_start',
      songId: item is MediaItem ? item.id : null,
      activeServerType: _activeServerTypeName,
      data: {'hasParam': _radio.lastContinuationToken != null},
    );
    try {
      final tracks = await _radio.fetchMore();
      radioContinuationParam = _radio.lastContinuationToken;
      printINFO('Radio continuation: fetched ${tracks.length} tracks, newParam=$radioContinuationParam');
      if (tracks.isNotEmpty) {
        printINFO('Radio continuation: adding ${tracks.length} tracks to queue');
        _diag.logEvent(
          category: 'radio',
          message: 'radio_continuation_fetched',
          songId: item is MediaItem ? item.id : null,
          activeServerType: _activeServerTypeName,
          data: {
            'trackCount': tracks.length,
            'hasContinuation': radioContinuationParam != null,
          },
        );
        await enqueueSongList(tracks);
      } else {
        // No more tracks available, stop radio mode
        printINFO('Radio continuation: no more tracks, stopping radio mode');
        _diag.logEvent(
          category: 'radio',
          message: 'radio_continuation_empty',
          activeServerType: _activeServerTypeName,
        );
        isRadioModeOn = false;
        radioContinuationParam = null;
      }
    } catch (e) {
      printERROR('Radio continuation failed: $e');
      _diag.logEvent(
        category: 'radio',
        message: 'radio_continuation_failed',
        activeServerType: _activeServerTypeName,
        data: {'error': e.toString()},
      );
      // Stop radio mode on error to prevent infinite retry loops
      isRadioModeOn = false;
      radioContinuationParam = null;
    } finally {
      printINFO('Radio continuation: completed, resetting flag');
      _isAddingRadioContinuation = false;
    }
  }

}
