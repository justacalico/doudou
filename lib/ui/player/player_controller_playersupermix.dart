part of 'player_controller.dart';

mixin _PlayerSupermixMixin on _PlayerControllerBase {
  SupermixService? _supermixService;
  SupermixService get _supermix =>
      _supermixService ??= SupermixService(musicServices: _musicServices);

  /// Starts an endless personalised mix: the "My Supermix" playlist YouTube
  /// Music generates when it is available, otherwise a mix built from the
  /// user's favourites and recently played songs with discovery tracks
  /// thrown in.
  Future<void> startSupermix() async {
    final settings = Get.find<SettingsScreenController>();
    if (settings.activeServer?.type != ServerType.youtubeMusic) return;

    final l10n = l10nFromPrefs();
    _isAddingSupermixContinuation = false;
    isSupermixModeOn = false;
    isRadioModeOn = false;
    radioInitiatorItem = null;
    radioContinuationParam = null;

    playinfrom.value =
        PlaylingFrom(type: PlaylingFromType.PLAYLIST, name: l10n.supermix);

    final favouriteSeeds = await _loadSupermixFavouriteSeeds();
    final playing = currentSong.value;
    final recentSeeds = [
      if (playing != null) playing,
      ...await _loadSupermixRecentSeeds(),
    ];

    final result = await _supermix.fetchSupermix(
        favouriteSeeds: favouriteSeeds, recentSeeds: recentSeeds);
    if (result.tracks.isEmpty) {
      Get.snackbar('', l10n.supermixUnavailable);
      return;
    }

    isSupermixModeOn = true;
    _playerPanelCheck();
    await _audioHandler.updateQueue(result.tracks);
    if (isShuffleModeEnabled.isTrue) {
      await _audioHandler.customAction("shuffleCmd", {"index": 0});
    }
    await _audioHandler.customAction("playByIndex", {"index": 0});

    if (isQueueLoopModeEnabled.isTrue) {
      toggleQueueLoopMode(showMessage: false);
    }
    printINFO('Supermix started with ${result.tracks.length} tracks '
        '(playlistId: ${result.playlistId})');
  }

  /// Adds the next page of the mix when the queue approaches its end.
  Future<void> _addSupermixContinuation() async {
    if (_isAddingSupermixContinuation) return;
    _isAddingSupermixContinuation = true;
    try {
      final tracks = await _supermix.fetchMoreTracks(
          excludeIds: currentQueue.map((e) => e.id).toSet());
      printINFO('Supermix continuation: fetched ${tracks.length} tracks');
      if (tracks.isNotEmpty) {
        await enqueueSongList(tracks);
      }
    } catch (e) {
      printERROR('Supermix continuation failed: $e');
    } finally {
      _isAddingSupermixContinuation = false;
    }
  }

  Future<List<MediaItem>> _loadSupermixFavouriteSeeds() async {
    try {
      final box = await Hive.openBox(libFavBoxName(currentServerId()));
      return _safeSupermixSeeds(box.values);
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=player.supermix.favourites] Failed to read favourites: $e\n$st');
      return const [];
    }
  }

  Future<List<MediaItem>> _loadSupermixRecentSeeds() async {
    try {
      final box = await Hive.openBox(recentlyPlayedBoxName(currentServerId()));
      return _safeSupermixSeeds(box.values).reversed.toList();
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=player.supermix.recent] Failed to read recently played: $e\n$st');
      return const [];
    }
  }

  List<MediaItem> _safeSupermixSeeds(Iterable<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map<MediaItem>(
            (e) => MediaItemBuilder.fromJson(Map<dynamic, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }
}
