import 'dart:ui';
import '/utils/app_l10n.dart';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/playling_from.dart';
import '/models/thumbnail.dart';
import '/ui/constants/layout.dart';
import '/ui/widgets/playlist_album_scroll_behaviour.dart';
import '../../../services/downloader.dart';
import '../../navigator.dart';
import '../../player/player_controller.dart';
import '../../shell_controller.dart';
import '../../widgets/create_playlist_dialog.dart';
import '../../widgets/loader.dart';
import '../../widgets/library_bookmark_icon.dart';
import '../../widgets/playlist_export_dialog.dart';
import '../../widgets/snackbar.dart';
import '../../widgets/song_list_tile.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../../widgets/sort_widget.dart';
import 'playlist_screen_controller.dart';

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tag = key.hashCode.toString();
    final playlistController =
        (Get.isRegistered<PlaylistScreenController>(tag: tag))
            ? Get.find<PlaylistScreenController>(tag: tag)
            : Get.put(PlaylistScreenController(), tag: tag);
    final size = MediaQuery.of(context).size;
    final playerController = Get.find<PlayerController>();
    final landscape = size.width > size.height;
    final isDesktop = Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows;
    final headerHeight =
        isDesktop ? size.height * 0.4 : (landscape ? size.height : size.width);
    final showMetaOverlay = !landscape || isDesktop;
    final theme = Theme.of(context);
    final useBottomNav = Get.find<ShellController>().useBottomNav.value;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          final scrollOffset = scrollInfo.metrics.pixels;
          playlistController.scrollOffset.value = scrollOffset;
          playlistController.appBarTitleVisible.value =
              scrollOffset > (headerHeight * 0.55);
          return true;
        },
        child: Stack(
          children: [
            // Main Content
            Obx(() => ScrollConfiguration(
                  behavior: PlaylistAlbumScrollBehaviour(),
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                        bottom: useBottomNav
                            ? kContentBottomPaddingWithBottomNav
                            : 120),
                    itemCount: playlistController.isContentFetched.isFalse
                        ? 1
                        : (playlistController.songList.isEmpty
                            ? 4
                            : playlistController.songList.length + 3),
                    itemBuilder: (context, index) {
                      if (playlistController.isContentFetched.isFalse) {
                        return const SizedBox(
                            height: 300,
                            child: Center(child: LoadingIndicator()));
                      }

                      if (index == 0) {
                        return _buildPlaylistHero(
                          context: context,
                          playlistController: playlistController,
                          headerHeight: headerHeight,
                          showMetaOverlay: showMetaOverlay,
                          theme: theme,
                        );
                      }

                      if (index == 1) {
                        // Action Buttons Row
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 16),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  final add = playlistController
                                      .isAddedToLibrary.isFalse;
                                  final l10n = context.l10n;
                                  playlistController
                                      .addNremoveFromLibrary(
                                          playlistController.playlist.value,
                                          add: add)
                                      .then((value) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(snackbar(
                                      context,
                                      value
                                          ? (add
                                              ? l10n.playlistBookmarkAddAlert
                                              : l10n.listBookmarkRemoveAlert)
                                          : l10n.operationFailed,
                                      size: SnackBarSize.MEDIUM,
                                    ));
                                  });
                                },
                                icon: LibraryBookmarkIcon(
                                  isBookmarked:
                                      playlistController.isAddedToLibrary.isTrue,
                                ),
                              ),
                              GetX<Downloader>(builder: (controller) {
                                final id = playlistController
                                    .playlist.value.playlistId;
                                return IconButton(
                                  onPressed: () {
                                    if (playlistController
                                        .isDownloaded.isTrue) {
                                      return;
                                    }
                                    controller.downloadPlaylist(id,
                                        playlistController.songList.toList());
                                  },
                                  icon: playlistController.isDownloaded.isTrue
                                      ? const Icon(Icons.download_done)
                                      : const Icon(
                                          Icons.file_download_outlined),
                                );
                              }),
                              IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) =>
                                        PlaylistExportDialog(
                                      controller: playlistController,
                                      parentContext: context,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.file_upload_outlined),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  final songsToplay = List<MediaItem>.from(
                                      playlistController.songList);
                                  songsToplay.shuffle();
                                  playerController.playPlayListSong(
                                      songsToplay, 0,
                                      playfrom: PlaylingFrom(
                                          name: playlistController
                                              .playlist.value.title,
                                          type: PlaylingFromType.PLAYLIST));
                                },
                                icon: const Icon(Icons.shuffle,
                                    size: 20, color: Colors.white38),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  playerController.playPlayListSong(
                                      List<MediaItem>.from(
                                          playlistController.songList),
                                      0,
                                      playfrom: PlaylingFrom(
                                          name: playlistController
                                              .playlist.value.title,
                                          type: PlaylingFromType.PLAYLIST));
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 10,
                                            offset: Offset(0, 4))
                                      ]),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      color: Colors.black, size: 32),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (index == 2) {
                        // Sorting and Search
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: SortWidget(
                            tag: playlistController.playlist.value.playlistId,
                            screenController: playlistController,
                            isSearchFeatureRequired: true,
                            itemCountTitle:
                                "${playlistController.songList.length}",
                            itemIcon: Icons.music_note,
                            titleLeftPadding: 9,
                            requiredSortTypes: buildSortTypeSet(false, true),
                            onSort: playlistController.onSort,
                            onSearch: playlistController.onSearch,
                            onSearchClose: playlistController.onSearchClose,
                            onSearchStart: playlistController.onSearchStart,
                            startAdditionalOperation:
                                playlistController.startAdditionalOperation,
                            selectAll: playlistController.selectAll,
                            performAdditionalOperation:
                                playlistController.performAdditionalOperation,
                            cancelAdditionalOperation:
                                playlistController.cancelAdditionalOperation,
                          ),
                        );
                      }

                      if (playlistController.songList.isEmpty) {
                        return SizedBox(
                          height: 300,
                          child: Center(child: Text(context.l10n.emptyPlaylist)),
                        );
                      }

                      final songIndex = index - 3;
                      final song = playlistController.songList[songIndex];
                      return Obx(() => SongListTile(
                            onTap: () {
                              playerController.playPlayListSong(
                                  List<MediaItem>.from(
                                      playlistController.songList),
                                  songIndex,
                                  playfrom: PlaylingFrom(
                                      name: playlistController
                                          .playlist.value.title,
                                      type: PlaylingFromType.PLAYLIST));
                            },
                            song: song,
                            isPlaylistOrAlbum: true,
                            thumbReplacementWithIndex: true,
                            index: songIndex + 1,
                            isActive: playerController.currentSong.value?.id ==
                                song.id,
                          ));
                    },
                  ),
                )),

            // Top Navigation Bar
            Obx(
              () => Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX:
                          playlistController.appBarTitleVisible.value ? 10 : 0,
                      sigmaY:
                          playlistController.appBarTitleVisible.value ? 10 : 0,
                    ),
                    child: Container(
                      height: 100,
                      padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top,
                          left: 16,
                          right: 16),
                      color: playlistController.appBarTitleVisible.value
                          ? theme.canvasColor.withValues(alpha: 0.8)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          _blurButton(
                            icon: Icons.chevron_left,
                            onPressed: () => Navigator.of(context).pop(),
                            visible:
                                !playlistController.appBarTitleVisible.value,
                          ),
                          if (playlistController.appBarTitleVisible.value)
                            IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.chevron_left)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Opacity(
                              opacity:
                                  playlistController.appBarTitleVisible.value
                                      ? 1.0
                                      : 0.0,
                              child: Text(
                                playlistController.playlist.value.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          _blurButton(
                            icon: Icons.more_vert,
                            onPressed: () {
                              // Show more options logic from original
                              if (!playlistController
                                      .playlist.value.isCloudPlaylist &&
                                  playlistController
                                      .isDefaultPlaylist.isFalse) {
                                _showMoreOptions(context, playlistController);
                              }
                            },
                            visible:
                                !playlistController.appBarTitleVisible.value,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistHero({
    required BuildContext context,
    required PlaylistScreenController playlistController,
    required double headerHeight,
    required bool showMetaOverlay,
    required ThemeData theme,
  }) {
    final playlist = playlistController.playlist.value;
    final thumbUrl = playlist.thumbnailUrl.trim();
    final effectiveUrl = thumbUrl.isNotEmpty
        ? thumbUrl
        : (playlistController.songList.isNotEmpty
            ? playlistController.songList[0].artUri.toString()
            : "");
    return SizedBox(
      height: headerHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: effectiveUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: Thumbnail(effectiveUrl).extraHigh,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: theme.colorScheme.secondary,
                    child: Center(
                      child: Image.asset("assets/icons/album.png",
                          width: 120, height: 120),
                    ),
                  ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                    theme.canvasColor.withValues(alpha: 0.8),
                    theme.canvasColor,
                  ],
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
          ),
          if (showMetaOverlay)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            context.l10n.playlistTypeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          playlist.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        if (playlist.description != null &&
                            playlist.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            playlist.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMoreOptions(
      BuildContext context, PlaylistScreenController playlistController) {
    showModalBottomSheet(
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      context: Get.find<ShellController>().overlayContextOrFallback!,
      barrierColor: Colors.transparent.withAlpha(100),
      builder: (context) => SizedBox(
        height: 140,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.renamePlaylist),
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (context) => CreateNRenamePlaylistPopup(
                      renamePlaylist: true,
                      playlist: playlistController.playlist.value),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(context.l10n.removePlaylist),
                onTap: () {
                final l10n = context.l10n;
                Navigator.of(context).pop();
                playlistController
                    .addNremoveFromLibrary(playlistController.playlist.value,
                        add: false)
                    .then((value) {
                  Get.nestedKey(ScreenNavigationSetup.id)!.currentState!.pop();
                  ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
                      Get.context!,
                      value ? l10n.playlistRemovedAlert : l10n.operationFailed,
                      size: SnackBarSize.MEDIUM));
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _blurButton(
      {required IconData icon,
      required VoidCallback onPressed,
      bool visible = true}) {
    if (!visible) return const SizedBox(width: 40);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

Future openBottomSheet(BuildContext context, MediaItem song) {
  return showModalBottomSheet(
    constraints: const BoxConstraints(maxWidth: 500),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
    ),
    isScrollControlled: true,
    context: context,
    barrierColor: Colors.transparent.withAlpha(100),
    builder: (context) => SongInfoBottomSheet(song),
  ).whenComplete(() => Get.delete<SongInfoController>());
}
