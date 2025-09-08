  /// Fallback method for playing the current track in background
  /// Uses a simplified, more reliable approach for background playback
  Future<void> _playCurrentTrackFallback() async {
    if (kDebugMode) {
      print('Using fallback method for playing track in background');
    }
    
    final track = _stateManager.currentTrack;
    if (track == null) return;
    
    try {
      // Stop current playback
      await _player.stop().timeout(const Duration(seconds: 2), onTimeout: () => null);
      
      // Immediately update state for responsiveness
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        queueIndex: _stateManager.currentIndex,
      ));
      
      // Check for local file first (most reliable)
      final localFilePath = _downloadService.getLocalFilePath(track.id);
      if (localFilePath != null) {
        final localFile = File(localFilePath);
        if (await localFile.exists()) {
          await _player.setFilePath(localFilePath)
              .timeout(const Duration(seconds: 5));
          
          if (kDebugMode) {
            print('Fallback: Playing local file for ${track.name}');
          }
          
          await _player.play();
          return;
        }
      }
      
      // Use direct URL approach (most reliable for streaming)
      final directUrl = _jellyfinService.getDirectStreamUrl(track.id);
      
      await _player.setUrl(directUrl)
          .timeout(const Duration(seconds: 5));
      
      await _player.play();
      
      if (kDebugMode) {
        print('Fallback: Playing stream URL for ${track.name}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error in playback fallback: $e');
      }
      
      // Last resort - try basic audio source
      try {
        final basicUrl = _jellyfinService.getStreamUrl(track.id);
        await _player.setUrl(basicUrl)
            .timeout(const Duration(seconds: 5));
        await _player.play();
      } catch (fallbackError) {
        if (kDebugMode) {
          print('Fallback playback failed: $fallbackError');
        }
        
        // Move to next track if possible
        if (_stateManager.hasNext && _stateManager.incrementCurrentIndex()) {
          return _playCurrentTrackFallback();
        }
      }
    }
  }
