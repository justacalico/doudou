import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/constants/doudou_design.dart';
import '/ui/widgets/animated_screen_transition.dart';
import '../Library/library_browse_screen.dart';
import '../Library/library_controller.dart';
import '../Library/library.dart';
import '../Search/search_screen.dart';
import '/ui/constants/layout.dart';
import '/utils/app_l10n.dart';
import '/utils/helper.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/player/player_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/create_playlist_dialog.dart';
import '../../navigator.dart';
import '../../widgets/library_section_builders.dart';
import 'home_screen_controller.dart';
import '../Settings/settings_screen.dart';

// #region agent log
const bool _enableAgentBuildLogging = false;

void _debugLog(String message, Map<String, dynamic> data, String hypothesisId) {
  if (!_enableAgentBuildLogging) return;
  try {
    final f = File(
        '/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-2cd524.log');
    f.writeAsStringSync(
        '${jsonEncode({
              'sessionId': '2cd524',
              'hypothesisId': hypothesisId,
              'location': 'home_screen.dart',
              'message': sanitizeLogString(message),
              'data': sanitizeLogMap(data),
              'timestamp': DateTime.now().millisecondsSinceEpoch
            })}\n',
        mode: FileMode.append);
  } catch (e, st) {
    printWarning(
        '[RECOVERABLE][opId=home.debugLog.writeFile] Failed to append debug log: $e\n$st');
  }
}
// #endregion

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

    return Scaffold(
        floatingActionButton: Obx(
          () => ((homeScreenController.tabIndex.value == 0 &&
                          !GetPlatform.isDesktop) ||
                      homeScreenController.tabIndex.value == 4) &&
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
            child: _LazyIndexedStack(
              index: tab,
              itemCount: _tabCount,
              itemBuilder: (i) => _buildTab(i, shellController.useBottomNav.value),
            ),
          );
        }));
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
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // #region agent log
          _debugLog(
              'home_tab0_constraints',
              {
                'maxHeight': constraints.maxHeight,
                'maxWidth': constraints.maxWidth,
                'boundedHeight': constraints.maxHeight.isFinite,
              },
              'H1');
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
                    final hasLibraryContent =
                        libSongs.librarySongsList.isNotEmpty ||
                            libAlbums.libraryAlbums.isNotEmpty ||
                            libArtists.libraryArtists.isNotEmpty ||
                            libPlaylists.libraryPlaylists.length > 4;
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

                        content.add(const SizedBox(height: 12));
                        content.add(const SizedBox(height: 24));
                        content.add(
                          _buildHomeQuickActionCards(
                            context: context,
                            libSongs: libSongs,
                            homeScreenController: homeScreenController,
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

                        // #region agent log
                        _debugLog('home_scroll_content',
                            {'contentLength': content.length}, 'H2');
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
                        } else if (content.length <= 5) {
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
                        _debugLog('home_building_scroll_view',
                            {'hasContent': content.isNotEmpty}, 'H4');
                        // #endregion
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
  }) {
    final shuffleCount = libSongs.librarySongsList.length;
    final downloadCount = homeScreenController.downloadedSongsCount.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 24) / 3;
        final compact = cardWidth < 180;
        return Row(
          children: [
            Expanded(
              child: _HomeQuickActionCard(
                icon: Icons.shuffle,
                label: context.l10n.shuffleAll,
                subtitle: '$shuffleCount ${context.l10n.songsCount}',
                compact: compact,
                onTap: () {
                  homeScreenController.shuffleAll(
                    emptyMessage: context.l10n.noSongsInLibrary,
                    playFromName: context.l10n.shuffleAll,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeQuickActionCard(
                icon: Icons.favorite,
                label: context.l10n.favorites,
                subtitle: context.l10n.shuffleFavorites,
                compact: compact,
                onTap: () {
                  homeScreenController.shuffleFavorites(
                    emptyMessage: context.l10n.favoritesEmpty,
                    playFromName: context.l10n.favorites,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeQuickActionCard(
                icon: Icons.download,
                label: context.l10n.downloads,
                subtitle: '$downloadCount ${context.l10n.songsCount}',
                compact: compact,
                onTap: () {
                  homeScreenController.shuffleDownloads(
                    emptyMessage: context.l10n.noOfflineSong,
                    playFromName: context.l10n.downloads,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
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
            border: Border.all(color: kDoudouBorderStrong, width: 1),
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
