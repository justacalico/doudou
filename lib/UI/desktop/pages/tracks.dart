import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../templates/page_template.dart';
import '../templates/desktop_layout.dart';
import 'details/media_details.dart';
import 'details/artist_details.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../models/download_models.dart';
import '../../../services/notification_service.dart';

class TracksPage extends StatefulWidget {
  const TracksPage({super.key});

  @override
  State<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends State<TracksPage> {
  List<Track> _tracks = [];
  bool _isLoading = false;
  String _error = '';
  String _sortBy = 'title'; // title, artist, album, duration, dateAdded
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final appState = context.read<AppState>();
      // Use getAllTracks to get all tracks with proper pagination
      // This fixes the issue where only 1 page was loaded for shuffle
      final tracks = await appState.mediaServiceManager.getAllTracks();

      setState(() {
        _tracks = tracks;
        _sortTracks();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tracks: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortTracks() {
    _tracks.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'title':
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'artist':
          comparison = (a.artistName ?? '').toLowerCase().compareTo(
            (b.artistName ?? '').toLowerCase(),
          );
          break;
        case 'album':
          comparison = (a.albumName ?? '').toLowerCase().compareTo(
            (b.albumName ?? '').toLowerCase(),
          );
          break;
        case 'duration':
          comparison = (a.duration ?? 0).compareTo(b.duration ?? 0);
          break;
        default:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _handleSort(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortBy;
        _sortAscending = true;
      }
      _sortTracks();
    });
  }

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return '--:--';

    // Convert milliseconds to seconds
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return PageTemplate(
      title: l10n.navTracks,
      actions: [
        // Play All button
        Consumer<AppState>(
          builder: (context, appState, child) {
            return IconButton(
              onPressed: _tracks.isNotEmpty
                  ? () => _playAllTracks(appState)
                  : null,
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.playAll,
              iconSize: 28,
            );
          },
        ),

        // Shuffle button
        Consumer<AppState>(
          builder: (context, appState, child) {
            return IconButton(
              onPressed: _tracks.isNotEmpty
                  ? () => _shuffleAllTracks(appState)
                  : null,
              icon: const Icon(Icons.shuffle),
              tooltip: l10n.shuffleAll,
              iconSize: 28,
            );
          },
        ),

        // Play Favorites button
        Consumer<AppState>(
          builder: (context, appState, child) {
            final favoriteCount = _tracks
                .where((track) => track.isFavorite)
                .length;
            return IconButton(
              onPressed: favoriteCount > 0
                  ? () => _playFavoriteTracks(appState)
                  : null,
              icon: Icon(
                Icons.favorite,
                color: favoriteCount > 0 ? Colors.red : null,
              ),
              tooltip: favoriteCount > 0
                  ? l10n.playFavoritesCount(favoriteCount)
                  : l10n.noFavoriteTracks,
              iconSize: 28,
            );
          },
        ),

        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: l10n.sortBy,
          onSelected: _handleSort,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'title',
              child: Row(
                children: [
                  Icon(_sortBy == 'title' ? Icons.check : null),
                  const SizedBox(width: 8),
                  Text(l10n.title),
                  if (_sortBy == 'title') ...[
                    const Spacer(),
                    Icon(
                      _sortAscending
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: 'artist',
              child: Row(
                children: [
                  Icon(_sortBy == 'artist' ? Icons.check : null),
                  const SizedBox(width: 8),
                  Text(l10n.artist),
                  if (_sortBy == 'artist') ...[
                    const Spacer(),
                    Icon(
                      _sortAscending
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: 'album',
              child: Row(
                children: [
                  Icon(_sortBy == 'album' ? Icons.check : null),
                  const SizedBox(width: 8),
                  Text(l10n.album),
                  if (_sortBy == 'album') ...[
                    const Spacer(),
                    Icon(
                      _sortAscending
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: 'duration',
              child: Row(
                children: [
                  Icon(_sortBy == 'duration' ? Icons.check : null),
                  const SizedBox(width: 8),
                  Text(l10n.duration),
                  if (_sortBy == 'duration') ...[
                    const Spacer(),
                    Icon(
                      _sortAscending
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _loadTracks,
          icon: const Icon(Icons.refresh),
          tooltip: l10n.tooltipRefresh,
        ),
      ],
      child: _buildContent(theme, l10n),
    );
  }

  Widget _buildContent(ThemeData theme, AppLocalizations l10n) {
    if (_isLoading && _tracks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(l10n.errorLoadingTracks, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadTracks, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noTracksFound,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.libraryAppearsEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 48), // For play button space
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _handleSort('title'),
                  child: Row(
                    children: [
                      Text(
                        l10n.title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'title') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _handleSort('artist'),
                  child: Row(
                    children: [
                      Text(
                        l10n.artist,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'artist') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _handleSort('album'),
                  child: Row(
                    children: [
                      Text(
                        l10n.album,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'album') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: InkWell(
                  onTap: () => _handleSort('duration'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        l10n.duration,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'duration') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),

        // Track list
        Expanded(
          child: Consumer<AppState>(
            builder: (context, appState, child) {
              return ListView.builder(
                itemCount: _tracks.length,
                itemBuilder: (context, index) {
                  final track = _tracks[index];
                  return _buildTrackItem(track, index, appState, theme, l10n);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackItem(
    Track track,
    int index,
    AppState appState,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SizedBox(
          width: 48,
          child: IconButton(
            onPressed: () {
              appState.playTrack(track);
            },
            icon: const Icon(Icons.play_arrow),
            tooltip: l10n.playTrack,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                track.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                track.artistName ?? l10n.unknownArtist,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                track.albumName ?? l10n.unknownAlbum,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                _formatDuration(track.duration),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        onTap: () {
          appState.playTrack(track);
        },
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'play',
              child: ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(l10n.play),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'addToQueue',
              child: ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(l10n.addToQueue),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'addToPlaylist',
              child: ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(l10n.addToPlaylist),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'showAlbum',
              child: ListTile(
                leading: const Icon(Icons.album),
                title: Text(l10n.showAlbum),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'showArtist',
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(l10n.showArtist),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            (() {
              final downloadStatus = appState.downloadService.getDownloadStatus(track.id);
              final isDownloaded = downloadStatus == DownloadStatus.downloaded;
              final isDownloading = downloadStatus == DownloadStatus.downloading;
              
              IconData downloadIcon;
              String downloadLabel;
              if (isDownloaded) {
                downloadIcon = Icons.download_done_rounded;
                downloadLabel = 'Downloaded';
              } else if (isDownloading) {
                downloadIcon = Icons.downloading_rounded;
                downloadLabel = l10n.downloading;
              } else {
                downloadIcon = Icons.download_rounded;
                downloadLabel = l10n.download;
              }
              
              return PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(downloadIcon),
                  title: Text(downloadLabel),
                  contentPadding: EdgeInsets.zero,
                ),
              );
            })(),
          ],
          onSelected: (value) {
            switch (value) {
              case 'play':
                appState.playTrack(track);
                break;
              case 'addToQueue':
                appState.addToQueue(track);
                break;
              case 'addToPlaylist':
                DesktopLayout.showAddToPlaylistDialog(context, track);
                break;
              case 'showAlbum':
                _navigateToAlbum(appState, track);
                break;
              case 'showArtist':
                _navigateToArtist(appState, track);
                break;
              case 'download':
                _handleDownload(context, appState, track);
                break;
            }
          },
        ),
      ),
    );
  }

  void _playAllTracks(AppState appState) {
    if (_tracks.isEmpty) return;

    // Play all tracks starting from the first one
    appState.playPlaylist(_tracks, 0);
  }

  void _shuffleAllTracks(AppState appState) {
    if (_tracks.isEmpty) return;

    // Create a shuffled copy of the tracks
    final shuffledTracks = List<Track>.from(_tracks)..shuffle();
    appState.playPlaylist(shuffledTracks, 0);
  }

  void _playFavoriteTracks(AppState appState) {
    final favoriteTracks = _tracks.where((track) => track.isFavorite).toList();

    if (favoriteTracks.isEmpty) {
      return;
    }

    // Shuffle favorite tracks before playing
    favoriteTracks.shuffle();
    appState.playPlaylist(favoriteTracks, 0);
  }

  void _navigateToAlbum(AppState appState, Track track) {
    final l10n = AppLocalizations.of(context);
    if (track.albumId == null) {
      NotificationService.showError(context, l10n.albumInfoNotAvailable);
      return;
    }

    // Find the album in the app state
    final album = appState.albums.cast<Album?>().firstWhere(
      (album) => album?.id == track.albumId,
      orElse: () => null,
    );

    if (album == null) {
      NotificationService.showError(context, l10n.albumNotFound);
      return;
    }

    // Navigate to album details page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaDetailsPage.album(album: album),
      ),
    );
  }

  void _navigateToArtist(AppState appState, Track track) {
    final l10n = AppLocalizations.of(context);
    if (track.artistName == null) {
      NotificationService.showError(context, l10n.artistInfoNotAvailable);
      return;
    }

    // Find the artist in the app state by name
    final artist = appState.artists.cast<Artist?>().firstWhere(
      (artist) => artist?.name == track.artistName,
      orElse: () => null,
    );

    if (artist == null) {
      NotificationService.showError(
        context,
        l10n.artistNotFound(track.artistName ?? l10n.unknownArtist),
      );
      return;
    }

    // Navigate to artist details page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArtistDetailsPage(artist: artist),
      ),
    );
  }

  void _handleDownload(BuildContext context, AppState appState, Track track) {
    final l10n = AppLocalizations.of(context);
    final downloadStatus = appState.downloadService.getDownloadStatus(track.id);
    
    switch (downloadStatus) {
      case DownloadStatus.downloaded:
        _showDownloadedOptions(context, appState, track);
        break;
      case DownloadStatus.downloading:
        _showDownloadingOptions(context, appState, track);
        break;
      case DownloadStatus.paused:
      case DownloadStatus.failed:
      case DownloadStatus.notDownloaded:
        appState.downloadService.downloadTrack(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.downloadStarted}: ${track.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  void _showDownloadedOptions(BuildContext context, AppState appState, Track track) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Downloaded'),
        content: Text('"${track.name}" is already downloaded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.downloadService.deleteDownload(track.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.deleteDownload),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(l10n.deleteDownload),
          ),
        ],
      ),
    );
  }

  void _showDownloadingOptions(BuildContext context, AppState appState, Track track) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.downloading),
        content: Text('"${track.name}" is currently downloading.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.downloadService.cancelDownload(track.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.cancelDownload),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(l10n.cancelDownload),
          ),
        ],
      ),
    );
  }
}
