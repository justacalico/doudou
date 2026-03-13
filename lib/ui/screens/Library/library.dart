import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '/ui/constants/layout.dart';
import '/ui/widgets/snackbar.dart';
import '/ui/widgets/modification_list.dart';
import '../../../models/playlist.dart';
import '../../../models/media_Item_builder.dart';
import '../../widgets/piped_sync_widget.dart';
import 'library_controller.dart';
import '../../widgets/content_list_widget_item.dart';
import '../../widgets/list_widget.dart';
import '../../widgets/sort_widget.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/shell_controller.dart';

class SongsLibraryWidget extends StatelessWidget {
  const SongsLibraryWidget({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    final useBottomNav = isBottomNavActive || Get.find<ShellController>().useBottomNav.value;
    final topPadding = context.isLandscape ? kTopPaddingLandscape : kTopPaddingDefault;
    return Padding(
      padding: useBottomNav
          ? const EdgeInsets.only(left: kContentLeftPaddingLibraryWithBottomNav)
          : EdgeInsets.only(left: kContentLeftPaddingWithoutBottomNav, top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          useBottomNav
              ? const SizedBox(
                  height: 10,
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.libSongs,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
          Obx(() {
            final libSongsController = Get.find<LibrarySongsController>();
            return SortWidget(
              tag: "LibSongSort",
              screenController: libSongsController,
              itemCountTitle: "${libSongsController.librarySongsList.length}",
              itemIcon: Icons.music_note,
              titleLeftPadding: 9,
              requiredSortTypes: buildSortTypeSet(true, true),
              isSearchFeatureRequired: true,
              isSongDeletetioFeatureRequired: true,
              onSort: (type, ascending) {
                libSongsController.onSort(type, ascending);
              },
              onSearch: libSongsController.onSearch,
              onSearchClose: libSongsController.onSearchClose,
              onSearchStart: libSongsController.onSearchStart,
              startAdditionalOperation:
                  libSongsController.startAdditionalOperation,
              selectAll: libSongsController.selectAll,
              performAdditionalOperation:
                  libSongsController.performAdditionalOperation,
              cancelAdditionalOperation:
                  libSongsController.cancelAdditionalOperation,
            );
          }),
          GetX<LibrarySongsController>(builder: (controller) {
            return controller.librarySongsList.isNotEmpty
                ? (controller.additionalOperationMode.value ==
                        OperationMode.none
                    ? ListWidget(
                        controller.librarySongsList,
                        "library Songs",
                        true,
                        isPlaylistOrAlbum: true,
                        playlist: Playlist(
                            title: context.l10n.libSongs,
                            playlistId: "SongsDownloads",
                            thumbnailUrl: "",
                            isCloudPlaylist: false),
                      )
                    : ModificationList(
                        mode: controller.additionalOperationMode.value,
                        screenController: controller,
                      ))
                : Expanded(
                    child: Center(
                        child: Text(
                      context.l10n.noOfflineSong,
                      style: Theme.of(context).textTheme.titleMedium,
                    )),
                  );
          })
        ],
      ),
    );
  }
}

class PlaylistNAlbumLibraryWidget extends StatelessWidget {
  const PlaylistNAlbumLibraryWidget(
      {super.key, this.isAlbumContent = true, this.isBottomNavActive = false});
  final bool isAlbumContent;
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    final libralbumCntrller = Get.find<LibraryAlbumsController>();
    final librplstCntrller = Get.find<LibraryPlaylistsController>();
    final shellController = Get.find<ShellController>();
    final settingscrnController = Get.find<SettingsScreenController>();
    final size = MediaQuery.of(context).size;
    final useBottomNav = shellController.useBottomNav.value;

    const double crossSpacing = 14;
    const double mainSpacing = 16;
    final topPadding = context.isLandscape ? kTopPaddingLandscape : kTopPaddingDefault;

    final isBottomNav = isBottomNavActive || useBottomNav;
    return Padding(
      padding: isBottomNav
          ? const EdgeInsets.only(left: kContentLeftPaddingLibraryWithBottomNav)
          : EdgeInsets.only(top: topPadding),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: kContentLeftPaddingWithoutBottomNav),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                isBottomNav
                    ? const SizedBox(
                        height: 10,
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isAlbumContent ? context.l10n.libAlbums : context.l10n.libPlaylists,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                (useBottomNav ||
                        isAlbumContent ||
                        settingscrnController.isLinkedWithPiped.isFalse)
                    ? const SizedBox.shrink()
                    : PipedSyncWidget(
                        padding: EdgeInsets.only(right: size.width * .05),
                      )
              ],
            ),
          ),
          Obx(
            () => isAlbumContent
                ? SortWidget(
                    tag: "LibAlbumSort",
                    screenController: libralbumCntrller,
                    isAdditionalOperationRequired: false,
                    isSearchFeatureRequired: true,
                    itemCountTitle:
                        "${libralbumCntrller.libraryAlbums.length} ${context.l10n.items}",
                    requiredSortTypes: buildSortTypeSet(true),
                    onSort: (type, ascending) {
                      libralbumCntrller.onSort(type, ascending);
                    },
                    onSearch: libralbumCntrller.onSearch,
                    onSearchClose: libralbumCntrller.onSearchClose,
                    onSearchStart: libralbumCntrller.onSearchStart,
                  )
                : SortWidget(
                    tag: "LibPlaylistSort",
                    screenController: librplstCntrller,
                    isAdditionalOperationRequired: false,
                    isSearchFeatureRequired: true,
                    itemCountTitle:
                        "${librplstCntrller.libraryPlaylists.length} ${context.l10n.items}",
                    requiredSortTypes: buildSortTypeSet(),
                    onSort: (type, ascending) {
                      librplstCntrller.onSort(type, ascending);
                    },
                    onSearch: librplstCntrller.onSearch,
                    onSearchClose: librplstCntrller.onSearchClose,
                    onSearchStart: librplstCntrller.onSearchStart,
                    isImportFeatureRequired: true,
                  ),
          ),
          Expanded(
            child: Obx(
              () => (isAlbumContent
                      ? libralbumCntrller.libraryAlbums.isNotEmpty
                      : librplstCntrller.libraryPlaylists.isNotEmpty)
                  ? LayoutBuilder(builder: (context, constraints) {
                      return GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: crossSpacing,
                            mainAxisSpacing: mainSpacing,
                            childAspectRatio: 0.75,
                          ),
                          scrollDirection: Axis.vertical,
                          padding: const EdgeInsets.only(
                            bottom: kContentBottomPaddingWithPlayer,
                            top: 10,
                          ),
                          itemCount: isAlbumContent
                              ? libralbumCntrller.libraryAlbums.length
                              : librplstCntrller.libraryPlaylists.length,
                          itemBuilder: (context, index) => ContentListItem(
                                content: isAlbumContent
                                    ? libralbumCntrller.libraryAlbums[index]
                                    : librplstCntrller.libraryPlaylists[index],
                                isLibraryItem: true,
                              ));
                    })
                  : Center(
                      child: Text(
                      context.l10n.noBookmarks,
                      style: Theme.of(context).textTheme.titleMedium,
                    )),
            ),
          )
        ],
      ),
    );
  }
}

class LibraryArtistWidget extends StatelessWidget {
  const LibraryArtistWidget({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    final useBottomNav = isBottomNavActive || Get.find<ShellController>().useBottomNav.value;
    final cntrller = Get.find<LibraryArtistsController>();
    final topPadding = context.isLandscape ? kTopPaddingLandscape : kTopPaddingDefault;
    return Padding(
      padding: useBottomNav
          ? const EdgeInsets.only(left: kContentLeftPaddingLibraryWithBottomNav)
          : EdgeInsets.only(left: kContentLeftPaddingWithoutBottomNav, top: topPadding),
      child: Column(
        children: [
          useBottomNav
              ? const SizedBox(
                height: 10,
              )
              : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    context.l10n.libArtists,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
          Obx(
            () => SortWidget(
              tag: "LibArtistSort",
              screenController: cntrller,
              isAdditionalOperationRequired: false,
              isSearchFeatureRequired: true,
              itemCountTitle: "${cntrller.libraryArtists.length} ${context.l10n.items}",
              onSort: (type, ascending) {
                cntrller.onSort(type, ascending);
              },
              onSearch: cntrller.onSearch,
              onSearchClose: cntrller.onSearchClose,
              onSearchStart: cntrller.onSearchStart,
            ),
          ),
          Obx(() => cntrller.libraryArtists.isNotEmpty
              ? ListWidget(cntrller.libraryArtists, "Library Artists", true)
              : Expanded(
                  child: Center(
                      child: Text(
                  context.l10n.noBookmarks,
                  style: Theme.of(context).textTheme.titleMedium,
                ))))
        ],
      ),
    );
  }
}

class DownloadsLibraryWidget extends StatefulWidget {
  const DownloadsLibraryWidget({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  State<DownloadsLibraryWidget> createState() => _DownloadsLibraryWidgetState();
}

class _DownloadsLibraryWidgetState extends State<DownloadsLibraryWidget> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _clearAllDownloads() async {
    final box = Hive.box("SongDownloads");
    final songs = box.values
        .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
        .whereType<MediaItem>()
        .toList();
    final supportDirPath = Get.find<SettingsScreenController>().supportDirPath;

    for (final song in songs) {
      final filePath = song.extras?['url'];
      if (filePath is String && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      final thumbFile = File("$supportDirPath/thumbnails/${song.id}.png");
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    }

    await box.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      snackbar(context, context.l10n.deleteDownloadedDataAlert,
          size: SnackBarSize.MEDIUM),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBottomNav = widget.isBottomNavActive || Get.find<ShellController>().useBottomNav.value;
    final topPadding = context.isLandscape ? kTopPaddingLandscape : kTopPaddingDefault;

    return Padding(
      padding: useBottomNav
          ? const EdgeInsets.only(left: kContentLeftPaddingLibraryWithBottomNav)
          : EdgeInsets.only(left: kContentLeftPaddingWithoutBottomNav, top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          useBottomNav
              ? const SizedBox(height: 10)
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.downloads,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: context.l10n.search,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<Box>(
                  valueListenable: Hive.box("SongDownloads").listenable(),
                  builder: (context, box, _) => IconButton(
                    tooltip: context.l10n.deleteDownloadedDataAlert,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: box.isEmpty
                        ? null
                        : () async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(context.l10n.deleteDownloadData),
                                content: Text(context.l10n.deleteDownloadedDataAlert),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: Text(context.l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    child: Text(context.l10n.deleteDownloadData),
                                  ),
                                ],
                              ),
                            );
                            if (shouldDelete == true) {
                              await _clearAllDownloads();
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<Box>(
            valueListenable: Hive.box("SongDownloads").listenable(),
            builder: (context, box, _) {
              final allSongs = box.values
                  .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
                  .whereType<MediaItem>()
                  .toList();
              final query = _searchController.text.trim().toLowerCase();
              final songs = query.isEmpty
                  ? allSongs
                  : allSongs
                      .where((s) => s.title.toLowerCase().contains(query))
                      .toList();

              if (songs.isEmpty) {
                return Expanded(
                  child: Center(
                    child: Text(
                      context.l10n.noOfflineSong,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              }

              return ListWidget(
                songs,
                context.l10n.downloads,
                true,
                isPlaylistOrAlbum: true,
                playlist: Playlist(
                  title: context.l10n.downloads,
                  playlistId: "SongDownloads",
                  thumbnailUrl: "",
                  isCloudPlaylist: false,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class LibraryListFullScreen extends StatelessWidget {
  const LibraryListFullScreen({super.key, required this.tabIndex});
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final index = tabIndex.clamp(0, 4);
    final titles = [
      context.l10n.songs,
      context.l10n.playlists,
      context.l10n.albums,
      context.l10n.artists,
      context.l10n.downloads,
    ];
    final body = switch (index) {
      0 => const SongsLibraryWidget(isBottomNavActive: true),
      1 => const PlaylistNAlbumLibraryWidget(
          isAlbumContent: false, isBottomNavActive: true),
      2 => const PlaylistNAlbumLibraryWidget(
          isAlbumContent: true, isBottomNavActive: true),
      3 => const LibraryArtistWidget(isBottomNavActive: true),
      4 => const DownloadsLibraryWidget(isBottomNavActive: true),
      _ => const SizedBox.shrink(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: body,
    );
  }
}
