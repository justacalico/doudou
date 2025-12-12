import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../models/download_models.dart';
import '../../widgets/cached_image_widget.dart';
import '../../widgets/apple_design/liquid_glass.dart';
import '../shared/detail_track_view.dart';
import '../favorites/favorites.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return LiquidGradientBackground(
          child: CupertinoPageScaffold(
            backgroundColor: Colors.transparent,
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  // Header with stats and buttons
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Download statistics with glass cards
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                _buildStatCard(
                                  '${appState.tracks.where((track) => appState.downloadService.isTrackDownloaded(track.id)).length}',
                                  l10n.songs,
                                  const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  '${appState.downloadService.downloadTasks.where((task) => task.status == DownloadStatus.downloading).length}',
                                  l10n.downloading,
                                  const Color(0xFF06B6D4),
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  '${appState.downloadService.downloadTasks.where((task) => task.status == DownloadStatus.failed).length}',
                                  l10n.failed,
                                  const Color(0xFFEC4899),
                                ),
                              ],
                            ),
                          ),
                          // Play and Shuffle buttons with liquid glass
                          Row(
                            children: [
                              // Play button
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _playAllDownloaded(appState),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                      child: Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF8B5CF6),
                                              Color(0xFFEC4899),
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
                                            Icon(
                                              CupertinoIcons.play_fill,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.play,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
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
                                  onPressed: () => _shuffleAllDownloaded(appState),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                      child: Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF06B6D4),
                                              Color(0xFF8B5CF6),
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
                                            Icon(
                                              CupertinoIcons.shuffle,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.shuffle,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
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
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String value, String label, Color accentColor) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDownloadedContent(AppState appState) {
    List<Widget> slivers = [];

    // Get downloaded tracks only
    final downloadedTracks = appState.tracks
        .where((track) => appState.downloadService.isTrackDownloaded(track.id))
        .toList();
    
    // Get downloaded albums (albums that have at least one downloaded track)
    final downloadedAlbums = appState.albums
        .where((album) => appState.tracks
            .where((track) => track.albumId == album.id)
            .any((track) => appState.downloadService.isTrackDownloaded(track.id)))
        .toList();

    // Get favorite downloaded tracks
    final favoriteDownloadedTracks = downloadedTracks
        .where((track) => track.isFavorite)
        .toList();

    // Favorites section (only show if there are downloaded favorites)
    if (favoriteDownloadedTracks.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _buildFavoritesSection(favoriteDownloadedTracks, appState),
        ),
      );
    }

    // Don't show playlists in downloads view - focus on downloaded content only
    // Playlists can be accessed through the main playlists tab

    // Downloaded albums (albums that have at least one downloaded track)
    for (final album in downloadedAlbums) {
      final albumDownloadedTracks = downloadedTracks
          .where((track) => track.albumId == album.id)
          .length;
      
      if (albumDownloadedTracks > 0) {
        slivers.add(
          SliverToBoxAdapter(
            child: _buildAlbumSection(album, albumDownloadedTracks, appState),
          ),
        );
      }
    }

    // Individual downloaded tracks (show recent downloads)
    final recentDownloadedTracks = downloadedTracks.take(10).toList();
    for (final track in recentDownloadedTracks) {
      slivers.add(SliverToBoxAdapter(child: _buildTrackItem(track, appState)));
    }

    // Download queue (show items currently downloading)
    final downloadService = appState.downloadService;
    final activeDownloads = downloadService.downloadTasks
        .where(
          (task) =>
              task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.failed,
        )
        .toList();

    if (activeDownloads.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            child: Column(
              children: activeDownloads
                  .map((task) => _buildDownloadQueueItem(task, appState))
                  .toList(),
            ),
          ),
        ),
      );
    }

    // Show empty state if no downloads
    if (slivers.length <= 1) { // Only header/padding might be present
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(32),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.arrow_down_circle,
                  size: 64,
                  color: CupertinoColors.systemGrey,
                ),
                SizedBox(height: 16),
                Text(
                  'No Downloaded Music',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Download songs to listen offline',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Bottom padding
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 150)));

    return slivers;
  }

  Widget _buildFavoritesSection(List<Track> favoriteTracks, AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _navigateToFavorites(context, appState),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                  // Favorites icon with gradient
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFFFF6B6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC4899).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.heart_fill,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favorites',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Playlist • ${favoriteTracks.length} tracks',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white.withOpacity(0.4),
                    size: 16,
                  ),
                ],
              ),
            ),
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
        onPressed: () => _navigateToAlbum(album, appState, context),
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
                          imageUrl: appState.getImageUrl(
                            album.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
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
    final track = appState.tracks.firstWhere(
      (t) => t.id == task.trackId,
      orElse: () => Track(id: task.trackId, name: 'Unknown Track'),
    );

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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: track.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedImageWidget(
                      imageUrl: appState.getImageUrl(
                        track.imageUrl!,
                        width: 100,
                        height: 100,
                      ),
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
              onPressed: () =>
                  appState.downloadService.cancelDownload(task.trackId),
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

  Widget _buildTrackItem(Track track, AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _playTrack(track, appState),
        child: Container(
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
                          imageUrl: appState.getImageUrl(
                            track.imageUrl!,
                            width: 100,
                            height: 100,
                          ),
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
                  ],
                ),
              ),

              // Download indicator if downloaded
              if (appState.downloadService.isTrackDownloaded(track.id))
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    CupertinoIcons.arrow_down_circle_fill,
                    color: Color(0xFF30D158),
                    size: 20,
                  ),
                ),

              // Chevron
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 16,
              ),
            ],
          ),
        ),
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

  void _playAllDownloaded(AppState appState) {
    // Get only downloaded tracks
    final downloadedTracks = appState.tracks
        .where((track) => appState.downloadService.isTrackDownloaded(track.id))
        .toList();
    if (downloadedTracks.isNotEmpty) {
      appState.playPlaylist(downloadedTracks, 0);
    }
  }

  void _shuffleAllDownloaded(AppState appState) {
    // Get only downloaded tracks and shuffle them
    final downloadedTracks = appState.tracks
        .where((track) => appState.downloadService.isTrackDownloaded(track.id))
        .toList();
    if (downloadedTracks.isNotEmpty) {
      downloadedTracks.shuffle();
      appState.playPlaylist(downloadedTracks, 0);
    }
  }

  void _navigateToFavorites(BuildContext context, AppState appState) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const FavoritesView(showDownloadedOnly: true),
      ),
    );
  }

  void _navigateToAlbum(Album album, AppState appState, BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DetailTrackView.album(album),
      ),
    );
  }

  void _playTrack(Track track, AppState appState) {
    appState.playTrack(track);
  }

  void _retryDownload(DownloadTask task, AppState appState) {
    final track = appState.tracks.firstWhere((t) => t.id == task.trackId, orElse: () => Track(
      id: task.trackId,
      name: 'Unknown Track',
    ));
    appState.downloadService.downloadTrack(track);
  }
}
