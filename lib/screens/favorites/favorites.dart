import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../widgets/mini_player.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Filter tracks to only show favorites
        final favoriteTracks = appState.tracks.where((track) => track.isFavorite).toList();

        if (appState.isLoading && favoriteTracks.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.white),
          );
        }

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
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              onPressed: () => _playAllFavorites(context),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.play_arrow, color: CupertinoColors.white),
                                  SizedBox(width: 8),
                                  Text('Play All', style: TextStyle(color: CupertinoColors.white)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CupertinoButton(
                              onPressed: () => _shuffleFavorites(context),
                              color: CupertinoColors.systemBackground,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.shuffle, color: const Color(0xFFFF453A)),
                                  const SizedBox(width: 8),
                                  Text('Shuffle', style: TextStyle(color: const Color(0xFFFF453A))),
                                ],
                              ),
                            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CupertinoContextMenu(
        actions: [
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(CupertinoIcons.add, size: 18),
                SizedBox(width: 8),
                Text('Add to Queue'),
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
                Icon(CupertinoIcons.play_arrow, size: 18),
                SizedBox(width: 8),
                Text('Play Next'),
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
                ),
                const SizedBox(width: 8),
                Text(track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
          ),
        ],
        child: CupertinoListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFF2C2C2E),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: appState.jellyfinService.getImageUrl(
                      track.imageUrl!,
                      width: 96,
                      height: 96,
                    ),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CupertinoActivityIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      CupertinoIcons.music_note,
                      color: CupertinoColors.systemGrey,
                      size: 24,
                    ),
                  )
                : const Icon(
                    CupertinoIcons.music_note,
                    color: CupertinoColors.systemGrey,
                    size: 24,
                  ),
          ),
        ),
        title: Text(
          track.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: CupertinoColors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: track.artistName != null
            ? Text(
                track.artistName!,
                style: const TextStyle(color: CupertinoColors.systemGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (track.duration != null)
              Text(
                _formatDuration(Duration(milliseconds: track.duration!)),
                style: const TextStyle(color: CupertinoColors.systemGrey2),
              ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _toggleFavorite(context, track),
              child: Icon(
                track.isFavorite 
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                color: track.isFavorite 
                    ? const Color(0xFFFF453A)
                    : CupertinoColors.systemGrey,
                size: 20,
              ),
            ),
          ],
        ),
        onTap: onTap,
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
