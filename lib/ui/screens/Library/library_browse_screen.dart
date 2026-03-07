import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/constants/doudou_design.dart';
import '/ui/constants/layout.dart';
import '/utils/app_l10n.dart';
import '/ui/player/player_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/library_section_builders.dart';
import '../Home/home_screen_controller.dart';
import 'library_controller.dart';
import 'library.dart';

class LibraryBrowseScreen extends StatelessWidget {
  const LibraryBrowseScreen({
    super.key,
    this.onSwitchToTab,
  });

  final void Function(int libraryTabIndex)? onSwitchToTab;

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final playerController = Get.find<PlayerController>();
    final useBottomNav = Get.find<ShellController>().useBottomNav.value;
    final leftPadding = useBottomNav
        ? kContentLeftPaddingLibraryWithBottomNav
        : kContentLeftPaddingWithoutBottomNav;

    return FutureBuilder<HomeLibrarySections>(
      future: homeScreenController.loadHomeLibrarySections(),
      builder: (context, snapshot) {
        final sections = snapshot.data;
        final isLoading =
            sections == null && snapshot.connectionState == ConnectionState.waiting;
        final resolved = sections ??
            HomeLibrarySections(
              continueListening: const [],
              basedOnFavorites: const [],
              playlistsFromCollection: const [],
              latestAlbums: const [],
              artistsToExplore: const [],
              freshPicks: const [],
            );

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final content = <Widget>[];
        content.add(const SizedBox(height: 24));

        final theme = Theme.of(context);
        content.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.library,
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
                context.l10n.libraryOverviewSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: kDoudouZinc500,
                ),
              ),
            ],
          ),
        );
        content.add(const SizedBox(height: 24));

        final albumsCount = Get.isRegistered<LibraryAlbumsController>()
            ? Get.find<LibraryAlbumsController>().libraryAlbums.length
            : 0;
        final artistsCount = Get.isRegistered<LibraryArtistsController>()
            ? Get.find<LibraryArtistsController>().libraryArtists.length
            : 0;
        final songsCount = Get.isRegistered<LibrarySongsController>()
            ? Get.find<LibrarySongsController>().librarySongsList.length
            : 0;
        final playlistsCount = Get.isRegistered<LibraryPlaylistsController>()
            ? Get.find<LibraryPlaylistsController>().libraryPlaylists.length
            : 0;
        content.add(
          buildLibraryOverviewCards(
            context,
            albumsCount: albumsCount,
            artistsCount: artistsCount,
            songsCount: songsCount,
            playlistsCount: playlistsCount,
            onSwitchToTab: onSwitchToTab,
          ),
        );
        content.add(const SizedBox(height: 32));

        void onViewAll(int combinedTabIndex) {
          if (onSwitchToTab != null) {
            onSwitchToTab!(combinedTabIndex + 3);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    LibraryListFullScreen(tabIndex: combinedTabIndex),
              ),
            );
          }
        }

        if (resolved.latestAlbums.isNotEmpty) {
          content.add(
            buildAlbumRowSection(
              context: context,
              title: context.l10n.recentlyAddedAlbums,
              subtitle: context.l10n.yourNewestAdditions,
              albums: resolved.latestAlbums,
              showViewAll: true,
              onViewAll: () => onViewAll(2),
            ),
          );
          content.add(const SizedBox(height: 32));
        }

        if (resolved.continueListening.isNotEmpty) {
          content.add(
            buildTrackRowSection(
              context: context,
              title: context.l10n.homeContinueListening,
              subtitle: context.l10n.homeContinueListeningSubtitle,
              items: resolved.continueListening,
              playLabel: context.l10n.homeContinueListening,
              playerController: playerController,
              showViewAll: true,
              onViewAll: () => onViewAll(0),
            ),
          );
          content.add(const SizedBox(height: 32));
        }

        if (resolved.basedOnFavorites.isNotEmpty) {
          content.add(
            buildTrackRowSection(
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
            buildPlaylistRowSection(
              context: context,
              title: context.l10n.playlists,
              subtitle: context.l10n.homePlaylistsSubtitle,
              playlists: resolved.playlistsFromCollection,
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

        final hasAny = resolved.continueListening.isNotEmpty ||
            resolved.basedOnFavorites.isNotEmpty ||
            resolved.playlistsFromCollection.isNotEmpty ||
            resolved.latestAlbums.isNotEmpty ||
            resolved.artistsToExplore.isNotEmpty ||
            resolved.freshPicks.isNotEmpty;

        if (!hasAny) {
          content.add(const SizedBox(height: 24));
          content.add(
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  context.l10n.homeEmptyLibraryMessage,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              left: leftPadding,
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
  }
}
