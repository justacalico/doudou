part of 'player_controller.dart';

mixin _PlayerFavMixin on _PlayerControllerBase {
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

}
