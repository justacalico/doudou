import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../templates/desktop_layout.dart';
import '../../templates/track_list_template.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  List<Track> _playlistTracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylistTracks();
  }

  void _loadPlaylistTracks() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch tracks for this playlist using the appropriate service
      _playlistTracks = await appState.getPlaylistTracks(widget.playlist.id);
    } catch (e) {
      // Handle error
      if (kDebugMode) {
        print('Error loading playlist tracks: $e');
      }
      _playlistTracks = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final theme = Theme.of(context);
        
        return DesktopLayout(
          showBackButton: true,
          title: widget.playlist.name,
          selectedIndex: 3, // Playlists page index
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons row
                _buildActionButtons(theme),
                
                const SizedBox(height: 24),
                
                // Playlist header
                _buildPlaylistHeader(theme, appState),
                
                const SizedBox(height: 32),
                
                // Track list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildTrackList(theme, appState),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Row(
          children: [
            // Play all button
            ElevatedButton.icon(
              onPressed: _playlistTracks.isNotEmpty ? () async {
                await appState.playPlaylist(_playlistTracks, 0);
              } : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play All'),
            ),
            const SizedBox(width: 8),
            // Shuffle button
            OutlinedButton.icon(
              onPressed: _playlistTracks.isNotEmpty ? () async {
                final shuffledTracks = List<Track>.from(_playlistTracks)..shuffle();
                await appState.playPlaylist(shuffledTracks, 0);
              } : null,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
            const SizedBox(width: 8),
            // More options
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditPlaylistDialog();
                    break;
                  case 'delete':
                    _showDeletePlaylistDialog();
                    break;
                  case 'share':
                    // Share playlist
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit Playlist'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistHeader(ThemeData theme, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Playlist artwork
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.playlist.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _getImageUrl(appState, widget.playlist.imageUrl)!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.playlist_play,
                            size: 80,
                            color: theme.colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.playlist_play,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            
            const SizedBox(width: 24),
            
            // Playlist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playlist',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.playlist.name,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${_playlistTracks.length} songs',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _getTotalDuration(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(ThemeData theme, AppState appState) {
    if (_playlistTracks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                'No tracks in this playlist',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Add some songs to get started',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Add tracks to playlist
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Songs'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          // Track list header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '#',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Title',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Artist',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Album',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Duration',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 48), // Space for actions
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Track list
          Expanded(
            child: ListView.builder(
              itemCount: _playlistTracks.length,
              itemBuilder: (context, index) {
                final track = _playlistTracks[index];
                return _buildTrackItem(theme, appState, track, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(ThemeData theme, AppState appState, Track track, int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 40,
        child: Text(
          index.toString(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      title: Row(
        children: [
          // Track artwork
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: track.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      _getImageUrl(appState, track.imageUrl)!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.music_note,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.music_note,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          
          // Track info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
              track.duration != null ? _formatDuration(track.duration!) : '--:--',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'play':
              // Play track
              break;
            case 'add_queue':
              // Add to queue
              break;
            case 'remove':
              _removeTrackFromPlaylist(track);
              break;
          }
        },
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
            value: 'add_queue',
            child: ListTile(
              leading: Icon(Icons.queue_music),
              title: Text('Add to Queue'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.remove, color: Colors.red),
              title: Text('Remove from Playlist', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: () {
        // Play track
      },
    );
  }

  String _getTotalDuration() {
    final totalMs = _playlistTracks.fold<int>(
      0,
      (sum, track) => sum + (track.duration ?? 0),
    );
    
    final duration = Duration(milliseconds: totalMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showEditPlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Playlist Name',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: widget.playlist.name),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: ''),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Save playlist changes
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${widget.playlist.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to playlists page
              // Delete playlist
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _removeTrackFromPlaylist(Track track) {
    setState(() {
      _playlistTracks.remove(track);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${track.name}" from playlist'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Undo remove track
          },
        ),
      ),
    );
  }
}
