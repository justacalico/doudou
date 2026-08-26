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

}
