import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../models/download_models.dart';
import '../../providers/app_state.dart';
import '../../services/download_service.dart';
import '../theme.dart';
import '../widgets/music_card.dart';
import '../widgets/page_template.dart';
import '../widgets/track_tile.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final downloadService = appState.downloadService;
          final downloadedTracks = List<Track>.from(
            appState.tracks.where((t) => downloadService.isTrackDownloaded(t.id)),
          );
          final albums = downloadService.getDownloadedAlbumsFromTracks(appState.tracks);

          return PageTemplate(
            title: l10n.downloads,
            subtitle: albums.isNotEmpty
                ? '${albums.length} ${l10n.albums} · ${downloadedTracks.length} ${l10n.songs}'
                : '${downloadedTracks.length} ${l10n.songs}',
            actions: [
              TextButton.icon(
                onPressed: downloadedTracks.isEmpty
                    ? null
                    : () => appState.playPlaylist(downloadedTracks, 0),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(l10n.playAll),
              ),
              TextButton.icon(
                onPressed: downloadedTracks.isEmpty
                    ? null
                    : () {
                        final shuffled = List<Track>.from(downloadedTracks)..shuffle();
                        appState.playPlaylist(shuffled, 0);
                      },
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: Text(l10n.shuffleAll),
              ),
            ],
            child: _buildContent(context, appState, downloadService, albums, downloadedTracks, l10n),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppState appState,
    DownloadService downloadService,
    List<DownloadedAlbumMetadata> albums,
    List<Track> downloadedTracks,
    AppLocalizations l10n,
  ) {
    if (downloadedTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              l10n.downloads,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              l10n.downloadSongsToListenOffline,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (albums.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.75,
          crossAxisSpacing: AppTheme.spacingMd,
          mainAxisSpacing: AppTheme.spacingMd,
        ),
        itemCount: albums.length,
        itemBuilder: (context, i) {
          final album = albums[i];
          final imageUrl = album.imageUrl != null ? appState.getImageUrl(album.imageUrl!) : null;
          final downloadingTracks = album.tracks.where((t) {
            return downloadService.getDownloadStatus(t.id) == DownloadStatus.downloading;
          }).toList();
          double? progress;
          if (downloadingTracks.isNotEmpty) {
            progress = downloadingTracks.fold<double>(
                  0.0,
                  (s, t) => s + downloadService.getDownloadProgress(t.id),
                ) /
                downloadingTracks.length;
          }
          return Stack(
            children: [
              MusicCard(
                title: album.name,
                subtitle: album.artistName ?? l10n.unknownArtist,
                imageUrl: imageUrl,
                size: 180,
                placeholderIcon: Icons.album_rounded,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => _DownloadAlbumDetailPage(
                        metadata: album,
                        downloadService: downloadService,
                      ),
                    ),
                  );
                },
              ),
              if (progress != null && progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppTheme.spacingMd,
        mainAxisSpacing: AppTheme.spacingMd,
      ),
      itemCount: downloadedTracks.length,
      itemBuilder: (context, i) {
        final track = downloadedTracks[i];
        final imageUrl = track.imageUrl != null ? appState.getImageUrl(track.imageUrl!) : null;
        final isDownloading = downloadService.getDownloadStatus(track.id) == DownloadStatus.downloading;
        final progress = downloadService.getDownloadProgress(track.id);
        return Stack(
          children: [
            MusicCard(
              title: track.name,
              subtitle: track.artistName ?? track.albumName ?? l10n.unknownArtist,
              imageUrl: imageUrl,
              size: 180,
              placeholderIcon: Icons.music_note_rounded,
              onTap: () => appState.playPlaylist(downloadedTracks, i),
            ),
            if (isDownloading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class FractionallySizedBox extends StatelessWidget {
  final double widthFactor;
  final Widget child;

  const FractionallySizedBox({super.key, required this.widthFactor, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth * widthFactor,
          child: child,
        );
      },
    );
  }
}

class _DownloadTrackPlaceholder extends StatelessWidget {
  final Track track;
  final AppState appState;
  final DownloadService downloadService;
  final bool isDownloaded;

  const _DownloadTrackPlaceholder({
    required this.track,
    required this.appState,
    required this.downloadService,
    required this.isDownloaded,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = track.imageUrl != null ? appState.getImageUrl(track.imageUrl!) : null;
    return Opacity(
      opacity: isDownloaded ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 44,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder())
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artistName ?? 'Unknown Artist',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isDownloaded)
              Text(
                'Not downloaded',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surface,
      child: Icon(Icons.music_note_rounded, color: AppTheme.textMuted, size: 22),
    );
  }
}

class _DownloadAlbumDetailPage extends StatelessWidget {
  final DownloadedAlbumMetadata metadata;
  final DownloadService downloadService;

  const _DownloadAlbumDetailPage({
    required this.metadata,
    required this.downloadService,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final tracks = metadata.tracks;
    final resolvedTracks = <Track>[];
    for (final min in tracks) {
      try {
        resolvedTracks.add(appState.tracks.firstWhere((t) => t.id == min.id));
      } catch (_) {}
    }
    resolvedTracks.sort((a, b) => (a.trackNumber ?? 999).compareTo(b.trackNumber ?? 999));
    final playable = resolvedTracks.where((t) => downloadService.isTrackDownloaded(t.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          metadata.name,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: resolvedTracks.isEmpty
          ? Center(
              child: Text(
                l10n.noSongsFound,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              itemCount: resolvedTracks.length,
              itemBuilder: (context, i) {
                final track = resolvedTracks[i];
                final canPlay = downloadService.isTrackDownloaded(track.id);
                final idx = playable.indexWhere((t) => t.id == track.id);
                if (canPlay && idx >= 0) {
                  return TrackTile(
                    track: track,
                    index: idx,
                    playlist: playable,
                    showTrackNumber: true,
                    showArtwork: true,
                    isCurrentTrack: false,
                  );
                }
                return _DownloadTrackPlaceholder(
                  track: track,
                  appState: appState,
                  downloadService: downloadService,
                  isDownloaded: canPlay,
                );
              },
            ),
    );
  }
}
