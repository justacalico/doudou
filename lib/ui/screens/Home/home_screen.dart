import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Search/components/desktop_search_bar.dart';
import '/models/album.dart';
import '/ui/constants/doudou_design.dart';
import '/models/artist.dart';
import '/models/playling_from.dart';
import '/models/playlist.dart';
import '/ui/widgets/animated_screen_transition.dart';
import '../Library/library_combined.dart';
import '../Library/library_controller.dart';
import '../Library/library.dart';
import '../Search/search_screen.dart';
import '/ui/constants/layout.dart';
import '/utils/app_l10n.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/player/player_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/create_playlist_dialog.dart';
import '../../navigator.dart';
import '../../widgets/content_list_widget.dart';
import '../../widgets/image_widget.dart';
import 'home_screen_controller.dart';
import '../Settings/settings_screen.dart';

// #region agent log
void _debugLog(String message, Map<String, dynamic> data, String hypothesisId) {
  try {
    final f = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-2cd524.log');
    f.writeAsStringSync('${jsonEncode({'sessionId':'2cd524','hypothesisId':hypothesisId,'location':'home_screen.dart','message':message,'data':data,'timestamp':DateTime.now().millisecondsSinceEpoch})}\n', mode: FileMode.append);
  } catch (_) {}
}
// #endregion

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
          final tab = homeScreenController.tabIndex.value;
          const verticalBaseMs = 380;
          const horizontalBaseMs = 320;
          final baseMs = shellController.useBottomNav.value
              ? horizontalBaseMs
              : verticalBaseMs;
          final effectiveMs = (baseMs * (factor == 0 ? 1.0 : factor)).round();
          return AnimatedScreenTransition(
            enabled: enabled,
            resverse: homeScreenController.reverseAnimationtransiton,
            horizontalTransition: shellController.useBottomNav.value,
            duration: Duration(milliseconds: effectiveMs),
            child: Body(
              key: ValueKey<int>(tab),
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
    final leftPadding = useBottomNav
        ? kContentLeftPaddingWithBottomNav
        : kContentLeftPaddingWithoutBottomNav;
    if (homeScreenController.tabIndex.value == 0) {
      return Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // #region agent log
            _debugLog('home_tab0_constraints', {
              'maxHeight': constraints.maxHeight,
              'maxWidth': constraints.maxWidth,
              'boundedHeight': constraints.maxHeight.isFinite,
            }, 'H1');
            // #endregion
            return SizedBox.expand(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Obx(() {
              final libSongs = Get.find<LibrarySongsController>();
              final libAlbums = Get.find<LibraryAlbumsController>();
              final libArtists = Get.find<LibraryArtistsController>();
              final libPlaylists = Get.find<LibraryPlaylistsController>();
              final hasLibraryContent = libSongs.librarySongsList.isNotEmpty ||
                  libAlbums.libraryAlbums.isNotEmpty ||
                  libArtists.libraryArtists.isNotEmpty ||
                  libPlaylists.libraryPlaylists.length > 4;
              if (!hasLibraryContent) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height - 180,
                  child: Center(
                    child: Text(
                      context.l10n.addMusicToLibraryHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              }

              final playerController = Get.find<PlayerController>();
              final theme = Theme.of(context);
              // Listen for background refreshes of cached home sections.
              homeScreenController.homeLibrarySectionsVersion.value;

              return FutureBuilder<HomeLibrarySections>(
                future: homeScreenController.loadHomeLibrarySections(),
                builder: (context, snapshot) {
                  final sections = snapshot.data;
                  final isLoading = sections == null &&
                      snapshot.connectionState == ConnectionState.waiting;

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

                  content.add(const SizedBox(height: 32));

                  if (resolved.continueListening.isNotEmpty) {
                    content.add(
                      _buildTrackRowSection(
                        context: context,
                        title: context.l10n.homeContinueListening,
                        subtitle:
                            context.l10n.homeContinueListeningSubtitle,
                        items: resolved.continueListening,
                        playLabel: context.l10n.homeContinueListening,
                        playerController: playerController,
                        showViewAll: true,
                      ),
                    );
                    content.add(const SizedBox(height: 32));
                  }

                  if (resolved.basedOnFavorites.isNotEmpty) {
                    content.add(
                      _buildTrackRowSection(
                        context: context,
                        title: context.l10n.homeBecauseYouLikeArtists,
                        subtitle: context.l10n.homeBecauseYouLikeArtistsSubtitle,
                        items: resolved.basedOnFavorites,
                        playLabel: context.l10n.homeBecauseYouLikeArtists,
                        playerController: playerController,
                      ),
                    );
                    content.add(const SizedBox(height: 32));
                  }

                  if (resolved.playlistsFromCollection.isNotEmpty) {
                    content.add(
                      _buildPlaylistRowSection(
                        context: context,
                        title: context.l10n.playlists,
                        subtitle: context.l10n.homePlaylistsSubtitle,
                        playlists: resolved.playlistsFromCollection,
                      ),
                    );
                    content.add(const SizedBox(height: 32));
                  }

                  if (resolved.latestAlbums.isNotEmpty) {
                    content.add(
                      _buildAlbumRowSection(
                        context: context,
                        title: context.l10n.recentlyAddedAlbums,
                        subtitle: context.l10n.yourNewestAdditions,
                        albums: resolved.latestAlbums,
                      ),
                    );
                    content.add(const SizedBox(height: 32));
                  }

                  if (resolved.artistsToExplore.isNotEmpty) {
                    content.add(
                      _buildArtistRowSection(
                        context: context,
                        title: context.l10n.yourArtists,
                        subtitle: context.l10n.homeArtistsSubtitle,
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

                  // #region agent log
                  _debugLog('home_scroll_content', {'contentLength': content.length}, 'H2');
                  // #endregion
                  if (isLoading) {
                    content.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          context.l10n.loading,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  } else if (content.length <= 2) {
                    content.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          context.l10n.homeEmptyLibraryMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }

                  // #region agent log
                  _debugLog('home_building_scroll_view', {'hasContent': content.isNotEmpty}, 'H4');
                  // #endregion
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
                    width: constraints.maxWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: kDoudouBlurBar,
                          sigmaY: kDoudouBlurBar,
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 15.0),
                            child: DesktopSearchBar(),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              )
          ],
        ),
      );
      },
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
    bool showViewAll = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: kDoudouPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kDoudouZinc500,
                    ),
                  ),
                ],
              ),
            ),
            if (showViewAll)
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: kDoudouPurpleLight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  context.l10n.viewAll.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
          ],
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
                child: Material(
                  color: Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(kDoudouRadiusIconBox),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(kDoudouRadiusIconBox),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.transparent),
                        borderRadius:
                            BorderRadius.circular(kDoudouRadiusIconBox),
                      ),
                      child: SizedBox(
                        width: 280,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ImageWidget(
                                song: track,
                                size: 56,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${track.artist ?? context.l10n.unknownArtist} • ${track.album ?? context.l10n.unknownAlbum}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color: kDoudouZinc500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: kDoudouPurple,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: kDoudouZinc500,
            ),
          ),
        ],
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
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(kDoudouRadiusCard),
                  onTap: () {
                    ScreenNavigationSetup.pushContentRoute(
                      ScreenNavigationSetup.playlistScreen,
                      arguments: [playlist, playlist.playlistId],
                    );
                  },
                  child: SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(kDoudouRadiusCard),
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
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: kDoudouPurple,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: kDoudouZinc500,
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
                  : context.l10n.unknownArtist;
              return Padding(
                padding: EdgeInsets.only(
                  right: index < albums.length - 1 ? 12 : 0,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    ScreenNavigationSetup.pushContentRoute(
                      ScreenNavigationSetup.albumScreen,
                      arguments: (album, album.browseId),
                    );
                  },
                  child: SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(kDoudouRadiusCard),
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
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    ScreenNavigationSetup.pushContentRoute(
                      ScreenNavigationSetup.artistScreen,
                      arguments: [false, artist],
                    );
                  },
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
          context.l10n.homeFreshPicks,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.yourMusicCollection,
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
                            name: context.l10n.homeFreshPicks,
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
                                "${track.artist ?? context.l10n.unknownArtist} • ${track.album ?? context.l10n.unknownAlbum}",
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
