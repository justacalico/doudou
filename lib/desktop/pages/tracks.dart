import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../templates/page_template.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../../services/notification_service.dart';

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
      final tracks = await appState.jellyfinService.getAllTracks();
      
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
          comparison = (a.artistName ?? '').toLowerCase().compareTo((b.artistName ?? '').toLowerCase());
          break;
        case 'album':
          comparison = (a.albumName ?? '').toLowerCase().compareTo((b.albumName ?? '').toLowerCase());
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

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--:--';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return PageTemplate(
      title: 'Tracks',
      actions: [
        // Play All button
        Consumer<AppState>(
          builder: (context, appState, child) {
            return IconButton(
              onPressed: _tracks.isNotEmpty ? () => _playAllTracks(appState) : null,
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Play all tracks',
              iconSize: 28,
            );
          },
        ),
        
        // Shuffle button
        Consumer<AppState>(
          builder: (context, appState, child) {
            return IconButton(
              onPressed: _tracks.isNotEmpty ? () => _shuffleAllTracks(appState) : null,
              icon: const Icon(Icons.shuffle),
              tooltip: 'Shuffle all tracks',
              iconSize: 28,
            );
          },
        ),
        
        // Play Favorites button
        Consumer<AppState>(
          builder: (context, appState, child) {
            final favoriteCount = _tracks.where((track) => track.isFavorite).length;
            return IconButton(
              onPressed: favoriteCount > 0 ? () => _playFavoriteTracks(appState) : null,
              icon: Icon(
                Icons.favorite,
                color: favoriteCount > 0 ? Colors.red : null,
              ),
              tooltip: favoriteCount > 0 ? 'Play favorites ($favoriteCount)' : 'No favorite tracks',
              iconSize: 28,
            );
          },
        ),
        
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort by',
          onSelected: _handleSort,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'title',
              child: Row(
                children: [
                  Icon(_sortBy == 'title' ? Icons.check : null),
                  const SizedBox(width: 8),
                  const Text('Title'),
                  if (_sortBy == 'title') ...[
                    const Spacer(),
                    Icon(_sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
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
                  const Text('Artist'),
                  if (_sortBy == 'artist') ...[
                    const Spacer(),
                    Icon(_sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
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
                  const Text('Album'),
                  if (_sortBy == 'album') ...[
                    const Spacer(),
                    Icon(_sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
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
                  const Text('Duration'),
                  if (_sortBy == 'duration') ...[
                    const Spacer(),
                    Icon(_sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                  ],
                ],
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _loadTracks,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      child: _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading && _tracks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading tracks',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTracks,
              child: const Text('Retry'),
            ),
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
              'No tracks found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your music library appears to be empty',
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
                        'Title',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'title') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
                        'Artist',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'artist') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
                        'Album',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'album') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: InkWell(
                  onTap: () => _handleSort('duration'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Duration',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_sortBy == 'duration') ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
                  return _buildTrackItem(track, index, appState, theme);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackItem(Track track, int index, AppState appState, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
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
            tooltip: 'Play track',
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
                track.artistName ?? 'Unknown Artist',
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
                track.albumName ?? 'Unknown Album',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 80,
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
            const PopupMenuItem(
              value: 'play',
              child: ListTile(
                leading: Icon(Icons.play_arrow),
                title: Text('Play'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'addToQueue',
              child: ListTile(
                leading: Icon(Icons.queue_music),
                title: Text('Add to queue'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'addToPlaylist',
              child: ListTile(
                leading: Icon(Icons.playlist_add),
                title: Text('Add to playlist'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'showAlbum',
              child: ListTile(
                leading: Icon(Icons.album),
                title: Text('Show album'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'showArtist',
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text('Show artist'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'play':
                appState.playTrack(track);
                break;
              case 'addToQueue':
                // TODO: Implement add to queue
                NotificationService.showInfo(context, 'Add to queue - Coming soon');
                break;
              case 'addToPlaylist':
                // TODO: Implement add to playlist
                NotificationService.showInfo(context, 'Add to playlist - Coming soon');
                break;
              case 'showAlbum':
                // TODO: Navigate to album
                NotificationService.showInfo(context, 'Show album - Coming soon');
                break;
              case 'showArtist':
                // TODO: Navigate to artist
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
}