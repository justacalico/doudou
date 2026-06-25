import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '/models/server.dart';
import '/models/album.dart';
import '/models/playlist.dart';
import '/ui/constants/doudou_design.dart';
import '../Library/library_browse_screen.dart';
import '../Library/library_controller.dart';
import '../Library/library.dart';
import '../Search/search_screen.dart';
import '/ui/constants/layout.dart';
import '/utils/app_l10n.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/player/player_controller.dart';
import '/ui/shell_controller.dart';
import '/services/tv_service.dart';
import '/ui/widgets/create_playlist_dialog.dart';
import '../../navigator.dart';
import '../../widgets/library_section_builders.dart';
import 'home_screen_controller.dart';
import '../Settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _tabCount = 8;

  Widget _buildTab(int index, bool useBottomNav) {
    if (index == 0) {
      return const Body();
    } else if (index == 1) {
      return const SearchScreen();
    } else if (index == 2) {
      return LibraryBrowseScreen(
        onSwitchToTab:
            useBottomNav ? null : (i) => Get.find<HomeScreenController>()
                .onSideBarTabSelected(3 + i),
      );
    } else if (index == 3) {
      return useBottomNav
          ? const SettingsScreen(isBottomNavActive: true)
          : const SongsLibraryWidget();
    } else if (index == 4) {
      return const PlaylistNAlbumLibraryWidget(isAlbumContent: false);
    } else if (index == 5) {
      return const PlaylistNAlbumLibraryWidget();
    } else if (index == 6) {
      return const LibraryArtistWidget();
    } else if (index == 7) {
      return const SettingsScreen();
    } else {
      return Center(child: Text("$index"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final homeScreenController = Get.find<HomeScreenController>();
    final shellController = Get.find<ShellController>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        floatingActionButton: Obx(
          () => ((homeScreenController.tabIndex.value == 0 &&
                          !GetPlatform.isDesktop) ||
                      homeScreenController.tabIndex.value == 4) &&
                  !shellController.useBottomNav.value &&
                  !(Get.isRegistered<TvService>() && Get.find<TvService>().isTV.value)
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
                              if (homeScreenController.tabIndex.value == 4) {
                                showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const CreateNRenamePlaylistPopup());
                              } else {
                                ScreenNavigationSetup.openContentRouteSmart(
                                    ScreenNavigationSetup.searchScreen);
                              }
                            },
                            child: Icon(homeScreenController.tabIndex.value == 4
                                ? Icons.add
                                : Icons.search)),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        body: Obx(() {
          final tab = homeScreenController.tabIndex.value;
          return _LazyIndexedStack(
            index: tab,
            itemCount: _tabCount,
            itemBuilder: (i) => _buildTab(i, shellController.useBottomNav.value),
          );
        }),
      ),
    );
  }
}

class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int index;
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<Widget?> _cache =
      List<Widget?>.filled(widget.itemCount, null, growable: false);

  @override
  void initState() {
    super.initState();
    _ensureBuilt(widget.index);
  }

  @override
  void didUpdateWidget(covariant _LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _ensureBuilt(widget.index);
    }
  }

  void _ensureBuilt(int index) {
    final safeIndex = index.clamp(0, widget.itemCount - 1);
    if (_cache[safeIndex] == null) {
      _cache[safeIndex] = widget.itemBuilder(safeIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index.clamp(0, widget.itemCount - 1),
      children: List<Widget>.generate(
        widget.itemCount,
        (i) => _cache[i] ?? const SizedBox.shrink(),
      ),
    );
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
    final leftPadding = useBottomNav
        ? kContentLeftPaddingWithBottomNav
        : kContentLeftPaddingWithoutBottomNav;
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: topPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Obx(() {
                    final libSongs = Get.find<LibrarySongsController>();
                    final libAlbums = Get.find<LibraryAlbumsController>();
                    final libArtists = Get.find<LibraryArtistsController>();
                    final libPlaylists = Get.find<LibraryPlaylistsController>();
                    final settings = Get.find<SettingsScreenController>();
                    final server = settings.activeServer;
                    final isYouTubeMusic = server?.type == ServerType.youtubeMusic;
                    
                    final hasLibraryContent =
                        libSongs.librarySongsList.isNotEmpty ||
                            libAlbums.libraryAlbums.isNotEmpty ||
                            libArtists.libraryArtists.isNotEmpty ||
                            libPlaylists.libraryPlaylists.length > 4;
                    
                    if (isYouTubeMusic) {
                      // Load YouTube Music home feed for all YT Music users
                      if (homeScreenController.youtubeMusicHomeContent.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          homeScreenController.loadYoutubeMusicHomeFeed();
                        });
                      }

                      final playerController = Get.find<PlayerController>();

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 24,
                            right: kContentRightPadding,
                            bottom: useBottomNav
                                ? kContentBottomPaddingWithBottomNav
                                : kContentBottomPaddingWithPlayer,
                          ),
                          child: FutureBuilder<HomeLibrarySections>(
                            future: homeScreenController.loadHomeLibrarySections(),
                            builder: (context, snapshot) {
                              final sections = snapshot.data;
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
                                _buildHomeQuickActionCards(
                                  context: context,
                                  libSongs: libSongs,
                                  homeScreenController: homeScreenController,
                                  isYouTubeMusic: isYouTubeMusic,
                                ),
                              );
                              content.add(const SizedBox(height: 24));

                              // Personalized: Your favorites
                              if (resolved.favoriteSongs.isNotEmpty) {
                                content.add(
                                  buildTrackRowSection(
                                    context: context,
                                    title: context.l10n.favorites,
                                    subtitle: context.l10n.shuffleFavorites,
                                    items: resolved.favoriteSongs.take(10).toList(),
                                    playLabel: context.l10n.favorites,
                                    playerController: playerController,
                                  ),
                                );
                                content.add(const SizedBox(height: 32));
                              }

                              // Personalized: Continue listening
                              if (resolved.continueListening.isNotEmpty) {
                                content.add(
                                  buildTrackRowSection(
                                    context: context,
                                    title: context.l10n.homeContinueListening,
                                    subtitle: context
                                        .l10n.homeContinueListeningSubtitle,
                                    items: resolved.continueListening,
                                    playLabel:
                                        context.l10n.homeContinueListening,
                                    playerController: playerController,
                                    showViewAll: true,
                                  ),
                                );
                                content.add(const SizedBox(height: 32));
                              }

                              // Personalized: Based on favorites
                              if (resolved.basedOnFavorites.isNotEmpty) {
                                content.add(
                                  buildTrackRowSection(
                                    context: context,
                                    title: context.l10n.homeBecauseYouLikeArtists,
                                    subtitle: context
                                        .l10n.homeBecauseYouLikeArtistsSubtitle,
                                    items: resolved.basedOnFavorites,
                                    playLabel:
                                        context.l10n.homeBecauseYouLikeArtists,
                                    playerController: playerController,
                                  ),
                                );
                                content.add(const SizedBox(height: 32));
                              }

                              // Personalized: Fresh picks
                              if (resolved.freshPicks.isNotEmpty) {
                                content.add(
                                  buildFreshPicksSection(
                                    context: context,
                                    items: resolved.freshPicks,
                                    playerController: playerController,
                                  ),
                                );
                                content.add(const SizedBox(height: 32));
                              }

                              // Personalized: Your artists
                              if (resolved.artistsToExplore.isNotEmpty) {
                                content.add(
                                  buildArtistRowSection(
                                    context: context,
                                    title: context.l10n.yourArtists,
                                    subtitle: context.l10n.homeArtistsSubtitle,
                                    artists: resolved.artistsToExplore,
                                  ),
                                );
                                content.add(const SizedBox(height: 32));
                              }

                              // Personalized: Latest albums
                              if (resolved.latestAlbums.isNotEmpty) {
                                content.add(
                                  buildAlbumRowSection(
                                    context: context,
                                    title: context.l10n.recentlyAddedAlbums,
                                    subtitle:
                                        context.l10n.yourNewestAdditions,
                                    albums: resolved.latestAlbums,
                                  ),
                                );
                                content.add(const SizedBox(height: 32));
                              }

                              // YouTube Music generic feed sections
                              content.add(
                                Obx(() {
                                  if (homeScreenController
                                      .isLoadingYoutubeMusicHome.value) {
                                    return const Padding(
                                      padding: EdgeInsets.all(48),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final ytContent = homeScreenController
                                      .youtubeMusicHomeContent;
                                  if (ytContent.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: _buildYoutubeMusicHomeSections(
                                      ytContent,
                                      context,
                                      playerController,
                                    ),
                                  );
                                }),
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: content,
                              );
                            },
                          ),
                        ),
                      );
                    }
                    
                    if (!hasLibraryContent) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 24,
                            right: kContentRightPadding,
                            bottom: useBottomNav
                                ? kContentBottomPaddingWithBottomNav
                                : kContentBottomPaddingWithPlayer,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHomeQuickActionCards(
                                context: context,
                                libSongs: libSongs,
                                homeScreenController: homeScreenController,
                                isYouTubeMusic: isYouTubeMusic,
                              ),
                              const SizedBox(height: 48),
                              Center(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    context.l10n.addMusicToLibraryHint,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                            ],
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
                            snapshot.connectionState ==
                                ConnectionState.waiting;

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
                          _buildHomeQuickActionCards(
                            context: context,
                            libSongs: libSongs,
                            homeScreenController: homeScreenController,
                            isYouTubeMusic: isYouTubeMusic,
                          ),
                        );
                        content.add(const SizedBox(height: 24));

                        if (resolved.continueListening.isNotEmpty) {
                          content.add(
                            buildTrackRowSection(
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
                            buildTrackRowSection(
                              context: context,
                              title: context.l10n.homeBecauseYouLikeArtists,
                              subtitle:
                                  context.l10n.homeBecauseYouLikeArtistsSubtitle,
                              items: resolved.basedOnFavorites,
                              playLabel:
                                  context.l10n.homeBecauseYouLikeArtists,
                              playerController: playerController,
                            ),
                          );
                          content.add(const SizedBox(height: 32));
                        }

                        if (resolved.playlistsFromCollection.isNotEmpty) {
                          content.add(
                            buildPlaylistRowSection(
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
                            buildAlbumRowSection(
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
                            buildArtistRowSection(
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
                            buildFreshPicksSection(
                              context: context,
                              items: resolved.freshPicks,
                              playerController: playerController,
                            ),
                          );
                        }

                        final hasAnySectionContent =
                            resolved.continueListening.isNotEmpty ||
                            resolved.basedOnFavorites.isNotEmpty ||
                            resolved.playlistsFromCollection.isNotEmpty ||
                            resolved.latestAlbums.isNotEmpty ||
                            resolved.artistsToExplore.isNotEmpty ||
                            resolved.freshPicks.isNotEmpty;

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
                        } else if (!hasAnySectionContent) {
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

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 24,
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeQuickActionCards({
    required BuildContext context,
    required LibrarySongsController libSongs,
    required HomeScreenController homeScreenController,
    required bool isYouTubeMusic,
  }) {
    final shuffleCount = libSongs.librarySongsList.length;
    final downloadCount = homeScreenController.downloadedSongsCount.value;
    
    final cards = <Widget>[];
    
    if (isYouTubeMusic) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.radio,
          label: context.l10n.startRadio,
          subtitle: '',
          onTap: () {
            homeScreenController.startRadio();
          },
        ),
      );
    } else if (shuffleCount > 0) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.shuffle,
          label: context.l10n.shuffleAll,
          subtitle: '$shuffleCount ${context.l10n.songsCount}',
          onTap: () {
            homeScreenController.shuffleAll(
              emptyMessage: context.l10n.noSongsInLibrary,
              playFromName: context.l10n.shuffleAll,
            );
          },
        ),
      );
    }
    
    if (homeScreenController.favoriteCount.value > 0) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.favorite,
          label: context.l10n.favorites,
          subtitle: context.l10n.shuffleFavorites,
          onTap: () {
            homeScreenController.shuffleFavorites(
              emptyMessage: context.l10n.favoritesEmpty,
              playFromName: context.l10n.favorites,
            );
          },
        ),
      );
    }
    
    if (downloadCount > 0) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.download,
          label: context.l10n.downloads,
          subtitle: '$downloadCount ${context.l10n.songsCount}',
          onTap: () {
            homeScreenController.shuffleDownloads(
              emptyMessage: context.l10n.noOfflineSong,
              playFromName: context.l10n.downloads,
            );
          },
        ),
      );
    }
    
    if (cards.isEmpty) return const SizedBox.shrink();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 24) / cards.length;
        final compact = cardWidth < 180;
        return Row(
          children: List.generate(cards.length * 2 - 1, (index) {
            if (index.isEven) {
              final card = cards[index ~/ 2] as _HomeQuickActionCard;
              return Expanded(
                child: _HomeQuickActionCard(
                  icon: card.icon,
                  label: card.label,
                  subtitle: card.subtitle,
                  compact: compact,
                  onTap: card.onTap,
                ),
              );
            } else {
              return const SizedBox(width: 12);
            }
          }),
        );
      },
    );
  }

  List<Widget> _buildYoutubeMusicHomeSections(
    List sections,
    BuildContext context,
    PlayerController playerController,
  ) {
    final content = <Widget>[];
    
    for (var section in sections) {
      if (section is Map && section.containsKey('title') && section.containsKey('contents')) {
        final title = section['title'] as String;
        final items = section['contents'] as List;
        
        if (items.isEmpty) continue;
        
        // Check the type of the first item to determine which builder to use
        final firstItem = items.first;
        
        if (firstItem is MediaItem) {
          content.add(
            buildTrackRowSection(
              context: context,
              title: title,
              subtitle: '',
              items: items.whereType<MediaItem>().toList(),
              playLabel: title,
              playerController: playerController,
              showViewAll: false,
            ),
          );
          content.add(const SizedBox(height: 32));
        } else if (firstItem is Playlist) {
          content.add(
            buildPlaylistRowSection(
              context: context,
              title: title,
              subtitle: '',
              playlists: items.whereType<Playlist>().toList(),
            ),
          );
          content.add(const SizedBox(height: 32));
        } else if (firstItem is Album) {
          content.add(
            buildAlbumRowSection(
              context: context,
              title: title,
              subtitle: '',
              albums: items.whereType<Album>().toList(),
            ),
          );
          content.add(const SizedBox(height: 32));
        }
      }
    }
    
    return content;
  }

}

class _HomeQuickActionCard extends StatelessWidget {
  const _HomeQuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.compact = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = onSurface.withValues(alpha: 0.7);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kDoudouRadiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(kDoudouRadiusCard),
        onTap: onTap,
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: kDoudouSurface,
            borderRadius: BorderRadius.circular(kDoudouRadiusCard),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: compact
              ? Center(
                  child: Tooltip(
                    message: label,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kDoudouSurfaceHover,
                        borderRadius:
                            BorderRadius.circular(kDoudouRadiusIconBox),
                      ),
                      child: Icon(icon, color: onSurface, size: 24),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kDoudouSurfaceHover,
                        borderRadius:
                            BorderRadius.circular(kDoudouRadiusIconBox),
                      ),
                      child: Icon(icon, color: onSurface, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
