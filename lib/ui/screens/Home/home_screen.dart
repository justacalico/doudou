import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../Search/components/desktop_search_bar.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/media_Item_builder.dart';
import '/models/playling_from.dart';
import '/models/playlist.dart';
import '/ui/screens/Search/search_screen_controller.dart';
import '/ui/widgets/animated_screen_transition.dart';
import '../Library/library_combined.dart';
import '../Library/library_controller.dart';
import '../Library/library.dart';
import '../Search/search_screen.dart';
import '/ui/constants/layout.dart';
import '/utils/server_storage.dart';
import '../Settings/settings_screen_controller.dart';
import '/models/server.dart';
import '/ui/player/player_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/create_playlist_dialog.dart';
import '../../navigator.dart';
import '../../widgets/content_list_widget.dart';
import '../../widgets/image_widget.dart';
import 'home_screen_controller.dart';
import '../Settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final homeScreenController = Get.find<HomeScreenController>();
    final shellController = Get.find<ShellController>();

    return Scaffold(
        floatingActionButton: Obx(
          () => ((homeScreenController.tabIndex.value == 0 &&
                          !GetPlatform.isDesktop) ||
                      homeScreenController.tabIndex.value == 2) &&
                  !shellController.useBottomNav.value
              ? Obx(
                  () => Padding(
                    padding: EdgeInsets.only(
                        bottom: playerController.playerPanelMinHeight.value >
                                Get.mediaQuery.padding.bottom
                            ? playerController.playerPanelMinHeight.value -
                                Get.mediaQuery.padding.bottom
                            : playerController.playerPanelMinHeight.value),
                    child: SizedBox(
                      height: 60,
                      width: 60,
                      child: FittedBox(
                        child: FloatingActionButton(
                            focusElevation: 0,
                            shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(14))),
                            elevation: 0,
                            onPressed: () async {
                              if (homeScreenController.tabIndex.value == 2) {
                                showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const CreateNRenamePlaylistPopup());
                              } else {
                                ScreenNavigationSetup.pushContentRoute(
                                    ScreenNavigationSetup.searchScreen);
                              }
                              // file:///data/user/0/gitlab.openlyst.doudou/cache/libCachedImageData/
                              //file:///data/user/0/gitlab.openlyst.doudou/cache/just_audio_cache/
                            },
                            child: Icon(homeScreenController.tabIndex.value == 2
                                ? Icons.add
                                : Icons.search)),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        body: Obx(() {
          final settings = Get.find<SettingsScreenController>();
          final factor = settings.animationSpeedFactor;
          final enabled = factor > 0;
          const verticalBaseMs = 380;
          const horizontalBaseMs = 320;
          final baseMs =
              shellController.useBottomNav.value ? horizontalBaseMs : verticalBaseMs;
          final effectiveMs =
              (baseMs * (factor == 0 ? 1.0 : factor)).round();
          return AnimatedScreenTransition(
            enabled: enabled,
            resverse: homeScreenController.reverseAnimationtransiton,
            horizontalTransition: shellController.useBottomNav.value,
            duration: Duration(milliseconds: effectiveMs),
            child: const Body(
              key: ValueKey<int>(0),
            ),
          );
        }));
  }
}

class Body extends StatelessWidget {
  const Body({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final useBottomNav = Get.find<ShellController>().useBottomNav.value;
    final size = MediaQuery.of(context).size;
    final topPadding = GetPlatform.isDesktop
        ? kTopPaddingDesktop
        : context.isLandscape
            ? kTopPaddingLandscape
            : size.height < kLayoutHeightBreakpointNarrow
                ? kTopPaddingNarrow
                : kTopPaddingDesktop;
    final leftPadding = useBottomNav ? kContentLeftPaddingWithBottomNav : kContentLeftPaddingWithoutBottomNav;
    if (homeScreenController.tabIndex.value == 0) {
      return Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (GetPlatform.isDesktop) {
                  final sscontroller = Get.find<SearchScreenController>();
                  if (sscontroller.focusNode.hasFocus) {
                    sscontroller.focusNode.unfocus();
                  }
                }
              },
              child: Obx(() {
                final libSongs = Get.find<LibrarySongsController>();
                final libAlbums = Get.find<LibraryAlbumsController>();
                final libArtists = Get.find<LibraryArtistsController>();
                final libPlaylists = Get.find<LibraryPlaylistsController>();
                final hasLibraryContent =
                    libSongs.librarySongsList.isNotEmpty ||
                        libAlbums.libraryAlbums.isNotEmpty ||
                        libArtists.libraryArtists.isNotEmpty ||
                        libPlaylists.libraryPlaylists.length > 4;
                if (!hasLibraryContent) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height - 180,
                    child: Center(
                      child: Text(
                        "addMusicToLibraryHint".tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  );
                }

                final playerController = Get.find<PlayerController>();
                final settingsController =
                    Get.find<SettingsScreenController>();
                final theme = Theme.of(context);
                final activeServer = settingsController.activeServer;
                final isYouTubeServer =
                    activeServer?.type == ServerType.youtubeMusic;
                final hasLibrarySongs = isYouTubeServer
                    ? libSongs.librarySongsList.isNotEmpty
                    : true;
                final favBoxName = libFavBoxName(currentServerId());
                final hasLocalFavorites = Hive.isBoxOpen(favBoxName)
                    ? Hive.box(favBoxName).length > 0
                    : false;
                final hasFavorites =
                    isYouTubeServer ? hasLocalFavorites : true;
                final hasDownloads = Hive.box("SongDownloads").length > 0;

                final shuffleTrackCount = isYouTubeServer
                    ? libSongs.librarySongsList.length
                    : libSongs.librarySongsList.length;
                const kLibraryCardHeight = 120.0;
                const kLibraryCardGap = 8.0;

                Widget libraryCard({
                  required VoidCallback? onTap,
                  required IconData icon,
                  required String title,
                  required String subtitle,
                  required bool enabled,
                  required String emptyMessage,
                  Color? iconColor,
                  bool useGradient = false,
                }) {
                  final surfaceElevated = theme.colorScheme.surfaceContainerHighest;
                  final primary = theme.colorScheme.primary;
                  final secondary = theme.colorScheme.secondary;
                  final decoration = useGradient && enabled
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primary,
                              primary.withValues(alpha: 0.85),
                              secondary,
                            ],
                          ),
                        )
                      : BoxDecoration(
                          color: surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                        );
                  final fgColor = (useGradient && enabled)
                      ? theme.colorScheme.onPrimary
                      : (enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5));
                  final subColor = (useGradient && enabled)
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.85)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7);
                  final effectiveIconColor = iconColor ?? fgColor;
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: enabled
                          ? onTap
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(emptyMessage)),
                              ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: kLibraryCardHeight,
                        padding: const EdgeInsets.all(14),
                        decoration: decoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              icon,
                              size: 26,
                              color: effectiveIconColor,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: fgColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: subColor,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                String formatTracksInCollection(int count) {
                  final t = "tracksInYourCollection".tr;
                  return t.contains("%s") ? t.replaceFirst("%s", count.toString()) : "$count tracks in your collection";
                }

                String formatShuffleLiked(int count) {
                  final t = "shuffleLikedSongs".tr;
                  return t.contains("%s") ? t.replaceFirst("%s", count.toString()) : "Shuffle $count liked songs";
                }

                return FutureBuilder<HomeLibrarySections>(
                  future: homeScreenController.loadHomeLibrarySections(),
                  builder: (context, snapshot) {
                    final sections = snapshot.data;

                    if (sections == null &&
                        snapshot.connectionState ==
                            ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: topPadding,
                            bottom: useBottomNav
                                ? kContentBottomPaddingWithBottomNav
                                : kContentBottomPaddingWithPlayer,
                          ),
                          child: const CircularProgressIndicator(),
                        ),
                      );
                    }

                    final resolved = sections ??
                        HomeLibrarySections(
                          continueListening: const [],
                          basedOnFavorites: const [],
                          playlistsFromCollection: const [],
                          latestAlbums: const [],
                          artistsToExplore: const [],
                          freshPicks: const [],
                        );

                    final content = <Widget>[];

                    content.add(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "yourLibrary".tr,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: kLibraryCardGap),
                                      child: libraryCard(
                                        useGradient: false,
                                        enabled: hasLibrarySongs,
                                        emptyMessage: "noSongsInLibrary".tr,
                                        onTap: hasLibrarySongs
                                            ? () async {
                                                final messenger =
                                                    ScaffoldMessenger.of(context);
                                                if (isYouTubeServer) {
                                                  final list = libSongs
                                                      .librarySongsList
                                                      .toList();
                                                  if (list.isEmpty) {
                                                    messenger.showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                "noSongsInLibrary".tr)));
                                                    return;
                                                  }
                                                  list.shuffle();
                                                  await playerController
                                                      .playPlayListSong(
                                                    list,
                                                    0,
                                                    playfrom: PlaylingFrom(
                                                      name: "shuffleAll".tr,
                                                      type: PlaylingFromType
                                                          .SELECTION,
                                                    ),
                                                  );
                                                } else {
                                                  final allSongs =
                                                      await libSongs
                                                          .loadAllSongsForShuffle();
                                                  if (allSongs.isEmpty) {
                                                    messenger.showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                "noSongsInLibrary".tr)));
                                                    return;
                                                  }
                                                  final list = allSongs.toList();
                                                  list.shuffle();
                                                  await playerController
                                                      .playPlayListSong(
                                                    list,
                                                    0,
                                                    playfrom: PlaylingFrom(
                                                      name: "shuffleAll".tr,
                                                      type: PlaylingFromType
                                                          .SELECTION,
                                                    ),
                                                  );
                                                }
                                              }
                                            : null,
                                        icon: Icons.shuffle,
                                        title: "shuffleAll".tr,
                                        subtitle: formatTracksInCollection(shuffleTrackCount),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: libraryCard(
                                        enabled: hasFavorites,
                                        emptyMessage: "favoritesEmpty".tr,
                                        onTap: hasFavorites
                                            ? () async {
                                                final messenger =
                                                    ScaffoldMessenger.of(context);
                                                if (isYouTubeServer) {
                                                  final box = Hive.box(favBoxName);
                                                  final list = box.values
                                                      .map<MediaItem?>((e) =>
                                                          MediaItemBuilder.fromJson(
                                                              e as Map))
                                                      .whereType<MediaItem>()
                                                      .toList();
                                                  if (list.isEmpty) {
                                                    messenger.showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                "favoritesEmpty".tr)));
                                                    return;
                                                  }
                                                  list.shuffle();
                                                  await playerController
                                                      .playPlayListSong(
                                                    list,
                                                    0,
                                                    playfrom: PlaylingFrom(
                                                      name: "favorites".tr,
                                                      type: PlaylingFromType
                                                          .PLAYLIST,
                                                    ),
                                                  );
                                                } else {
                                                  final tracks =
                                                      await settingsController
                                                          .currentBackend
                                                          .getFavoriteSongs();
                                                  final list = tracks
                                                      .map<MediaItem?>((e) =>
                                                          MediaItemBuilder.fromJson(
                                                              e))
                                                      .whereType<MediaItem>()
                                                      .toList();
                                                  if (list.isEmpty) {
                                                    messenger.showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                "favoritesEmpty".tr)));
                                                    return;
                                                  }
                                                  list.shuffle();
                                                  await playerController
                                                      .playPlayListSong(
                                                    list,
                                                    0,
                                                    playfrom: PlaylingFrom(
                                                      name: "favorites".tr,
                                                      type: PlaylingFromType
                                                          .PLAYLIST,
                                                    ),
                                                  );
                                                }
                                              }
                                            : null,
                                        icon: Icons.favorite_border,
                                        iconColor: hasFavorites
                                            ? theme.colorScheme.error
                                            : null,
                                        title: "favorites".tr,
                                        subtitle: formatShuffleLiked(resolved.favoriteCount),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: kLibraryCardGap),
                                      child: libraryCard(
                                        enabled: hasDownloads,
                                        emptyMessage: "noOfflineSong".tr,
                                        onTap: hasDownloads
                                            ? () async {
                                                final box =
                                                    Hive.box("SongDownloads");
                                                final list = box.values
                                                    .map<MediaItem?>((e) =>
                                                        MediaItemBuilder.fromJson(
                                                            e as Map))
                                                    .whereType<MediaItem>()
                                                    .toList();
                                                list.shuffle();
                                                await playerController
                                                    .playPlayListSong(
                                                  list,
                                                  0,
                                                  playfrom: PlaylingFrom(
                                                    name: "downloads".tr,
                                                    type: PlaylingFromType
                                                        .PLAYLIST,
                                                  ),
                                                );
                                              }
                                            : null,
                                        icon: Icons.download,
                                        iconColor: hasDownloads
                                            ? theme.colorScheme.tertiary
                                            : null,
                                        title: "downloads".tr,
                                        subtitle: "availableOffline".tr,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );

                    content.add(const SizedBox(height: 32));

                    if (resolved.continueListening.isNotEmpty) {
                      content.add(
                        _buildTrackRowSection(
                          context: context,
                          title: "homeContinueListening".tr,
                          subtitle: "homeContinueListeningSubtitle".tr,
                          items: resolved.continueListening,
                          playLabel: "homeContinueListening".tr,
                          playerController: playerController,
                        ),
                      );
                      content.add(const SizedBox(height: 32));
                    }

                    if (resolved.basedOnFavorites.isNotEmpty) {
                      content.add(
                        _buildTrackRowSection(
                          context: context,
                          title: "homeBecauseYouLikeArtists".tr,
                          subtitle: "homeBecauseYouLikeArtistsSubtitle".tr,
                          items: resolved.basedOnFavorites,
                          playLabel: "homeBecauseYouLikeArtists".tr,
                          playerController: playerController,
                        ),
                      );
                      content.add(const SizedBox(height: 32));
                    }

                    if (resolved.playlistsFromCollection.isNotEmpty) {
                      content.add(
                        _buildPlaylistRowSection(
                          context: context,
                          title: "playlists".tr,
                          subtitle: "homePlaylistsSubtitle".tr,
                          playlists: resolved.playlistsFromCollection,
                        ),
                      );
                      content.add(const SizedBox(height: 32));
                    }

                    if (resolved.latestAlbums.isNotEmpty) {
                      content.add(
                        _buildAlbumRowSection(
                          context: context,
                          title: "recentlyAddedAlbums".tr,
                          subtitle: "yourNewestAdditions".tr,
                          albums: resolved.latestAlbums,
                        ),
                      );
                      content.add(const SizedBox(height: 32));
                    }

                    if (resolved.artistsToExplore.isNotEmpty) {
                      content.add(
                        _buildArtistRowSection(
                          context: context,
                          title: "yourArtists".tr,
                          subtitle: "homeArtistsSubtitle".tr,
                          artists: resolved.artistsToExplore,
                        ),
                      );
                      content.add(const SizedBox(height: 32));
                    }

                    if (resolved.freshPicks.isNotEmpty) {
                      content.add(
                        _buildFreshPicksSection(
                          context: context,
                          items: resolved.freshPicks,
                          playerController: playerController,
                        ),
                      );
                    }

                    if (content.length <= 2) {
                      content.add(
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            "homeEmptyLibraryMessage".tr,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: topPadding,
                          right: kContentRightPadding,
                          bottom: useBottomNav
                              ? kContentBottomPaddingWithBottomNav
                              : kContentBottomPaddingWithPlayer,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: content,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            if (GetPlatform.isDesktop)
              Align(
                alignment: Alignment.topCenter,
                child: LayoutBuilder(builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth > 800
                        ? 800
                        : constraints.maxWidth - 40,
                    child: const Padding(
                        padding: EdgeInsets.only(top: 15.0),
                        child: DesktopSearchBar()),
                  );
                }),
              )
          ],
        ),
      );
    } else if (homeScreenController.tabIndex.value == 1) {
      return useBottomNav ? const SearchScreen() : const SongsLibraryWidget();
    } else if (homeScreenController.tabIndex.value == 2) {
      return useBottomNav
          ? const CombinedLibrary()
          : const PlaylistNAlbumLibraryWidget(isAlbumContent: false);
    } else if (homeScreenController.tabIndex.value == 3) {
      return useBottomNav
          ? const SettingsScreen(isBottomNavActive: true)
          : const PlaylistNAlbumLibraryWidget();
    } else if (homeScreenController.tabIndex.value == 4) {
      return const LibraryArtistWidget();
    } else if (homeScreenController.tabIndex.value == 5) {
      return const SettingsScreen();
    } else {
      return Center(
        child: Text("${homeScreenController.tabIndex.value}"),
      );
    }
  }

  List<Widget> getWidgetList(
      dynamic list, HomeScreenController homeScreenController) {
    return list
        .map((content) {
          final scrollController = ScrollController();
          homeScreenController.contentScrollControllers.add(scrollController);
          return ContentListWidget(
              content: content, scrollController: scrollController);
        })
        .whereType<Widget>()
        .toList();
  }

  Widget _buildTrackRowSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<MediaItem> items,
    required String playLabel,
    required PlayerController playerController,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final track = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < items.length - 1 ? 12 : 0,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    playerController.playPlayListSong(
                      items,
                      index,
                      playfrom: PlaylingFrom(
                        name: playLabel,
                        type: PlaylingFromType.SELECTION,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 280,
                    child: Row(
                      children: [
                        const SizedBox(width: 2),
                        ImageWidget(
                          song: track,
                          size: 56,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${track.artist ?? 'unknownArtist'.tr} • ${track.album ?? 'unknownAlbum'.tr}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistRowSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Playlist> playlists,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < playlists.length - 1 ? 12 : 0,
                ),
                child: SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ImageWidget(
                          playlist: playlist,
                          size: 180,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumRowSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Album> albums,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              final artistName = (album.artists != null &&
                      album.artists!.isNotEmpty &&
                      (album.artists![0]['name'] as String?) != null)
                  ? album.artists![0]['name'] as String
                  : "unknownArtist".tr;
              return Padding(
                padding: EdgeInsets.only(
                  right: index < albums.length - 1 ? 12 : 0,
                ),
                child: SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ImageWidget(
                          album: album,
                          size: 180,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtistRowSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Artist> artists,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < artists.length - 1 ? 12 : 0,
                ),
                child: SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImageWidget(
                        artist: artist,
                        size: 180,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFreshPicksSection({
    required BuildContext context,
    required List<MediaItem> items,
    required PlayerController playerController,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "homeFreshPicks".tr,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          "yourMusicCollection".tr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: items
              .map(
                (track) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final index = items.indexOf(track);
                      if (index >= 0) {
                        playerController.playPlayListSong(
                          items,
                          index,
                          playfrom: PlaylingFrom(
                            name: "homeFreshPicks".tr,
                            type: PlaylingFromType.SELECTION,
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        ImageWidget(
                          song: track,
                          size: 56,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${track.artist ?? 'unknownArtist'.tr} • ${track.album ?? 'unknownAlbum'.tr}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (track.duration != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(track.duration!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
