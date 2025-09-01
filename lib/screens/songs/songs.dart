import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../partials/player/mini_player.dart';
import '../../widgets/download_button.dart';

class SongsView extends StatelessWidget {
  const SongsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading && appState.tracks.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: CupertinoColors.white),
          );
        }

        if (appState.tracks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.music_note, size: 64, color: CupertinoColors.systemGrey),
                SizedBox(height: 16),
                Text(
                  'No songs found',
                  style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Container(
              color: const Color(0xFF000000), // Dark background
              child: CustomScrollView(
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              borderRadius: BorderRadius.circular(25),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(CupertinoIcons.play_fill, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Play All',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                if (appState.tracks.isNotEmpty) {
                                  appState.playPlaylist(appState.tracks, 0);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              borderRadius: BorderRadius.circular(25),
                              color: const Color(0xFF2C2C2E),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(CupertinoIcons.shuffle, color: CupertinoColors.white, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Shuffle',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                if (appState.tracks.isNotEmpty) {
                                  final shuffledTracks = List<Track>.from(appState.tracks)..shuffle();
                                  appState.playPlaylist(shuffledTracks, 0);
                                }
                              },
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
                        final track = appState.tracks[index];
                        return SongTile(
                          track: track,
                          onTap: () {
                            appState.playPlaylist(appState.tracks, index);
                          },
                        );
                      },
                      childCount: appState.tracks.length,
                    ),
                  ),
                  // Add some bottom padding for mini player
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
            // Mini player at bottom
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        );
      },
    );
  }
}

class SongTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const SongTile({
    super.key,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: CupertinoContextMenu(
            actions: [
              CupertinoContextMenuAction(
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.arrow_down_circle, size: 18),
                    SizedBox(width: 8),
                    Text('Download'),
                  ],
                ),
                onPressed: () {
                  Navigator.pop(context);
                  appState.downloadService.downloadTrack(track);
                },
              ),
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
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Album artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: track.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: appState.jellyfinService.getImageUrl(
                                  track.imageUrl!,
                                  width: 150,
                                  height: 150,
                                ),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF2C2C2E),
                                  child: const Icon(
                                    CupertinoIcons.music_note,
                                    color: CupertinoColors.systemGrey,
                                    size: 24,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF2C2C2E),
                                  child: const Icon(
                                    CupertinoIcons.music_note,
                                    color: CupertinoColors.systemGrey,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(
                                  CupertinoIcons.music_note,
                                  color: CupertinoColors.systemGrey,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Song info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.name,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (track.artistName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              track.artistName!,
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Duration and favorite
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (track.duration != null) ...[
                          Text(
                            _formatDuration(track.duration!),
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Favorite heart icon
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 32,
                          onPressed: () {
                            appState.toggleFavorite(track);
                          },
                          child: Icon(
                            track.isFavorite 
                                ? CupertinoIcons.heart_fill 
                                : CupertinoIcons.heart,
                            color: track.isFavorite 
                                ? CupertinoColors.systemRed 
                                : CupertinoColors.systemGrey,
                            size: 20,
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
      },
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
