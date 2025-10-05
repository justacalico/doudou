import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';

class AlbumDetailsPage extends StatefulWidget {
  final Album album;

  const AlbumDetailsPage({
    super.key,
    required this.album,
  });

  @override
  State<AlbumDetailsPage> createState() => _AlbumDetailsPageState();
}

class _AlbumDetailsPageState extends State<AlbumDetailsPage> {
  List<Track> _albumTracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumTracks();
  }

  void _loadAlbumTracks() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
    });

    try {
      // Get tracks for this album
      _albumTracks = appState.tracks
          .where((track) => track.albumId == widget.album.id)
          .toList();
      
      // Sort by track number if available
      _albumTracks.sort((a, b) {
        final aTrack = a.trackNumber ?? 999;
        final bTrack = b.trackNumber ?? 999;
        return aTrack.compareTo(bTrack);
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.jellyfinService.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final theme = Theme.of(context);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and actions
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.album.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Action buttons
                  ElevatedButton.icon(
                    onPressed: () {
                      // Play all tracks in album
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Album'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Shuffle play album
                    },
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Shuffle'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      // Toggle favorite
                    },
                    icon: Icon(
                      widget.album.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: widget.album.isFavorite ? Colors.red : null,
                    ),
                    tooltip: widget.album.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'add_playlist':
                          _showAddToPlaylistDialog();
                          break;
                        case 'download':
                          // Download album
                          break;
                        case 'share':
                          // Share album
                          break;
                        case 'artist':
                          _navigateToArtist();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add_playlist',
                        child: ListTile(
                          leading: Icon(Icons.playlist_add),
                          title: Text('Add to Playlist'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'download',
                        child: ListTile(
                          leading: Icon(Icons.download),
                          title: Text('Download'),
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
                      const PopupMenuItem(
                        value: 'artist',
                        child: ListTile(
                          leading: Icon(Icons.person),
                          title: Text('Go to Artist'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Album header
                    _buildAlbumHeader(theme, appState),
                    
                    const SizedBox(height: 32),
                    
                    // Track list
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildTrackList(theme, appState),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlbumHeader(ThemeData theme, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Album artwork
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: widget.album.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _getImageUrl(appState, widget.album.imageUrl)!,
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.album,
                            size: 100,
                            color: theme.colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.album,
                      size: 100,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            
            const SizedBox(width: 32),
            
            // Album info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Album',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.album.name,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _navigateToArtist,
                    child: Text(
                      widget.album.artistName ?? 'Unknown Artist',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (widget.album.year != null) ...[
                        Text(
                          widget.album.year.toString(),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(
                        '${_albumTracks.length} songs',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _getTotalDuration(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.album.dateCreated != null)
                    Text(
                      'Added ${_formatDate(widget.album.dateCreated!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
    if (_albumTracks.isEmpty) {
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
                'No tracks found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'This album appears to be empty',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                  child: Text(
                    'Title',
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
              itemCount: _albumTracks.length,
              itemBuilder: (context, index) {
                final track = _albumTracks[index];
                return _buildTrackItem(theme, appState, track, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(ThemeData theme, AppState appState, Track track, int trackNumber) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 40,
        child: Text(
          trackNumber.toString(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      title: Text(
        track.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.duration != null ? _formatDuration(track.duration!) : '--:--',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'play':
                  // Play track
                  break;
                case 'play_next':
                  // Play next
                  break;
                case 'add_queue':
                  // Add to queue
                  break;
                case 'add_playlist':
                  // Add to playlist
                  break;
                case 'download':
                  // Download track
                  break;
                case 'favorite':
                  // Toggle favorite
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
                value: 'play_next',
                child: ListTile(
                  leading: Icon(Icons.skip_next),
                  title: Text('Play Next'),
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
                value: 'add_playlist',
                child: ListTile(
                  leading: Icon(Icons.playlist_add),
                  title: Text('Add to Playlist'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Download'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'favorite',
                child: ListTile(
                  leading: Icon(track.isFavorite ? Icons.favorite : Icons.favorite_border),
                  title: Text(track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        // Play track
      },
    );
  }

  String _getTotalDuration() {
    final totalMs = _albumTracks.fold<int>(
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToArtist() {
    // Navigate to artist page
    // This would require finding the artist and navigating to ArtistDetailsPage
  }

  void _showAddToPlaylistDialog() {
    final appState = context.read<AppState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Album to Playlist'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create New Playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePlaylistDialog();
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: appState.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = appState.playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.trackCount} songs'),
                      onTap: () {
                        Navigator.pop(context);
                        // Add album to playlist
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added album to "${playlist.name}"'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Playlist Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                // Create playlist with album tracks
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Created playlist "${nameController.text}" with album tracks'),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
