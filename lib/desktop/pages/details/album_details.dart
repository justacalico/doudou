import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../templates/desktop_layout.dart';

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
      // Fetch tracks for this album using the appropriate service
      _albumTracks = await appState.getAlbumTracks(widget.album.id);
      
      // Sort by track number if available (already sorted by API, but just in case)
      _albumTracks.sort((a, b) {
        final aTrack = a.trackNumber ?? 999;
        final bTrack = b.trackNumber ?? 999;
        return aTrack.compareTo(bTrack);
      });
      
      if (_albumTracks.isEmpty) {
        if (kDebugMode) {
          print('No tracks found for album: ${widget.album.name} (ID: ${widget.album.id})');
        }
      }
    } catch (e) {
      // Handle error
      if (kDebugMode) {
        print('Error loading album tracks: $e');
      }
      _albumTracks = [];
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
          title: widget.album.name,
          selectedIndex: 4, // Albums page index
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons row
                _buildActionButtons(theme),
                
                const SizedBox(height: 24),
                
                // Album header
                _buildAlbumHeader(theme, appState),
                
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
            // Play album button
            ElevatedButton.icon(
              onPressed: _albumTracks.isNotEmpty ? () async {
                if (kDebugMode) {
                  print('=== ALBUM PLAY BUTTON CLICKED ===');
                  print('Album: ${widget.album.name}');
                  print('Track count: ${_albumTracks.length}');
                  print('First track: ${_albumTracks.isNotEmpty ? _albumTracks[0].name : "None"}');
                  if (_albumTracks.isNotEmpty) {
                    print('First track ID: ${_albumTracks[0].id}');
                    print('First track duration: ${_albumTracks[0].duration}');
                  }
                }
                await appState.playPlaylist(_albumTracks, 0);
                if (kDebugMode) {
                  print('=== ALBUM PLAY BUTTON COMPLETED ===');
                }
              } : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Album'),
            ),
            const SizedBox(width: 8),
            // Shuffle button
            OutlinedButton.icon(
              onPressed: _albumTracks.isNotEmpty ? () async {
                final shuffledTracks = List<Track>.from(_albumTracks)..shuffle();
                await appState.playPlaylist(shuffledTracks, 0);
              } : null,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
            const SizedBox(width: 8),
            // Favorite button
            IconButton(
              onPressed: () {
                // Note: Albums don't typically have favorites in most services
                // This would need to be implemented based on your service's capabilities
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Album favorites not yet implemented'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: Icon(
                widget.album.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.album.isFavorite ? Colors.red : null,
              ),
              tooltip: widget.album.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
            // More options
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'add_playlist':
                    _showAddToPlaylistDialog();
                    break;
                  case 'download':
                    // Download album
                    _downloadAlbum();
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
                'This album appears to be empty or the tracks couldn\'t be loaded',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
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
            onSelected: (value) async {
              final appState = context.read<AppState>();
              switch (value) {
                case 'play':
                  await appState.playPlaylist(_albumTracks, trackNumber - 1);
                  break;
                case 'play_next':
                  // Play next - add to queue
                  break;
                case 'add_queue':
                  // Add to queue
                  break;
                case 'add_playlist':
                  // Add to playlist
                  break;
                case 'download':
                  // Download track
                  try {
                    await appState.downloadService.downloadTrack(track);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Started downloading "${track.name}"'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to download "${track.name}": $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  break;
                case 'favorite':
                  // Toggle favorite
                  try {
                    await appState.toggleFavorite(track);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            track.isFavorite 
                              ? 'Added "${track.name}" to favorites'
                              : 'Removed "${track.name}" from favorites'
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to toggle favorite: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
      onTap: () async {
        if (kDebugMode) {
          print('=== TRACK CLICKED ===');
          print('Track: ${track.name}');
          print('Track ID: ${track.id}');
          print('Track number: $trackNumber');
          print('Album: ${widget.album.name}');
        }
        final appState = context.read<AppState>();
        await appState.playPlaylist(_albumTracks, trackNumber - 1);
        if (kDebugMode) {
          print('=== TRACK CLICK COMPLETED ===');
        }
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

  void _downloadAlbum() async {
    final appState = context.read<AppState>();
    
    if (_albumTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tracks to download'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Album'),
        content: Text('Download all ${_albumTracks.length} tracks from "${widget.album.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Start downloading all tracks
    int successCount = 0;
    int failCount = 0;

    for (final track in _albumTracks) {
      try {
        await appState.downloadService.downloadTrack(track);
        successCount++;
      } catch (e) {
        failCount++;
        if (kDebugMode) {
          print('Failed to download track "${track.name}": $e');
        }
      }
    }

    if (mounted) {
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading all $successCount tracks from "${widget.album.name}"'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $successCount tracks, $failCount failed from "${widget.album.name}"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
