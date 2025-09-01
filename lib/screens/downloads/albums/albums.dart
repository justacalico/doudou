import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../services/download_service.dart';

class DownloadedAlbumsTab extends StatelessWidget {
  const DownloadedAlbumsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        return _buildDownloadedAlbums(downloadService, appState);
      },
    );
  }

  Widget _buildDownloadedAlbums(DownloadService downloadService, AppState appState) {
    final downloadedTracks = downloadService.downloadedTracks;
    
    if (downloadedTracks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.music_albums,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloaded albums',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Downloaded songs that are part of albums will appear here',
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

    // Group downloaded tracks by album
    final Map<Album, List<Track>> albumGroups = {};
    
    // Get all downloaded track IDs
    final downloadedTrackIds = downloadedTracks.keys.toSet();
    
    // Group tracks by album
    for (final track in appState.tracks) {
      if (downloadedTrackIds.contains(track.id) && track.albumId != null) {
        // Find the album for this track
        final album = appState.albums.firstWhere(
          (a) => a.id == track.albumId,
          orElse: () => Album(
            id: track.albumId!,
            name: track.albumName ?? 'Unknown Album',
            artistName: track.artistName,
          ),
        );
        
        if (albumGroups.containsKey(album)) {
          albumGroups[album]!.add(track);
        } else {
          albumGroups[album] = [track];
        }
      }
    }

    if (albumGroups.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.music_albums,
                  size: 80,
                  color: Color(0xFF333333),
                ),
                SizedBox(height: 24),
                Text(
                  'No downloaded albums',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Downloaded songs that are part of albums will appear here',
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

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final albumEntry = albumGroups.entries.elementAt(index);
          final album = albumEntry.key;
          final tracks = albumEntry.value;
          
          return DownloadedAlbumItem(
            album: album,
            downloadedTracks: tracks,
            onTap: () => _showAlbumTracks(context, album, tracks, appState),
            onDelete: () => _deleteAlbumDownloads(downloadService, tracks),
          );
        },
        childCount: albumGroups.length,
      ),
    );
  }

  void _showAlbumTracks(BuildContext context, Album album, List<Track> tracks, AppState appState) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DownloadedAlbumDetailScreen(
          album: album,
          downloadedTracks: tracks,
        ),
      ),
    );
  }

  void _deleteAlbumDownloads(DownloadService downloadService, List<Track> tracks) {
    for (final track in tracks) {
      downloadService.deleteDownload(track.id);
    }
  }
}

// Widget for downloaded album items
class DownloadedAlbumItem extends StatelessWidget {
  final Album album;
  final List<Track> downloadedTracks;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DownloadedAlbumItem({
    super.key,
    required this.album,
    required this.downloadedTracks,
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
                  child: album.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: context
                              .read<AppState>()
                              .jellyfinService
                              .getImageUrl(
                                album.imageUrl!,
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
                            CupertinoIcons.music_albums,
                            color: Color(0xFF8E8E93),
                            size: 28,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.music_albums,
                          color: Color(0xFF8E8E93),
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Album info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (album.artistName != null) ...[
                      Text(
                        album.artistName!,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      '${downloadedTracks.length} downloaded ${downloadedTracks.length == 1 ? 'song' : 'songs'}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Download indicator and delete button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D158).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF30D158).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: Color(0xFF30D158),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 24,
                    onPressed: onDelete,
                    child: const Icon(
                      CupertinoIcons.delete,
                      color: Color(0xFFFF453A),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen for showing downloaded album details
class DownloadedAlbumDetailScreen extends StatelessWidget {
  final Album album;
  final List<Track> downloadedTracks;

  const DownloadedAlbumDetailScreen({
    super.key,
    required this.album,
    required this.downloadedTracks,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          album.name,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Album header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Album artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: album.imageUrl != null
                            ? Consumer<AppState>(
                                builder: (context, appState, child) {
                                  return CachedNetworkImage(
                                    imageUrl: appState.jellyfinService.getImageUrl(
                                      album.imageUrl!,
                                      width: 400,
                                      height: 400,
                                    ),
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: const Color(0xFF2C2C2E),
                                      child: const Icon(
                                        CupertinoIcons.music_albums,
                                        color: CupertinoColors.systemGrey,
                                        size: 80,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: const Color(0xFF2C2C2E),
                                      child: const Icon(
                                        CupertinoIcons.music_albums,
                                        color: CupertinoColors.systemGrey,
                                        size: 80,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(
                                  CupertinoIcons.music_albums,
                                  color: CupertinoColors.systemGrey,
                                  size: 80,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Album title
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (album.artistName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        album.artistName!,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Downloaded track count
                    Text(
                      '${downloadedTracks.length} downloaded ${downloadedTracks.length == 1 ? 'song' : 'songs'}',
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Play button
                    if (downloadedTracks.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.play_fill, size: 18),
                              SizedBox(width: 8),
                              Text('Play Downloaded'),
                            ],
                          ),
                          onPressed: () => _playDownloadedTracks(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Downloaded tracks list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = downloadedTracks[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _playTrack(context, track, index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Track number
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  (index + 1).toString(),
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Downloaded indicator
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: Color(0xFF30D158),
                              size: 16,
                            ),
                            const SizedBox(width: 12),
                            // Track info
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: downloadedTracks.length,
              ),
            ),
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  void _playDownloadedTracks(BuildContext context) {
    final appState = context.read<AppState>();
    appState.playPlaylist(downloadedTracks, 0);
  }

  void _playTrack(BuildContext context, Track track, int index) {
    final appState = context.read<AppState>();
    appState.playPlaylist(downloadedTracks, index);
  }
}
