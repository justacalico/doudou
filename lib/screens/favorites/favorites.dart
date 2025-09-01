import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
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
                        return FavoriteTrackListItem(
                          track: track,
                          onTap: () => _playTrack(context, track, index),
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

class FavoriteTrackListItem extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const FavoriteTrackListItem({
    super.key,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Pure black background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: CupertinoContextMenu(
        actions: [
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(CupertinoIcons.add, size: 18, color: Color(0xFFFFFFFF)),
                SizedBox(width: 8),
                Text('Add to Queue', style: TextStyle(color: Color(0xFFFFFFFF))),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.addToQueue(track);
            },
          ),
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(CupertinoIcons.play_arrow, size: 18, color: Color(0xFFFFFFFF)),
                SizedBox(width: 8),
                Text('Play Next', style: TextStyle(color: Color(0xFFFFFFFF))),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.addNextInQueue(track);
            },
          ),
          CupertinoContextMenuAction(
            child: Row(
              children: [
                Icon(
                  track.isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 18,
                  color: track.isFavorite ? const Color(0xFFFF453A) : const Color(0xFFFFFFFF),
                ),
                const SizedBox(width: 8),
                Text(
                  track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  style: const TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
          ),
        ],
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
              // Album artwork
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1C1C1E),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: track.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: appState.jellyfinService.getImageUrl(
                            track.imageUrl!,
                            width: 112,
                            height: 112,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CupertinoActivityIndicator(
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            CupertinoIcons.music_note,
                            color: Color(0xFF8E8E93),
                            size: 28,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.music_note,
                          color: Color(0xFF8E8E93),
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artistName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.artistName!,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Duration and favorite button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (track.duration != null)
                    Text(
                      _formatDuration(Duration(milliseconds: track.duration!)),
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _toggleFavorite(context, track),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: track.isFavorite 
                            ? const Color(0xFFFF453A).withOpacity(0.1)
                            : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: track.isFavorite 
                              ? const Color(0xFFFF453A).withOpacity(0.3)
                              : const Color(0xFF2C2C2E),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        track.isFavorite 
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: track.isFavorite 
                            ? const Color(0xFFFF453A)
                            : const Color(0xFF8E8E93),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _toggleFavorite(BuildContext context, Track track) {
    final appState = context.read<AppState>();
    appState.toggleFavorite(track);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
