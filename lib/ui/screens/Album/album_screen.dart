import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:widget_marquee/widget_marquee.dart';
import 'package:doudou/models/playling_from.dart';
import 'package:doudou/models/thumbnail.dart';
import 'package:doudou/ui/widgets/playlist_album_scroll_behaviour.dart';

import '../../../services/downloader.dart';
import '../../navigator.dart';
import '../../player/player_controller.dart';
import '../../widgets/loader.dart';
import '../../widgets/snackbar.dart';
import '../../widgets/song_list_tile.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../../widgets/sort_widget.dart';
import 'album_screen_controller.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tag = key.hashCode.toString();
    final albumController = (Get.isRegistered<AlbumScreenController>(tag: tag))
        ? Get.find<AlbumScreenController>(tag: tag)
        : Get.put(AlbumScreenController(), tag: tag);
    final size = MediaQuery.of(context).size;
    final playerController = Get.find<PlayerController>();
    final landscape = size.width > size.height;
    final isDesktop = Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows;
    final headerHeight = isDesktop
        ? size.height * 0.4
        : (landscape ? size.height : size.width);
    final showMetaOverlay = !landscape || isDesktop;
    final theme = Theme.of(context);

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          final scrollOffset = scrollInfo.metrics.pixels;
          if (landscape) {
            albumController.scrollOffset.value = 0;
          } else {
            albumController.scrollOffset.value = scrollOffset;
          }
          albumController.appBarTitleVisible.value = scrollOffset > (size.width * 0.8);
          return true;
        },
        child: Stack(
          children: [
            // Background / Header Image
            Obx(() {
              final album = albumController.album.value;
              return albumController.isContentFetched.isTrue
                  ? Positioned(
                      top: landscape ? 0 : -.3 * albumController.scrollOffset.value,
                      left: 0,
                      right: 0,
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: Thumbnail(album.thumbnailUrl).extraHigh,
                            width: size.width,
                            height: headerHeight,
                            fit: BoxFit.cover,
                          ),
                          // Gradient Overlay
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
                          // Meta Info Overlay (only visible when not scrolled much)
                          if (showMetaOverlay)
                            Positioned(
                              bottom: 40,
                              left: 24,
                              right: 24,
                              child: Opacity(
                                opacity: (1 - (albumController.scrollOffset.value / 200)).clamp(0.0, 1.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                          ),
                                          child: Text(
                                            "ALBUM",
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                        if (album.year != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8.0),
                                            child: Text(
                                              "• ${album.year}",
                                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      album.title,
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      album.artists?.map((e) => e['name']).join(", ") ?? "",
                                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink();
            }),

            // Main Content
            Obx(() => ScrollConfiguration(
              behavior: PlaylistAlbumScrollBehaviour(),
              child: ListView.builder(
                padding: EdgeInsets.only(
                  top: isDesktop
                      ? headerHeight - 60
                      : (landscape ? 0 : headerHeight - 60),
                  bottom: 120,
                ),
                itemCount: albumController.isContentFetched.isFalse || albumController.songList.isEmpty
                    ? 1
                    : albumController.songList.length + 2,
                itemBuilder: (context, index) {
                  if (albumController.isContentFetched.isFalse) {
                    return const SizedBox(height: 300, child: Center(child: LoadingIndicator()));
                  }
                  if (albumController.songList.isEmpty) {
                    return SizedBox(height: 300, child: Center(child: Text("emptyPlaylist".tr)));
                  }

                  if (index == 0) {
                    // Action Buttons Row
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              final add = albumController.isAddedToLibrary.isFalse;
                              albumController.addNremoveFromLibrary(albumController.album.value, add: add).then((value) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(snackbar(
                                  context,
                                  value ? (add ? "albumBookmarkAddAlert".tr : "albumBookmarkRemoveAlert".tr) : "operationFailed".tr,
                                  size: SnackBarSize.MEDIUM,
                                ));
                              });
                            },
                            icon: Icon(albumController.isAddedToLibrary.isTrue ? Icons.bookmark : Icons.bookmark_border),
                          ),
                          GetX<Downloader>(builder: (controller) {
                            final id = albumController.album.value.browseId;
                            return IconButton(
                              onPressed: () {
                                if (albumController.isDownloaded.isTrue) return;
                                controller.downloadPlaylist(id, albumController.songList.toList());
                              },
                              icon: albumController.isDownloaded.isTrue ? const Icon(Icons.download_done) : const Icon(Icons.file_download_outlined),
                            );
                          }),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              final songsToplay = List<MediaItem>.from(albumController.songList);
                              songsToplay.shuffle();
                              playerController.playPlayListSong(songsToplay, 0, playfrom: PlaylingFrom(name: albumController.album.value.title, type: PlaylingFromType.ALBUM));
                            },
                            icon: const Icon(Icons.shuffle, size: 20, color: Colors.white38),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              playerController.playPlayListSong(List<MediaItem>.from(albumController.songList), 0, playfrom: PlaylingFrom(name: albumController.album.value.title, type: PlaylingFromType.ALBUM));
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == 1) {
                    // Sorting and Search
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SortWidget(
                        tag: albumController.album.value.browseId,
                        screenController: albumController,
                        isSearchFeatureRequired: true,
                        itemCountTitle: "${albumController.songList.length}",
                        itemIcon: Icons.music_note,
                        titleLeftPadding: 9,
                        requiredSortTypes: buildSortTypeSet(false, true),
                        onSort: albumController.onSort,
                        onSearch: albumController.onSearch,
                        onSearchClose: albumController.onSearchClose,
                        onSearchStart: albumController.onSearchStart,
                        startAdditionalOperation: albumController.startAdditionalOperation,
                        selectAll: albumController.selectAll,
                        performAdditionalOperation: albumController.performAdditionalOperation,
                        cancelAdditionalOperation: albumController.cancelAdditionalOperation,
                      ),
                    );
                  }

                  final songIndex = index - 2;
                  final song = albumController.songList[songIndex];
                  return Obx(() => SongListTile(
                    onTap: () {
                      playerController.playPlayListSong(List<MediaItem>.from(albumController.songList), songIndex, playfrom: PlaylingFrom(name: albumController.album.value.title, type: PlaylingFromType.ALBUM));
                    },
                    song: song,
                    isPlaylistOrAlbum: true,
                    thumbReplacementWithIndex: true,
                    index: songIndex + 1,
                    isActive: playerController.currentSong.value?.id == song.id,
                  ));
                },
              ),
            )),

            // Top Navigation Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: albumController.appBarTitleVisible.value ? 10 : 0,
                    sigmaY: albumController.appBarTitleVisible.value ? 10 : 0,
                  ),
                  child: Container(
                    height: 100,
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16),
                    color: albumController.appBarTitleVisible.value ? theme.canvasColor.withValues(alpha: 0.8) : Colors.transparent,
                    child: Row(
                      children: [
                        _blurButton(
                          icon: Icons.chevron_left,
                          onPressed: () => Navigator.of(context).pop(),
                          visible: !albumController.appBarTitleVisible.value,
                        ),
                        if (albumController.appBarTitleVisible.value)
                          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Opacity(
                            opacity: albumController.appBarTitleVisible.value ? 1.0 : 0.0,
                            child: Text(
                              albumController.album.value.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        _blurButton(
                          icon: Icons.more_vert,
                          onPressed: () {},
                          visible: !albumController.appBarTitleVisible.value,
                        ),
                      ],
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

  Widget _blurButton({required IconData icon, required VoidCallback onPressed, bool visible = true}) {
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

  Widget buildTitleSubTitle(
      BuildContext context, AlbumScreenController albumController) {
    final title = albumController.album.value.title;
    final description = albumController.album.value.description;
    final artistsList = albumController.album.value.artists ?? [];
    final artists =
        artistsList.map((e) => e['name']?.toString() ?? '').join(", ");
    final firstArtistBrowseId = artistsList.isNotEmpty
        ? (artistsList.first['id'] ?? artistsList.first['browseId'])?.toString()
        : null;
    return AnimatedBuilder(
      animation: albumController.animationController,
      builder: (context, child) {
        return SizedBox(
          height: albumController.heightAnimation.value,
          child: Transform.scale(
              scale: albumController.scaleAnimation.value, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 25.0, bottom: 10, right: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Marquee(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(seconds: 5),
              id: title.hashCode.toString(),
              child: Text(
                title.length > 50 ? title.substring(0, 50) : title,
                maxLines: 1,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(fontSize: 30),
              ),
            ),
            Text(
              description ?? "",
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: firstArtistBrowseId != null
                  ? InkWell(
                      onTap: () {
                        ScreenNavigationSetup.pushContentRoute(
                            ScreenNavigationSetup.artistScreen,
                            arguments: [true, firstArtistBrowseId]);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Marquee(
                        delay: const Duration(milliseconds: 300),
                        duration: const Duration(seconds: 5),
                        id: artists.hashCode.toString(),
                        child: Text(
                          artists,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    )
                  : Marquee(
                      delay: const Duration(milliseconds: 300),
                      duration: const Duration(seconds: 5),
                      id: artists.hashCode.toString(),
                      child: Text(
                        artists,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
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
