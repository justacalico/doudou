part of 'player_controller.dart';

mixin _PlayerLyricsMixin on _PlayerControllerBase {
  void _parseSyncedLyrics(String raw) {
    _syncedLyricLines = [];
    _clearTemporaryLyricAccent();
    if (raw.isEmpty) return;
    final lines = raw.split('\n');
    for (final line in lines) {
      final m = _PlayerControllerBase._lrcLineRegex.firstMatch(line);
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

}
