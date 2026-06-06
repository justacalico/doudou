import 'package:audio_service/audio_service.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/downloader.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../screens/Home/home_screen_controller.dart';
import '../screens/Playlist/playlist_screen_controller.dart';
import '../screens/Settings/settings_screen_controller.dart';
import '/models/server.dart';
import '/utils/helper.dart';
import '/utils/server_storage.dart';
import '/services/piped_service.dart';
import '/ui/widgets/sleep_timer_bottom_sheet.dart';
import '/ui/player/player_controller.dart';
import '../screens/Library/library_controller.dart';
import '/ui/widgets/add_to_playlist.dart';
import '/ui/widgets/snackbar.dart';
import '../../models/media_Item_builder.dart';
import '../../models/playlist.dart';
import '../navigator.dart';
import '../shell_controller.dart';
import 'song_download_btn.dart';
import 'image_widget.dart';
import 'song_info_dialog.dart';

class SongInfoBottomSheet extends StatelessWidget {
  const SongInfoBottomSheet(this.song,
      {super.key,
      this.playlist,
      this.calledFromPlayer = false,
      this.calledFromQueue = false});
  final MediaItem song;
  final Playlist? playlist;
  final bool calledFromPlayer;
  final bool calledFromQueue;

  bool get _isYouTubeServer {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    return server?.type == ServerType.youtubeMusic;
  }

  Album? _matchAlbumFromLibrary() {
    final albumName = (song.album ?? '').trim().toLowerCase();
    if (albumName.isEmpty || !Get.isRegistered<LibraryAlbumsController>()) {
      return null;
    }
    final songArtist = (song.artist ?? '').trim().toLowerCase();
    final albums = Get.find<LibraryAlbumsController>().libraryAlbums;
    for (final album in albums) {
      final title = album.title.trim().toLowerCase();
      if (title != albumName) continue;
      if (songArtist.isEmpty) return album;
      final artistNames = (album.artists ?? [])
          .map((a) => (a['name'] ?? '').toString().trim().toLowerCase())
          .where((n) => n.isNotEmpty)
          .toList();
      if (artistNames.isEmpty ||
          artistNames
              .any((a) => songArtist.contains(a) || a.contains(songArtist))) {
        return album;
      }
    }
    return null;
  }

  void _openAlbum(BuildContext context) {
    final albumExtras = song.extras?['album'];
    final albumId = (albumExtras is Map ? albumExtras['id'] : null)?.toString();
    final validAlbumId = albumId != null && albumId.trim().isNotEmpty;
    final matchedAlbum = _matchAlbumFromLibrary();
    final targetId = validAlbumId ? albumId : (matchedAlbum?.browseId ?? '');

    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(context, context.l10n.operationFailed,
            size: SnackBarSize.MEDIUM),
      );
      return;
    }

    ScreenNavigationSetup.openContentRouteSmart(
      ScreenNavigationSetup.albumScreen,
      arguments: (matchedAlbum, targetId),
    );
  }

  Artist? _matchArtistByName(String name) {
    if (!Get.isRegistered<LibraryArtistsController>()) return null;
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final artist in Get.find<LibraryArtistsController>().libraryArtists) {
      if (artist.name.trim().toLowerCase() == normalized) return artist;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final songInfoController =
        Get.put(SongInfoController(song, calledFromPlayer));
    final playerController = Get.find<PlayerController>();
    return Padding(
      padding: EdgeInsets.only(bottom: Get.mediaQuery.padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.only(left: 15, top: 7, right: 10, bottom: 0),
              leading: ImageWidget(
                song: song,
                size: 50,
              ),
              title: Text(
                song.title,
                maxLines: 1,
              ),
              subtitle: Text(song.artist!),
              trailing: SizedBox(
                width: 110,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    calledFromPlayer
                        ? IconButton(
                            onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => SongInfoDialog(
                                    song: song,
                                  ),
                                ),
                            icon: Icon(
                              Icons.info,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .color,
                            ))
                        : IconButton(
                            onPressed: songInfoController.toggleFav,
                            icon: Obx(() => Icon(
                                  songInfoController.isCurrentSongFav.isFalse
                                      ? Icons.favorite_border
                                      : Icons.favorite,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .color,
                                ))),
                    SongDownloadButton(
                      song_: song,
                      isDownloadingDoneCallback:
                          songInfoController.setDownloadStatus,
                    )
                  ],
                ),
              ),
            ),
            const Divider(),
            if (_isYouTubeServer)
              ListTile(
                visualDensity: const VisualDensity(vertical: -1),
                leading: const Icon(Icons.sensors),
                title: Text(context.l10n.startRadio),
                onTap: () {
                  Navigator.of(context).pop();
                  playerController.startRadio(song);
                },
              ),
            (calledFromPlayer || calledFromQueue)
                ? const SizedBox.shrink()
                : ListTile(
                    visualDensity: const VisualDensity(vertical: -1),
                    leading: const Icon(Icons.playlist_play),
                    title: Text(context.l10n.playNext),
                    onTap: () {
                      Navigator.of(context).pop();
                      playerController.playNext(song);
                      ScaffoldMessenger.of(context).showSnackBar(snackbar(
                          context, "${context.l10n.playnextMsg} ${song.title}",
                          size: SnackBarSize.BIG));
                    },
                  ),
            ListTile(
              visualDensity: const VisualDensity(vertical: -1),
              leading: const Icon(Icons.playlist_add),
              title: Text(context.l10n.addToPlaylist),
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (context) => AddToPlaylist([song]),
                ).whenComplete(() => Get.delete<AddToPlaylistController>());
              },
            ),
            (calledFromPlayer || calledFromQueue)
                ? const SizedBox.shrink()
                : ListTile(
                    visualDensity: const VisualDensity(vertical: -1),
                    leading: const Icon(Icons.merge),
                    title: Text(context.l10n.enqueueSong),
                    onTap: () {
                      playerController.enqueueSong(song).whenComplete(() {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(snackbar(
                            context, context.l10n.songEnqueueAlert,
                            size: SnackBarSize.MEDIUM));
                      });
                      Navigator.of(context).pop();
                    },
                  ),
            song.extras!['album'] != null
                ? ListTile(
                    visualDensity: const VisualDensity(vertical: -1),
                    leading: const Icon(Icons.album),
                    title: Text(context.l10n.goToAlbum),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (calledFromPlayer) {
                        playerController.playerPanelController.close();
                      }
                      if (calledFromQueue) {
                        playerController.playerPanelController.close();
                      }
                      _openAlbum(context);
                    },
                  )
                : const SizedBox.shrink(),
            ...artistWidgetList(song, context),
            (playlist != null &&
                        !playlist!.isCloudPlaylist &&
                        !(playlist!.playlistId == "LIBRP")) ||
                    (playlist != null && playlist!.isPipedPlaylist)
                ? ListTile(
                    visualDensity: const VisualDensity(vertical: -1),
                    leading: const Icon(Icons.delete),
                    title: playlist!.playlistId == "SongsDownloads"
                        ? Text(context.l10n.removeFromLib)
                        : Text(context.l10n.removeFromPlaylist),
                    onTap: () {
                      Navigator.of(context).pop();
                      songInfoController
                          .removeSongFromPlaylist(song, playlist!)
                          .whenComplete(() => ScaffoldMessenger.of(Get.context!)
                              .showSnackBar(snackbar(Get.context!,
                                  "Removed from ${playlist!.title}",
                                  size: SnackBarSize.MEDIUM)));
                    },
                  )
                : const SizedBox.shrink(),
            (calledFromQueue)
                ? ListTile(
                    visualDensity: const VisualDensity(vertical: -1),
                    leading: const Icon(Icons.delete),
                    title: Text(context.l10n.removeFromQueue),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (playerController.currentSong.value!.id == song.id) {
                        ScaffoldMessenger.of(context).showSnackBar(snackbar(
                            context, context.l10n.songRemovedfromQueueCurrSong,
                            size: SnackBarSize.BIG));
                      } else {
                        playerController.removeFromQueue(song);
                        ScaffoldMessenger.of(context).showSnackBar(snackbar(
                            context, context.l10n.songRemovedfromQueue,
                            size: SnackBarSize.MEDIUM));
                      }
                    })
                : const SizedBox.shrink(),
            Obx(
              () => (songInfoController.isDownloaded.isTrue &&
                      (playlist?.playlistId != "SongDownloads" &&
                          playlist?.playlistId != "SongsCache"))
                  ? ListTile(
                      contentPadding: const EdgeInsets.only(left: 15),
                      visualDensity: const VisualDensity(vertical: -1),
                      leading: const Icon(Icons.delete),
                      title: Text(context.l10n.deleteDownloadData),
                      onTap: () {
                        Navigator.of(context).pop();
                        final box = Hive.box("SongDownloads");
                        Get.find<LibrarySongsController>()
                            .removeSong(song, true,
                                url: box.get(song.id)['url'])
                            .then((value) async {
                          box.delete(song.id).then((value) {
                            if (playlist != null) {
                              Get.find<PlaylistScreenController>(
                                      tag: Key(playlist!.playlistId)
                                          .hashCode
                                          .toString())
                                  .checkDownloadStatus();
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  snackbar(context,
                                      context.l10n.deleteDownloadedDataAlert,
                                      size: SnackBarSize.BIG));
                            }
                          });
                        });
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            if (_isYouTubeServer)
              ListTile(
                leading: const Icon(Icons.open_with),
                title: Text(context.l10n.openIn),
                trailing: SizedBox(
                  width: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        splashRadius: 10,
                        onPressed: () {
                          launchUrl(Uri.parse(
                              "https://youtube.com/watch?v=${song.id}"));
                        },
                        icon: const Icon(Ionicons.logo_youtube),
                      ),
                      IconButton(
                        splashRadius: 10,
                        onPressed: () {
                          launchUrl(Uri.parse(
                              "https://music.youtube.com/watch?v=${song.id}"));
                        },
                        icon: const Icon(Ionicons.play_circle),
                      )
                    ],
                  ),
                ),
              ),
            if (calledFromPlayer)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 15),
                visualDensity: const VisualDensity(vertical: -1),
                leading: const Icon(Icons.timer),
                title: Text(context.l10n.sleepTimer),
                onTap: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    constraints: const BoxConstraints(maxWidth: 500),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10.0)),
                    ),
                    isScrollControlled: true,
                    context:
                        Get.find<ShellController>().overlayContextOrFallback!,
                    barrierColor: Colors.transparent.withAlpha(100),
                    builder: (context) => const SleepTimerBottomSheet(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> artistWidgetList(MediaItem song, BuildContext context) {
    final artistList = [];
    final artists = song.extras!['artists'];
    if (artists != null) {
      for (dynamic each in artists) {
        final name = each['name']?.toString().trim();
        if (name != null && name.isNotEmpty) artistList.add(each);
      }
    }
    return artistList.isNotEmpty
        ? artistList
            .map((e) => ListTile(
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (calledFromPlayer) {
                      Get.find<PlayerController>()
                          .playerPanelController
                          .close();
                    }
                    if (calledFromQueue) {
                      final playerController = Get.find<PlayerController>();
                      playerController.playerPanelController.close();
                    }
                    final artistId = e['id']?.toString();
                    if (artistId != null && artistId.trim().isNotEmpty) {
                      await ScreenNavigationSetup.openContentRouteSmart(
                          ScreenNavigationSetup.artistScreen,
                          arguments: [true, artistId]);
                      return;
                    }

                    final matched =
                        _matchArtistByName(e['name']?.toString() ?? '');
                    if (matched != null) {
                      await ScreenNavigationSetup.openContentRouteSmart(
                          ScreenNavigationSetup.artistScreen,
                          arguments: [false, matched]);
                      return;
                    }

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      snackbar(context, context.l10n.operationFailed,
                          size: SnackBarSize.MEDIUM),
                    );
                  },
                  tileColor: Colors.transparent,
                  leading: const Icon(Icons.person),
                  title: Text("${context.l10n.viewArtist} (${e['name']})"),
                ))
            .toList()
        : [const SizedBox.shrink()];
  }
}

class SongInfoController extends GetxController
    with RemoveSongFromPlaylistMixin {
  final isCurrentSongFav = false.obs;
  final MediaItem song;
  final bool calledFromPlayer;
  List artistList = [].obs;
  final isDownloaded = false.obs;
  SongInfoController(this.song, this.calledFromPlayer) {
    _setInitStatus(song);
  }
  _setInitStatus(MediaItem song) async {
    isDownloaded.value = Hive.box(songDownloadsBoxName(currentServerId())).containsKey(song.id);
    final favBox = await Hive.openBox(libFavBoxName(currentServerId()));
    isCurrentSongFav.value = favBox.containsKey(song.id);
    final artists = song.extras!['artists'];
    if (artists != null) {
      for (dynamic each in artists) {
        if (each.containsKey("id") && each['id'] != null) artistList.add(each);
      }
    }
  }

  void setDownloadStatus(bool isDownloaded_) {
    if (isDownloaded_) {
      Future.delayed(const Duration(milliseconds: 100),
          () => isDownloaded.value = isDownloaded_);
    }
  }

  Future<void> toggleFav() async {
    if (calledFromPlayer) {
      final cntrl = Get.find<PlayerController>();
      if (cntrl.currentSong.value == song) {
        cntrl.toggleFavourite();
        isCurrentSongFav.value = !isCurrentSongFav.value;
        return;
      }
    }
    final box = await Hive.openBox(libFavBoxName(currentServerId()));
    isCurrentSongFav.isFalse
        ? box.put(song.id, MediaItemBuilder.toJson(song))
        : box.delete(song.id);
    isCurrentSongFav.value = !isCurrentSongFav.value;
    if (Get.isRegistered<HomeScreenController>()) {
      final homeCtrl = Get.find<HomeScreenController>();
      if (isCurrentSongFav.isTrue) {
        homeCtrl.favoriteCount.value++;
      } else {
        homeCtrl.favoriteCount.value--;
      }
    }
    if (Get.find<SettingsScreenController>()
            .autoDownloadFavoriteSongEnabled
            .isTrue &&
        isCurrentSongFav.isTrue) {
      Get.find<Downloader>().download(song);
    }
  }
}

mixin RemoveSongFromPlaylistMixin {
  Future<void> removeSongFromPlaylist(MediaItem item, Playlist playlist) async {
    final box = await Hive.openBox(playlist.playlistId);
    //Library songs case
    if (playlist.playlistId == "SongsCache") {
      if (!box.containsKey(item.id)) {
        Hive.box(songDownloadsBoxName(currentServerId())).delete(item.id);
        Get.find<LibrarySongsController>().removeSong(item, true);
      } else {
        Get.find<LibrarySongsController>().removeSong(item, false);
        box.delete(item.id);
      }
    } else if (playlist.playlistId == "SongDownloads") {
      box.delete(item.id);
      Get.find<LibrarySongsController>().removeSong(item, true);
    } else if (!playlist.isPipedPlaylist) {
      //Other playlist song case
      final index =
          box.values.toList().indexWhere((ele) => ele['videoId'] == item.id);
      await box.deleteAt(index);
    }

    // this try catch block is to handle the case when song is removed from libsongs sections
    try {
      final plstCntroller = Get.find<PlaylistScreenController>(
          tag: Key(playlist.playlistId).hashCode.toString());
      if (playlist.isPipedPlaylist) {
        final res = await Get.find<PipedServices>()
            .getPlaylistSongs(playlist.playlistId);
        final songIndex = res.indexWhere((element) => element.id == item.id);
        if (songIndex != -1) {
          final res = await Get.find<PipedServices>()
              .removeFromPlaylist(playlist.playlistId, songIndex);
          if (res.code == 1) {
            plstCntroller.addNRemoveItemsinList(item, action: 'remove');
          }
        }
        return;
      }

      try {
        plstCntroller.addNRemoveItemsinList(item, action: 'remove');
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=songInfo.removeFromPlaylist.updateController] Failed to update playlist controller for playlistId=${playlist.playlistId}, songId=${item.id}: $e\n$st');
      }
    } catch (e) {
      printERROR("Some Error in removeSongFromPlaylist (might irrelavant): $e");
    }

    if (playlist.playlistId == "SongDownloads" ||
        playlist.playlistId == "SongsCache") {
      return;
    }
    box.close();
  }
}
