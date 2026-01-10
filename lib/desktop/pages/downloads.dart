import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../templates/desktop_theme.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../models/download_models.dart';
import 'details/media_details.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return '--:--';
    final totalSeconds = milliseconds ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _playAllDownloaded(AppState appState) {
    final downloadedTracks = appState.tracks
        .where((track) => appState.downloadService.isTrackDownloaded(track.id))
        .toList();
    if (downloadedTracks.isNotEmpty) {
      appState.playPlaylist(downloadedTracks, 0);
    }
  }

  void _shuffleAllDownloaded(AppState appState) {
    final downloadedTracks = appState.tracks
        .where((track) => appState.downloadService.isTrackDownloaded(track.id))
        .toList();
    if (downloadedTracks.isNotEmpty) {
      final shuffled = List<Track>.from(downloadedTracks)..shuffle();
      appState.playPlaylist(shuffled, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        final downloadedTracks = appState.tracks
            .where((track) => downloadService.isTrackDownloaded(track.id))
            .toList();

        final downloadingCount = downloadService.downloadTasks
            .where((task) => task.status == DownloadStatus.downloading)
            .length;

        final failedCount = downloadService.downloadTasks
            .where((task) => task.status == DownloadStatus.failed)
            .length;

        return PageTemplate(
          title: l10n.downloads,
          subtitle: '${downloadedTracks.length} ${l10n.songs}',
          actions: [
            // Play All button
            IconButton(
              onPressed: downloadedTracks.isNotEmpty
                  ? () => _playAllDownloaded(appState)
                  : null,
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.playAll,
              iconSize: 28,
            ),
            // Shuffle button
            IconButton(
              onPressed: downloadedTracks.isNotEmpty
                  ? () => _shuffleAllDownloaded(appState)
                  : null,
              icon: const Icon(Icons.shuffle),
              tooltip: l10n.shuffleAll,
              iconSize: 28,
            ),
          ],
          child: _buildContent(
            context,
            appState,
            downloadedTracks,
            downloadingCount,
            failedCount,
            l10n,
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppState appState,
    List<Track> downloadedTracks,
    int downloadingCount,
    int failedCount,
    AppLocalizations l10n,
  ) {
    final downloadService = appState.downloadService;

    // Get active downloads
    final activeDownloads = downloadService.downloadTasks
        .where(
          (task) =>
              task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.failed,
        )
        .toList();

    // Get downloaded albums
    final downloadedAlbums = appState.albums
        .where(
          (album) => appState.tracks
              .where((track) => track.albumId == album.id)
              .any((track) => downloadService.isTrackDownloaded(track.id)),
        )
        .toList();

    if (downloadedTracks.isEmpty && activeDownloads.isEmpty) {
      return _buildEmptyState(l10n);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          _buildStatsRow(
            downloadedTracks.length,
            downloadingCount,
            failedCount,
            l10n,
          ),
          const SizedBox(height: DesktopTheme.spacingXl),

          // Active downloads section
          if (activeDownloads.isNotEmpty) ...[
            _buildSectionHeader(l10n.downloading, Icons.download_rounded),
            const SizedBox(height: DesktopTheme.spacingMd),
            _buildActiveDownloadsList(activeDownloads, appState),
            const SizedBox(height: DesktopTheme.spacingXl),
          ],

          // Downloaded albums section
          if (downloadedAlbums.isNotEmpty) ...[
            _buildSectionHeader(l10n.albums, Icons.album_rounded),
            const SizedBox(height: DesktopTheme.spacingMd),
            _buildAlbumsGrid(downloadedAlbums, downloadedTracks, appState),
            const SizedBox(height: DesktopTheme.spacingXl),
          ],

          // All downloaded tracks
          _buildSectionHeader(l10n.songs, Icons.music_note_rounded),
          const SizedBox(height: DesktopTheme.spacingMd),
          _buildTracksList(downloadedTracks, appState),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: DesktopTheme.accentGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: DesktopTheme.accentPrimary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.download_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noDownloadedMusic,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: DesktopTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.downloadSongsToListenOffline,
            style: TextStyle(
              fontSize: 14,
              color: DesktopTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    int downloadedCount,
    int downloadingCount,
    int failedCount,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            downloadedCount.toString(),
            l10n.songs,
            DesktopTheme.accentPrimary,
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        Expanded(
          child: _buildStatCard(
            downloadingCount.toString(),
            l10n.downloading,
            const Color(0xFF06B6D4),
          ),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        Expanded(
          child: _buildStatCard(
            failedCount.toString(),
            l10n.failed,
            const Color(0xFFEC4899),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: DesktopTheme.spacingLg,
        horizontal: DesktopTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: DesktopTheme.glassSurface,
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: DesktopTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: DesktopTheme.textSecondary, size: 20),
        const SizedBox(width: DesktopTheme.spacingSm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: DesktopTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDownloadsList(
    List<DownloadTask> tasks,
    AppState appState,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: DesktopTheme.glassSurface,
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: Column(
        children: tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          final isLast = index == tasks.length - 1;

          return Column(
            children: [
              _buildDownloadTaskItem(task, appState),
              if (!isLast)
                const Divider(
                  height: 1,
                  color: DesktopTheme.glassBorder,
                  indent: 72,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDownloadTaskItem(DownloadTask task, AppState appState) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isFailed = task.status == DownloadStatus.failed;

    return InkWell(
      onTap: isFailed
          ? () {
              // Retry download
              final track = appState.tracks.firstWhere(
                (t) => t.id == task.trackId,
                orElse: () => Track(
                  id: task.trackId,
                  name: task.trackName,
                ),
              );
              appState.downloadService.downloadTrack(track);
            }
          : null,
      borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(DesktopTheme.spacingMd),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isDownloading
                        ? const Color(0xFF06B6D4)
                        : const Color(0xFFEC4899))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
              ),
              child: isDownloading
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: task.progress,
                          strokeWidth: 3,
                          color: const Color(0xFF06B6D4),
                          backgroundColor: const Color(0xFF06B6D4).withOpacity(0.2),
                        ),
                        Text(
                          '${(task.progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                      ],
                    )
                  : const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEC4899),
                    ),
            ),
            const SizedBox(width: DesktopTheme.spacingMd),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.trackName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: DesktopTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDownloading
                        ? 'Downloading... ${(task.progress * 100).toInt()}%'
                        : 'Failed - Tap to retry',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDownloading
                          ? const Color(0xFF06B6D4)
                          : const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
            ),
            // Cancel button
            IconButton(
              onPressed: () {
                appState.downloadService.cancelDownload(task.trackId);
              },
              icon: const Icon(Icons.close),
              iconSize: 20,
              color: DesktopTheme.textSecondary,
              tooltip: 'Cancel',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsGrid(
    List<Album> albums,
    List<Track> downloadedTracks,
    AppState appState,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75,
        crossAxisSpacing: DesktopTheme.spacingMd,
        mainAxisSpacing: DesktopTheme.spacingMd,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final albumTracks = downloadedTracks
            .where((track) => track.albumId == album.id)
            .toList();

        return _buildAlbumCard(album, albumTracks.length, appState);
      },
    );
  }

  Widget _buildAlbumCard(Album album, int downloadedCount, AppState appState) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaDetailsPage.album(album: album),
          ),
        );
      },
      borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: DesktopTheme.glassSurface,
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          border: Border.all(color: DesktopTheme.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album artwork
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DesktopTheme.radiusMd),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildAlbumImage(album.imageUrl, appState),
                    // Download indicator
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DesktopTheme.accentPrimary.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.download_done_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$downloadedCount',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Album info
            Padding(
              padding: const EdgeInsets.all(DesktopTheme.spacingSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DesktopTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.artistName ?? 'Unknown Artist',
                    style: TextStyle(
                      fontSize: 12,
                      color: DesktopTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTracksList(List<Track> tracks, AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: DesktopTheme.glassSurface,
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesktopTheme.spacingMd,
              vertical: DesktopTheme.spacingSm,
            ),
            child: Row(
              children: [
                const SizedBox(width: 48), // Space for artwork
                const SizedBox(width: DesktopTheme.spacingMd),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DesktopTheme.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Album',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DesktopTheme.textTertiary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DesktopTheme.textTertiary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 64), // Space for actions (icon + menu button)
              ],
            ),
          ),
          const Divider(height: 1, color: DesktopTheme.glassBorder),
          // Track rows
          ...tracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            final isLast = index == tracks.length - 1;

            return Column(
              children: [
                _buildTrackRow(track, index, tracks, appState),
                if (!isLast)
                  const Divider(
                    height: 1,
                    color: DesktopTheme.glassBorder,
                    indent: 72,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrackRow(
    Track track,
    int index,
    List<Track> tracks,
    AppState appState,
  ) {
    return InkWell(
      onTap: () {
        appState.playPlaylist(tracks, index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesktopTheme.spacingMd,
          vertical: DesktopTheme.spacingSm,
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
              child: SizedBox(
                width: 48,
                height: 48,
                child: _buildTrackImage(track.imageUrl, appState),
              ),
            ),
            const SizedBox(width: DesktopTheme.spacingMd),
            // Title and artist
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: DesktopTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName ?? 'Unknown Artist',
                    style: TextStyle(
                      fontSize: 12,
                      color: DesktopTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Album
            Expanded(
              flex: 2,
              child: Text(
                track.albumName ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: DesktopTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Duration
            SizedBox(
              width: 60,
              child: Text(
                _formatDuration(track.duration),
                style: TextStyle(
                  fontSize: 13,
                  color: DesktopTheme.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // Downloaded indicator and delete button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_done_rounded,
                  size: 16,
                  color: DesktopTheme.accentPrimary,
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: DesktopTheme.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDeleteDownload(context, track, appState);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Delete Download'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDownload(
    BuildContext context,
    Track track,
    AppState appState,
  ) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteDownload),
        content: Text('Delete "${track.name}" from your device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              appState.downloadService.deleteDownload(track.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  Widget _buildAlbumImage(String? imageId, AppState appState) {
    final imageUrl = _getImageUrl(appState, imageId);
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: DesktopTheme.backgroundElevated,
          child: const Icon(
            Icons.album_rounded,
            size: 40,
            color: DesktopTheme.textTertiary,
          ),
        ),
      );
    }
    return Container(
      color: DesktopTheme.backgroundElevated,
      child: const Icon(
        Icons.album_rounded,
        size: 40,
        color: DesktopTheme.textTertiary,
      ),
    );
  }

  Widget _buildTrackImage(String? imageId, AppState appState) {
    final imageUrl = _getImageUrl(appState, imageId);
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: DesktopTheme.backgroundElevated,
          child: const Icon(
            Icons.music_note_rounded,
            size: 20,
            color: DesktopTheme.textTertiary,
          ),
        ),
      );
    }
    return Container(
      color: DesktopTheme.backgroundElevated,
      child: const Icon(
        Icons.music_note_rounded,
        size: 20,
        color: DesktopTheme.textTertiary,
      ),
    );
  }
}
