import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../models/download_models.dart';
import '../../widgets/cached_image_widget.dart';
import '../albums/details/album_details.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF000000),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header with Play and Shuffle buttons
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Play and Shuffle buttons
                        Row(
                          children: [
                            // Play button
                            Expanded(
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _playAllDownloaded(appState),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                        'Play',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Shuffle button
                            Expanded(
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _shuffleAllDownloaded(appState),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                
                // Downloaded content
                ..._buildDownloadedContent(appState),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDownloadedContent(AppState appState) {
    List<Widget> slivers = [];

    // Get downloaded content
    final downloadedTracks = appState.tracks.where((track) => 
      appState.downloadService.isTrackDownloaded(track.id)).toList();
    final downloadedAlbums = _getDownloadedAlbums(appState, downloadedTracks);
    final favoriteDownloaded = downloadedTracks.where((track) => track.isFavorite).toList();

    // Favorites section
    if (favoriteDownloaded.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: _buildFavoritesSection(favoriteDownloaded, appState),
      ));
    }

    // Sample playlists (mock data matching your image)
    slivers.add(SliverToBoxAdapter(
      child: _buildPlaylistSection('中文', 10, appState),
    ));
    
    slivers.add(SliverToBoxAdapter(
      child: _buildPlaylistSection('Future', 28, appState),
    ));

    // Downloaded albums
    for (final album in downloadedAlbums) {
      final albumTracks = downloadedTracks.where((track) => track.albumId == album.id).toList();
      slivers.add(SliverToBoxAdapter(
        child: _buildAlbumSection(album, albumTracks.length, appState),
      ));
    }

    // Download queue (show items currently downloading)
    final downloadService = appState.downloadService;
    final activeDownloads = downloadService.downloadTasks.where((task) => 
      task.status == DownloadStatus.downloading || 
      task.status == DownloadStatus.failed
    ).toList();

    if (activeDownloads.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.only(top: 20),
          child: Column(
            children: activeDownloads.map((task) => _buildDownloadQueueItem(task, appState)).toList(),
          ),
        ),
      ));
    }

    // Bottom padding
    slivers.add(const SliverToBoxAdapter(
      child: SizedBox(height: 150),
    ));

    return slivers;
  }

  List<Album> _getDownloadedAlbums(AppState appState, List<Track> downloadedTracks) {
    final albumIds = downloadedTracks.map((track) => track.albumId).where((id) => id != null).toSet();
    return appState.albums.where((album) => albumIds.contains(album.id)).toList();
  }

  Widget _buildFavoritesSection(List<Track> favoriteTracks, AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _playFavorites(favoriteTracks, appState),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Favorites icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF453A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.heart_fill,
                  color: Color(0xFFFFFFFF),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Playlist • ${favoriteTracks.length} tracks',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistSection(String playlistName, int trackCount, AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Playlist artwork (composite for sample data)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Create a composite artwork look
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E4EC6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF453A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlistName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Playlist • $trackCount tracks',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumSection(Album album, int trackCount, AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _navigateToAlbum(album, appState),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Album artwork
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: album.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImageWidget(
                          imageUrl: appState.jellyfinService.getImageUrl(album.imageUrl!, width: 100, height: 100),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_albums,
                              color: Color(0xFFFFFFFF),
                              size: 24,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.music_albums,
                          color: Color(0xFFFFFFFF),
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Album • ${album.artistName ?? 'Unknown Artist'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey2,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadQueueItem(DownloadTask task, AppState appState) {
    final track = appState.tracks.firstWhere((t) => t.id == task.trackId, orElse: () => Track(
      id: task.trackId,
      name: 'Unknown Track',
    ));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Track artwork
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: track.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedImageWidget(
                      imageUrl: appState.jellyfinService.getImageUrl(track.imageUrl!, width: 100, height: 100),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.music_note,
                          color: Color(0xFFFFFFFF),
                          size: 24,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.music_note,
                      color: Color(0xFFFFFFFF),
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  track.artistName ?? 'Unknown Artist',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: task.progress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getStatusColor(task.status),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(task.progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(task.status),
                      style: TextStyle(
                        color: _getStatusColor(task.status),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action button
          if (task.status == DownloadStatus.downloading)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => appState.downloadService.cancelDownload(task.trackId),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: CupertinoColors.systemRed,
                  size: 20,
                ),
              ),
            )
          else if (task.status == DownloadStatus.failed)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _retryDownload(task, appState),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  CupertinoIcons.arrow_clockwise_circle_fill,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const Color(0xFF007AFF);
      case DownloadStatus.downloaded:
        return const Color(0xFF30D158);
      case DownloadStatus.failed:
        return const Color(0xFFFF453A);
      case DownloadStatus.paused:
        return const Color(0xFF8E8E93);
      case DownloadStatus.notDownloaded:
        return const Color(0xFF8E8E93);
    }
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.downloaded:
        return 'Complete';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.notDownloaded:
        return 'Not Downloaded';
    }
  }

  // Actions
  void _playAllDownloaded(AppState appState) {
    final downloadedTracks = appState.tracks.where((track) => 
      appState.downloadService.isTrackDownloaded(track.id)).toList();
    if (downloadedTracks.isNotEmpty) {
      appState.playPlaylist(downloadedTracks, 0);
    }
  }

  void _shuffleAllDownloaded(AppState appState) {
    final downloadedTracks = appState.tracks.where((track) => 
      appState.downloadService.isTrackDownloaded(track.id)).toList();
    if (downloadedTracks.isNotEmpty) {
      downloadedTracks.shuffle();
      appState.playPlaylist(downloadedTracks, 0);
    }
  }

  void _playFavorites(List<Track> favoriteTracks, AppState appState) {
    if (favoriteTracks.isNotEmpty) {
      appState.playPlaylist(favoriteTracks, 0);
    }
  }

  void _navigateToAlbum(Album album, AppState appState) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AlbumDetailScreen(album: album),
      ),
    );
  }

  void _retryDownload(DownloadTask task, AppState appState) {
    final track = appState.tracks.firstWhere((t) => t.id == task.trackId, orElse: () => Track(
      id: task.trackId,
      name: 'Unknown Track',
    ));
    appState.downloadService.downloadTrack(track);
  }
}