import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/models/download_models.dart';
import 'package:doudou/services/download_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/ui/templates/music_card.dart';

/// Downloads page: grid of albums that have at least one downloaded track.
/// Tapping an album shows all tracks; downloaded ones are tappable, others greyed out.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final downloadService = appState.downloadService;
        final downloadedTracks = List<Track>.from(
          appState.tracks
              .where((t) => downloadService.isTrackDownloaded(t.id)),
        );
        final albums = downloadService.downloadedAlbums;

        return PageTemplate(
          title: l10n.downloads,
          subtitle: albums.isNotEmpty
              ? '${albums.length} ${l10n.albums} · ${downloadedTracks.length} ${l10n.songs}'
              : '${downloadedTracks.length} ${l10n.songs}',
          actions: [
            DesktopGlassButton(
              onPressed: downloadedTracks.isNotEmpty
                  ? () => appState.playPlaylist(downloadedTracks, 0)
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 18),
                  const SizedBox(width: DesktopTheme.spacingSm),
                  Text(l10n.playAll),
                ],
              ),
            ),
            const SizedBox(width: DesktopTheme.spacingSm),
            DesktopGlassButton(
              onPressed: downloadedTracks.isNotEmpty
                  ? () {
                      final shuffled = List<Track>.from(downloadedTracks)
                        ..shuffle();
                      appState.playPlaylist(shuffled, 0);
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shuffle_rounded, size: 18),
                  const SizedBox(width: DesktopTheme.spacingSm),
                  Text(l10n.shuffleAll),
                ],
              ),
            ),
          ],
          child: _buildContent(
            context,
            appState,
            downloadService,
            albums,
            downloadedTracks,
            l10n,
          ),
        );
      },
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
            Icon(
              Icons.download_outlined,
              size: 64,
              color: DesktopTheme.textMuted,
            ),
            const SizedBox(height: DesktopTheme.spacingMd),
            Text(
              l10n.downloads,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: DesktopTheme.textPrimary,
              ),
            ),
            const SizedBox(height: DesktopTheme.spacingSm),
            Text(
              l10n.downloadSongsToListenOffline,
              style: TextStyle(
                fontSize: 14,
                color: DesktopTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Prefer album grid when we have album metadata
    if (albums.isNotEmpty) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.75,
          crossAxisSpacing: DesktopTheme.spacingMd,
          mainAxisSpacing: DesktopTheme.spacingMd,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          final imageUrl = album.imageUrl != null
              ? appState.getImageUrl(album.imageUrl!)
              : null;
          return MusicCard(
            title: album.name,
            subtitle: album.artistName ?? l10n.unknownArtist,
            imageUrl: imageUrl,
            size: 180,
            placeholderIcon: Icons.album_rounded,
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => _DownloadAlbumDetailPage(
                    metadata: album,
                    downloadService: downloadService,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    // Fallback: grid of individual tracks (no album metadata, e.g. no albumId)
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75,
        crossAxisSpacing: DesktopTheme.spacingMd,
        mainAxisSpacing: DesktopTheme.spacingMd,
      ),
      itemCount: downloadedTracks.length,
      itemBuilder: (context, index) {
        final track = downloadedTracks[index];
        final imageUrl = track.imageUrl != null
            ? appState.getImageUrl(track.imageUrl!)
            : null;
        return MusicCard(
          title: track.name,
          subtitle: track.artistName ?? track.albumName ?? l10n.unknownArtist,
          imageUrl: imageUrl,
          size: 180,
          placeholderIcon: Icons.music_note_rounded,
          onTap: () => appState.playPlaylist(downloadedTracks, index),
        );
      },
    );
  }
}

/// Detail page for one downloaded album: shows all tracks; downloaded ones are tappable, others greyed out.
class _DownloadAlbumDetailPage extends StatefulWidget {
  final DownloadedAlbumMetadata metadata;
  final DownloadService downloadService;

  const _DownloadAlbumDetailPage({
    required this.metadata,
    required this.downloadService,
  });

  @override
  State<_DownloadAlbumDetailPage> createState() =>
      _DownloadAlbumDetailPageState();
}

class _DownloadAlbumDetailPageState extends State<_DownloadAlbumDetailPage> {
  List<Track>? _tracks;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();
    try {
      final list = await appState.getAlbumTracks(widget.metadata.albumId);
      list.sort((a, b) {
        final an = a.trackNumber ?? 999;
        final bn = b.trackNumber ?? 999;
        return an.compareTo(bn);
      });
      if (mounted) {
        setState(() {
          _tracks = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tracks = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final meta = widget.metadata;

    return Scaffold(
      backgroundColor: DesktopTheme.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          meta.name,
          style: TextStyle(
            color: DesktopTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_tracks == null || _tracks!.isEmpty)
              ? _buildListFromMetadata(context, appState, l10n)
              : _buildTrackList(context, appState, l10n),
    );
  }

  Widget _buildListFromMetadata(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final meta = widget.metadata;
    final downloadService = widget.downloadService;
    // Offline or no cached tracks: show from stored metadata
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopTheme.spacingLg,
        vertical: DesktopTheme.spacingMd,
      ),
      itemCount: meta.tracks.length,
      itemBuilder: (context, index) {
        final min = meta.tracks[index];
        final isDownloaded = downloadService.isTrackDownloaded(min.id);
        Track? track;
        try {
          track = appState.tracks.firstWhere((t) => t.id == min.id);
        } catch (_) {
          track = null;
        }
        return ListTile(
          leading: Icon(
            isDownloaded ? Icons.download_done_rounded : Icons.music_note_rounded,
            color: isDownloaded
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          title: Text(
            min.name,
            style: TextStyle(
              color: isDownloaded
                  ? DesktopTheme.textPrimary
                  : DesktopTheme.textPrimary.withValues(alpha: 0.5),
              fontWeight: isDownloaded ? FontWeight.w500 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: min.artistName != null
              ? Text(
                  min.artistName!,
                  style: TextStyle(
                    color: isDownloaded
                        ? DesktopTheme.textSecondary
                        : DesktopTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                )
              : null,
          trailing: isDownloaded && track != null
              ? IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {
                    final List<Track> playlist = [];
                    for (final m in meta.tracks) {
                      try {
                        final t = appState.tracks.firstWhere((x) => x.id == m.id);
                        playlist.add(t);
                      } catch (_) {}
                    }
                    final idx = playlist.indexWhere((t) => t.id == track!.id);
                    if (idx >= 0) appState.playPlaylist(playlist, idx);
                  },
                )
              : (track != null
                  ? IconButton(
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => downloadService.downloadTrack(track!),
                    )
                  : null),
        );
      },
    );
  }

  Widget _buildTrackList(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final downloadService = widget.downloadService;
    final tracks = _tracks!;
    final downloadedInAlbum =
        tracks.where((t) => downloadService.isTrackDownloaded(t.id)).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopTheme.spacingLg,
        vertical: DesktopTheme.spacingMd,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isDownloaded = downloadService.isTrackDownloaded(track.id);
        return ListTile(
          leading: Icon(
            isDownloaded ? Icons.download_done_rounded : Icons.music_note_rounded,
            color: isDownloaded
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          title: Text(
            track.name,
            style: TextStyle(
              color: isDownloaded
                  ? DesktopTheme.textPrimary
                  : DesktopTheme.textPrimary.withValues(alpha: 0.5),
              fontWeight: isDownloaded ? FontWeight.w500 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: Text(
            track.artistName ?? l10n.unknownArtist,
            style: TextStyle(
              color: isDownloaded
                  ? DesktopTheme.textSecondary
                  : DesktopTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          trailing: isDownloaded
              ? IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {
                    final idx = downloadedInAlbum
                        .indexWhere((t) => t.id == track.id);
                    if (idx >= 0) appState.playPlaylist(downloadedInAlbum, idx);
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => downloadService.downloadTrack(track),
                ),
        );
      },
    );
  }
}
