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
    _lastContinuationParamUsed = null;
    _diag.logEvent(
      category: 'radio',
      message: 'radio_fetch_start',
      songId: mediaItem.id,
      backendType: mediaItem.extras?['backendType']?.toString(),
      activeServerType: _activeServerTypeName,
    );
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
      _diag.logEvent(
        category: 'radio',
        message: 'radio_tracks_appended',
        songId: mediaItem.id,
        backendType: mediaItem.extras?['backendType']?.toString(),
        activeServerType: _activeServerTypeName,
        data: {
          'trackCount': filteredTracks.length,
          'hasContinuation': radioContinuationParam != null,
        },
      );
      await enqueueSongList(filteredTracks);
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
    printINFO('Radio continuation: called, isAdding=$_isAddingRadioContinuation, currentParam=$radioContinuationParam, lastParam=$_lastContinuationParamUsed');
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
    // Skip only when both are set and match; null == null must not block a fetch.
    if (radioContinuationParam != null &&
        _lastContinuationParamUsed != null &&
        radioContinuationParam == _lastContinuationParamUsed) {
      printINFO('Radio continuation: same continuation param as last, skipping');
      _diag.logEvent(
        category: 'radio',
        message: 'radio_continuation_skipped',
        activeServerType: _activeServerTypeName,
        data: {'reason': 'same_param'},
      );
      return;
    }
    _isAddingRadioContinuation = true;
    _lastContinuationParamUsed = radioContinuationParam;
    printINFO('Radio continuation: starting fetch with param=$radioContinuationParam');
    _diag.logEvent(
      category: 'radio',
      message: 'radio_continuation_start',
      songId: item is MediaItem ? item.id : null,
      activeServerType: _activeServerTypeName,
      data: {'hasParam': radioContinuationParam != null},
    );
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
        _diag.logEvent(
          category: 'radio',
          message: 'radio_continuation_fetched',
          songId: isSong ? item.id : null,
          activeServerType: _activeServerTypeName,
          data: {
            'trackCount': filteredTracks.length,
            'hasContinuation': radioContinuationParam != null,
          },
        );
        await enqueueSongList(filteredTracks);
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
