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
    return TrackListTemplate(
      tracks: _playlistTracks,
      emptyStateTitle: 'No tracks in this playlist',
      emptyStateMessage: 'Add some songs to get started',
      emptyStateAction: ElevatedButton.icon(
        onPressed: () {
          // Add tracks to playlist
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Songs'),
      ),
      showTrackNumber: true,
      showArtist: true,
      showAlbum: true,
      showArtwork: true,
      onTrackTap: (track, index) async {
        await appState.playPlaylist(_playlistTracks, index);
      },
      onRemoveTrack: (track) {
        _removeTrackFromPlaylist(track);
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
