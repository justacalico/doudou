import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../widgets/apple_design/liquid_glass.dart';
import '../partials/tracks/track_list_item.dart';

class FavoritesView extends StatelessWidget {
  final bool showDownloadedOnly;

  const FavoritesView({super.key, this.showDownloadedOnly = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Filter tracks to only show favorites
        List<Track> favoriteTracks =
            appState.tracks.where((track) => track.isFavorite).toList();

        // If coming from downloads page, only show downloaded favorites
        if (showDownloadedOnly) {
          favoriteTracks = favoriteTracks
              .where(
                  (track) => appState.downloadService.isTrackDownloaded(track.id))
              .toList();
        }

        return LiquidGradientBackground(
          child: CupertinoPageScaffold(
            backgroundColor: Colors.transparent,
            navigationBar: CupertinoNavigationBar(
              backgroundColor: Colors.transparent,
              border: null,
              middle: Text(
                showDownloadedOnly ? l10n.downloadedFavorites : l10n.navFavorites,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(
                  CupertinoIcons.back,
                  color: Color(0xFFEC4899),
                ),
              ),
            ),
            child: SafeArea(
              child: favoriteTracks.isEmpty
                  ? _buildEmptyState(l10n)
                  : _buildContent(context, appState, favoriteTracks, l10n),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFFFF6B6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC4899).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.heart_fill,
                      size: 40,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    showDownloadedOnly
                        ? l10n.noDownloadedFavorites
                        : l10n.noFavoriteSongs,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      showDownloadedOnly
                          ? l10n.downloadFavoritesSuggestion
                          : l10n.favoriteSongsDescription,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppState appState,
      List<Track> favoriteTracks, AppLocalizations l10n) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => appState.loadLibraryData(),
        ),
        // Header with stats and buttons
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Stats card
                _buildStatsCard(favoriteTracks.length, l10n),
                const SizedBox(height: 16),
                // Play and Shuffle buttons with liquid glass
                Row(
                  children: [
                    // Play button
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _playAllFavorites(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEC4899),
                                    Color(0xFFFF6B6B),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.play_fill,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.playAll,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Shuffle button
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _shuffleFavorites(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.shuffle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.shuffle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
              ],
            ),
          ),
        ),
        // Songs list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = favoriteTracks[index];
              return TrackListItem(
                track: track,
                onTap: () => _playTrack(context, track, index),
                showAlbumArt: true,
                showTrackNumber: false,
                showDuration: true,
                showDownloadButton: true,
                showFavoriteButton: true,
              );
            },
            childCount: favoriteTracks.length,
          ),
        ),
        // Bottom padding for mini player
        const SliverToBoxAdapter(
          child: SizedBox(height: 150),
        ),
      ],
    );
  }

  Widget _buildStatsCard(int trackCount, AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Heart icon with glow
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFFF6B6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.heart_fill,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showDownloadedOnly
                          ? 'Downloaded Favorites'
                          : 'Your Favorites',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.songsCount(trackCount),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Track count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEC4899).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$trackCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEC4899),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playTrack(BuildContext context, Track track, int index) {
    final appState = context.read<AppState>();
    List<Track> favoriteTracks =
        appState.tracks.where((track) => track.isFavorite).toList();
    if (showDownloadedOnly) {
      favoriteTracks = favoriteTracks
          .where((track) => appState.downloadService.isTrackDownloaded(track.id))
          .toList();
    }
    appState.playPlaylist(favoriteTracks, index);
  }

  void _playAllFavorites(BuildContext context) {
    final appState = context.read<AppState>();
    List<Track> favoriteTracks =
        appState.tracks.where((track) => track.isFavorite).toList();
    if (showDownloadedOnly) {
      favoriteTracks = favoriteTracks
          .where((track) => appState.downloadService.isTrackDownloaded(track.id))
          .toList();
    }

    if (favoriteTracks.isNotEmpty) {
      appState.playPlaylist(favoriteTracks, 0);
    }
  }

  void _shuffleFavorites(BuildContext context) {
    final appState = context.read<AppState>();
    List<Track> favoriteTracks =
        appState.tracks.where((track) => track.isFavorite).toList();
    if (showDownloadedOnly) {
      favoriteTracks = favoriteTracks
          .where((track) => appState.downloadService.isTrackDownloaded(track.id))
          .toList();
    }

    if (favoriteTracks.isNotEmpty) {
      final shuffledTracks = List<Track>.from(favoriteTracks)..shuffle();
      appState.playPlaylist(shuffledTracks, 0);
    }
  }
}
