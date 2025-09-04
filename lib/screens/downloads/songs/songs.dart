import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/app_state.dart';
import '../../../models/download_models.dart';
import '../../../models/jellyfin_models.dart';
import '../../../services/download_service.dart';

class DownloadedSongsTab extends StatelessWidget {
  const DownloadedSongsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        return _buildDownloadedSongs(downloadService, appState);
      },
    );
  }

  Widget _buildDownloadedSongs(DownloadService downloadService, AppState appState) {
    final downloadedTracks = downloadService.downloadedTracks;
    
    if (downloadedTracks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.arrow_down_circle,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloaded songs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Download songs to listen offline',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        // Play buttons section
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Song count
                Text(
                  '${downloadedTracks.length} downloaded ${downloadedTracks.length == 1 ? 'song' : 'songs'}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Play buttons
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton.filled(
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.play_fill, size: 18),
                                SizedBox(width: 8),
                                Text('Play All'),
                              ],
                            ),
                            onPressed: () => _playAllDownloaded(appState, downloadedTracks, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton(
                            color: const Color(0xFF2C2C2E),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.shuffle, size: 18),
                                SizedBox(width: 8),
                                Text('Shuffle'),
                              ],
                            ),
                            onPressed: () => _playAllDownloaded(appState, downloadedTracks, true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      color: const Color(0xFF2C2C2E),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.shuffle, size: 18),
                          SizedBox(width: 8),
                          Icon(CupertinoIcons.heart_fill, size: 16, color: Color(0xFFFF375F)),
                          SizedBox(width: 8),
                          Text('Shuffle Favorites'),
                        ],
                      ),
                      onPressed: () => _playFavoritesDownloaded(appState, downloadedTracks),
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
              final trackId = downloadedTracks.keys.elementAt(index);
              final downloadedTrack = downloadedTracks[trackId]!;
              final track = appState.tracks.firstWhere(
                (t) => t.id == trackId,
                orElse: () => Track(
                  id: trackId,
                  name: 'Unknown Track',
                ),
              );
              
              return DownloadedTrackItem(
                track: track,
                downloadedTrack: downloadedTrack,
                onTap: () => _playDownloadedTrack(appState, track),
                onDelete: () => _deleteDownload(context, downloadService, trackId),
              );
            },
            childCount: downloadedTracks.length,
          ),
        ),
      ],
    );
  }

  void _playDownloadedTrack(AppState appState, Track track) {
    // Create a playlist with just this track for now
    // In a real implementation, you might want to play all downloaded tracks
    appState.playPlaylist([track], 0);
  }

  void _playAllDownloaded(AppState appState, Map<String, DownloadedTrack> downloadedTracks, bool shuffle) {
    // Convert downloaded tracks to Track objects
    final tracks = downloadedTracks.keys.map((trackId) {
      return appState.tracks.firstWhere(
        (t) => t.id == trackId,
        orElse: () => Track(
          id: trackId,
          name: 'Unknown Track',
        ),
      );
    }).toList();
    
    if (tracks.isNotEmpty) {
      if (shuffle) {
        // Create a shuffled copy of the tracks
        final shuffledTracks = List<Track>.from(tracks)..shuffle();
        appState.playPlaylist(shuffledTracks, 0);
      } else {
        appState.playPlaylist(tracks, 0);
      }
    }
  }
  
  void _playFavoritesDownloaded(AppState appState, Map<String, DownloadedTrack> downloadedTracks) {
    // Get tracks that are both downloaded and favorited
    final tracks = downloadedTracks.keys
        .map((trackId) {
          return appState.tracks.firstWhere(
            (t) => t.id == trackId,
            orElse: () => Track(id: trackId, name: 'Unknown Track'),
          );
        })
        .where((track) => track.isFavorite)
        .toList();
    
    if (tracks.isEmpty) {
      // Show alert if no favorited downloaded tracks
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('No Favorited Downloads'),
          content: const Text('You don\'t have any downloaded songs that are also marked as favorites.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }
    
    // Create a shuffled copy of the tracks
    final shuffledTracks = List<Track>.from(tracks)..shuffle();
    appState.playPlaylist(shuffledTracks, 0);
  }

  void _deleteDownload(BuildContext context, DownloadService downloadService, String trackId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Download'),
        content: const Text('Are you sure you want to delete this downloaded song?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              downloadService.deleteDownload(trackId);
            },
          ),
        ],
      ),
    );
  }
}

// Widget for downloaded track items
class DownloadedTrackItem extends StatelessWidget {
  final Track track;
  final DownloadedTrack downloadedTrack;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DownloadedTrackItem({
    super.key,
    required this.track,
    required this.downloadedTrack,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1C1E),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
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
                  child: downloadedTrack.imagePath != null
                      ? Image.file(
                          File(downloadedTrack.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            CupertinoIcons.music_note,
                            color: Color(0xFF8E8E93),
                            size: 28,
                          ),
                        )
                      : track.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: context
                                  .read<AppState>()
                                  .jellyfinService
                                  .getImageUrl(
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.arrow_down_circle_fill,
                          color: Color(0xFF00FF88),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatFileSize(downloadedTrack.fileSize),
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Delete button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.trash,
                    color: Color(0xFFFF453A),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
