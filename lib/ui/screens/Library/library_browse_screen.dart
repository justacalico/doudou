import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/constants/layout.dart';
import '/utils/app_l10n.dart';
import '/ui/player/player_controller.dart';
import '/ui/shell_controller.dart';
import '/ui/widgets/library_section_builders.dart';
import '../Home/home_screen_controller.dart';
import 'library_combined.dart';

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

        void onViewAll(int tabIndex) {
          if (onSwitchToTab != null) {
            onSwitchToTab!(tabIndex);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CombinedLibrary(initialTabIndex: tabIndex),
              ),
            );
          }
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

        final hasAny = resolved.continueListening.isNotEmpty ||
            resolved.basedOnFavorites.isNotEmpty ||
            resolved.playlistsFromCollection.isNotEmpty ||
            resolved.latestAlbums.isNotEmpty ||
            resolved.artistsToExplore.isNotEmpty ||
            resolved.freshPicks.isNotEmpty;

        if (!hasAny) {
          return Padding(
            padding: EdgeInsets.only(left: leftPadding, right: kContentRightPadding),
            child: Center(
              child: Text(
                context.l10n.homeEmptyLibraryMessage,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
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
