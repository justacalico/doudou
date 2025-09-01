import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../partials/tracks/track_list_item.dart';
import '../partials/player/mini_player.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Filter tracks to only show favorites
        final favoriteTracks = appState.tracks.where((track) => track.isFavorite).toList();

        if (favoriteTracks.isEmpty) {
          return Container(
            color: const Color(0xFF000000), // Pure black for OLED
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.heart,
                    size: 80,
                    color: Color(0xFF333333),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No favorite songs',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Songs you love will appear here. Tap the heart icon to add songs to your favorites.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8E8E93),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: const Color(0xFF000000), // Dark background
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () => appState.loadLibraryData(),
                  ),
                  // Header with Play and Shuffle buttons
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF453A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFF453A).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.heart_fill,
                                  color: Color(0xFFFF453A),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Favorites',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFFFFFF),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${favoriteTracks.length} song${favoriteTracks.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF453A), Color(0xFFFF6B6B)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF453A).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CupertinoButton(
                                    onPressed: () => _playAllFavorites(context),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.play_fill,
                                          color: Color(0xFFFFFFFF),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Play All',
                                          style: TextStyle(
                                            color: Color(0xFFFFFFFF),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1E),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF333333),
                                      width: 1,
                                    ),
                                  ),
                                  child: CupertinoButton(
                                    onPressed: () => _shuffleFavorites(context),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.shuffle,
                                          color: Color(0xFFFFFFFF),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Shuffle',
                                          style: TextStyle(
                                            color: Color(0xFFFFFFFF),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
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
                  // Add bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
              // Mini player at bottom
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MiniPlayer(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _playTrack(BuildContext context, Track track, int index) {
    final appState = context.read<AppState>();
    final favoriteTracks = appState.tracks.where((track) => track.isFavorite).toList();
    appState.playPlaylist(favoriteTracks, index);
  }

  void _playAllFavorites(BuildContext context) {
    final appState = context.read<AppState>();
    final favoriteTracks = appState.tracks.where((track) => track.isFavorite).toList();
    
    if (favoriteTracks.isNotEmpty) {
      appState.playPlaylist(favoriteTracks, 0);
    }
  }

  void _shuffleFavorites(BuildContext context) {
    final appState = context.read<AppState>();
    final favoriteTracks = appState.tracks.where((track) => track.isFavorite).toList();
    
    if (favoriteTracks.isNotEmpty) {
      final shuffledTracks = List<Track>.from(favoriteTracks)..shuffle();
      appState.playPlaylist(shuffledTracks, 0);
    }
  }
}
