import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../templates/desktop_layout.dart';
import '../../templates/track_list_template.dart';
import 'artist_details.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAlbumTracks();
    });
  }

  void _loadAlbumTracks() async {
    if (!mounted) return;
    
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('=== ALBUM TRACKS LOADING DEBUG ===');
        print('Album: ${widget.album.name}');
        print('Album ID: ${widget.album.id}');
        print('AppState connected: ${appState.isLoggedIn}');
        print('Current server type: ${appState.mediaServiceManager.currentServerType}');
        print('Total tracks in AppState: ${appState.tracks.length}');
        print('=== CALLING getAlbumTracks ===');
      }
      
      // Fetch tracks for this album using the appropriate service
      _albumTracks = await appState.getAlbumTracks(widget.album.id);
      
      if (kDebugMode) {
        print('=== ALBUM TRACKS RESULT ===');
        print('Loaded ${_albumTracks.length} tracks for album: ${widget.album.name}');
        if (_albumTracks.isNotEmpty) {
          print('First track: ${_albumTracks.first.name}');
          print('Sample track IDs: ${_albumTracks.take(3).map((t) => t.id).toList()}');
        }
        
        // Also check if we can find tracks manually by filtering appState.tracks
        final manualTracks = appState.tracks.where((track) => track.albumId == widget.album.id).toList();
        print('Manual filter found ${manualTracks.length} tracks with albumId: ${widget.album.id}');
        if (manualTracks.isNotEmpty) {
          print('Manual track example: ${manualTracks.first.name}');
        }
        print('=== END ALBUM TRACKS DEBUG ===');
      }
      
      // Sort by track number if available (already sorted by API, but just in case)
      _albumTracks.sort((a, b) {
        final aTrack = a.trackNumber ?? 999;
        final bTrack = b.trackNumber ?? 999;
        return aTrack.compareTo(bTrack);
      });
      
      if (_albumTracks.isEmpty) {
        if (kDebugMode) {
          print('WARNING: No tracks found for album: ${widget.album.name} (ID: ${widget.album.id})');
          print('Trying fallback method...');
          
          // Try manual filtering as fallback
          final fallbackTracks = appState.tracks.where((track) => 
            track.albumId == widget.album.id || 
            track.albumName?.toLowerCase() == widget.album.name.toLowerCase()
          ).toList();
          
          if (fallbackTracks.isNotEmpty) {
            print('Fallback found ${fallbackTracks.length} tracks!');
            _albumTracks = fallbackTracks;
          }
        }
      }
    } catch (e) {
      // Handle error
      if (kDebugMode) {
        print('Error loading album tracks: $e');
      }
      _albumTracks = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  void _refreshTracks() {
    _loadAlbumTracks();
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
            // Refresh button (for debugging)
            if (_albumTracks.isEmpty && !_isLoading)
              IconButton(
                onPressed: _refreshTracks,
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload tracks',
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
    if (_albumTracks.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
              'This album appears to be empty or the tracks couldn\'t be loaded.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshTracks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TrackListTemplate(
      tracks: _albumTracks,
      emptyStateTitle: 'No tracks found',
      emptyStateMessage: 'This album appears to be empty or the tracks couldn\'t be loaded',
      showTrackNumber: true,
      showArtist: false,
      showAlbum: false,
      showArtwork: false,
      onTrackTap: (track, index) async {
        if (kDebugMode) {
          print('=== TRACK CLICKED ===');
          print('Track: ${track.name}');
          print('Track ID: ${track.id}');
          print('Track number: ${index + 1}');
          print('Album: ${widget.album.name}');
        }
        await appState.playPlaylist(_albumTracks, index);
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
    if (widget.album.artistName == null) {
      if (kDebugMode) {
        print('No artist name available for album: ${widget.album.name}');
      }
      return;
    }

    final appState = context.read<AppState>();
    
    // Find the artist by name in the artists list
    final artist = appState.artists.firstWhere(
      (artist) => artist.name.toLowerCase() == widget.album.artistName!.toLowerCase(),
      orElse: () => Artist(
        id: '', // We'll use empty ID as a fallback
        name: widget.album.artistName!,
      ),
    );

    if (artist.id.isEmpty) {
      if (kDebugMode) {
        print('Artist not found in artists list: ${widget.album.artistName}');
      }
      // Show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Artist "${widget.album.artistName}" not found'),
          duration: const Duration(seconds: 2),
        ),
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
        content: Text('Open all ${_albumTracks.length} tracks from "${widget.album.name}" in browser for download?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Open all tracks in browser for download
    int successCount = 0;
    int failCount = 0;

    for (final track in _albumTracks) {
      try {
        final streamUrl = appState.mediaServiceManager.getStreamUrl(track.id);
        final uri = Uri.parse(streamUrl);
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          successCount++;
          // Add a small delay between opening URLs to prevent overwhelming the browser
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          failCount++;
          if (kDebugMode) {
            print('Cannot launch URL for track "${track.name}": $streamUrl');
          }
        }
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
            content: Text('Opened all $successCount tracks from "${widget.album.name}" in browser'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opened $successCount tracks, $failCount failed from "${widget.album.name}"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
