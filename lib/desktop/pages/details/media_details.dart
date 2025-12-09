import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../templates/desktop_layout.dart';

import 'artist_details.dart';

import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../l10n/app_localizations.dart';

enum MediaType { playlist, album }

class MediaDetailsPage extends StatefulWidget {
  final Playlist? playlist;
  final Album? album;
  final MediaType mediaType;

  const MediaDetailsPage.playlist({
    super.key,
    required this.playlist,
  }) : album = null, mediaType = MediaType.playlist;

  const MediaDetailsPage.album({
    super.key,
    required this.album,
  }) : playlist = null, mediaType = MediaType.album;

  @override
  State<MediaDetailsPage> createState() => _MediaDetailsPageState();
}

class _MediaDetailsPageState extends State<MediaDetailsPage> {
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == MediaType.album) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTracks();
      });
    } else {
      _loadTracks();
    }
  }

  void _loadTracks() async {
    if (!mounted) return;
    
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.mediaType == MediaType.playlist) {
        // Load playlist tracks
        _tracks = await appState.getPlaylistTracks(widget.playlist!.id);
      } else {
        // Load album tracks
        if (kDebugMode) {
          print('=== ALBUM TRACKS LOADING DEBUG ===');
          print('Album: ${widget.album!.name}');
          print('Album ID: ${widget.album!.id}');
          print('AppState connected: ${appState.isLoggedIn}');
          print('Current server type: ${appState.mediaServiceManager.currentServerType}');
          print('Total tracks in AppState: ${appState.tracks.length}');
          print('=== CALLING getAlbumTracks ===');
        }
        
        _tracks = await appState.getAlbumTracks(widget.album!.id);
        
        if (kDebugMode) {
          print('=== ALBUM TRACKS RESULT ===');
          print('Loaded ${_tracks.length} tracks for album: ${widget.album!.name}');
          if (_tracks.isNotEmpty) {
            print('First track: ${_tracks.first.name}');
            print('Sample track IDs: ${_tracks.take(3).map((t) => t.id).toList()}');
          }
          
          // Also check if we can find tracks manually by filtering appState.tracks
          final manualTracks = appState.tracks.where((track) => track.albumId == widget.album!.id).toList();
          print('Manual filter found ${manualTracks.length} tracks with albumId: ${widget.album!.id}');
          if (manualTracks.isNotEmpty) {
            print('Manual track example: ${manualTracks.first.name}');
          }
          print('=== END ALBUM TRACKS DEBUG ===');
        }
        
        // Sort by track number if available (already sorted by API, but just in case)
        _tracks.sort((a, b) {
          final aTrack = a.trackNumber ?? 999;
          final bTrack = b.trackNumber ?? 999;
          return aTrack.compareTo(bTrack);
        });
        
        if (_tracks.isEmpty) {
          if (kDebugMode) {
            print('WARNING: No tracks found for album: ${widget.album!.name} (ID: ${widget.album!.id})');
            print('Trying fallback method...');
            
            // Try manual filtering as fallback
            final fallbackTracks = appState.tracks.where((track) => 
              track.albumId == widget.album!.id || 
              track.albumName?.toLowerCase() == widget.album!.name.toLowerCase()
            ).toList();
            
            if (fallbackTracks.isNotEmpty) {
              print('Fallback found ${fallbackTracks.length} tracks!');
              _tracks = fallbackTracks;
            }
          }
        }
      }
    } catch (e) {
      // Handle error
      if (kDebugMode) {
        print('Error loading ${widget.mediaType.name} tracks: $e');
      }
      _tracks = [];
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
    _loadTracks();
  }

  String get _title {
    return widget.mediaType == MediaType.playlist 
        ? widget.playlist!.name 
        : widget.album!.name;
  }

  int get _selectedIndex {
    return widget.mediaType == MediaType.playlist ? 3 : 4; // Playlists: 3, Albums: 4
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final theme = Theme.of(context);
        
        return DesktopLayout(
          showBackButton: true,
          title: _title,
          selectedIndex: _selectedIndex,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48, // Account for padding
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                      // Action buttons row
                      _buildActionButtons(theme, l10n),
                      
                      const SizedBox(height: 24),
                      
                      // Media header
                      _buildMediaHeader(theme, appState, l10n),
                      
                      const SizedBox(height: 24),
                      
                      // Track list section (now part of the scrollable content)
                      _buildTrackList(theme, appState, l10n),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildActionButtons(ThemeData theme, AppLocalizations l10n) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < (widget.mediaType == MediaType.playlist ? 500 : 600);
            
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Play button
                ElevatedButton.icon(
                  onPressed: _tracks.isNotEmpty ? () async {
                    if (widget.mediaType == MediaType.album && kDebugMode) {
                      if (kDebugMode) {
                        print('=== ${widget.mediaType.name.toUpperCase()} PLAY BUTTON CLICKED ===');
                      }
                      if (kDebugMode) {
                        print('${widget.mediaType.name}: $_title');
                      }
                      if (kDebugMode) {
                        print('Track count: ${_tracks.length}');
                      }
                      if (kDebugMode) {
                        print('First track: ${_tracks.isNotEmpty ? _tracks[0].name : "None"}');
                      }
                      if (_tracks.isNotEmpty) {
                        if (kDebugMode) {
                          print('First track ID: ${_tracks[0].id}');
                        }
                        if (kDebugMode) {
                          print('First track duration: ${_tracks[0].duration}');
                        }
                      }
                    }
                    await appState.playPlaylist(_tracks, 0);
                    if (widget.mediaType == MediaType.album && kDebugMode) {
                      if (kDebugMode) {
                        print('=== ${widget.mediaType.name.toUpperCase()} PLAY BUTTON COMPLETED ===');
                      }
                    }
                  } : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(isNarrow ? l10n.play : (widget.mediaType == MediaType.playlist ? l10n.playAll : l10n.playAlbum)),
                ),
                // Shuffle button
                OutlinedButton.icon(
                  onPressed: _tracks.isNotEmpty ? () async {
                    final shuffledTracks = List<Track>.from(_tracks)..shuffle();
                    await appState.playPlaylist(shuffledTracks, 0);
                  } : null,
                  icon: const Icon(Icons.shuffle),
                  label: Text(l10n.shuffle),
                ),
                // Conditional buttons based on media type
                if (widget.mediaType == MediaType.album) ...[
                  // Favorite button (for albums)
                  IconButton(
                    onPressed: () {
                      // Note: Albums don't typically have favorites in most services
                      // This would need to be implemented based on your service's capabilities
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.albumFavoritesNotImplemented),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                    icon: Icon(
                      widget.album!.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: widget.album!.isFavorite ? Colors.red : null,
                    ),
                    tooltip: widget.album!.isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
                  ),
                ],
                // Refresh button (for debugging when tracks are empty)
                if (_tracks.isEmpty && !_isLoading)
                  IconButton(
                    onPressed: _refreshTracks,
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.reloadTracks,
                  ),
                // More options
                _buildMoreOptionsMenu(l10n),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMoreOptionsMenu(AppLocalizations l10n) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'add_playlist':
            _showAddToPlaylistDialog(l10n);
            break;
          case 'download':
            if (widget.mediaType == MediaType.album) {
              _downloadAlbum(l10n);
            }
            break;
          case 'share':
            // Share media
            break;
          case 'artist':
            if (widget.mediaType == MediaType.album) {
              _navigateToArtist(l10n);
            }
            break;
          case 'edit':
            if (widget.mediaType == MediaType.playlist) {
              _showEditPlaylistDialog(l10n);
            }
            break;
          case 'delete':
            if (widget.mediaType == MediaType.playlist) {
              _showDeletePlaylistDialog(l10n);
            }
            break;
        }
      },
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = [];
        
        // Common items
        if (widget.mediaType == MediaType.album) {
          items.add(PopupMenuItem(
            value: 'add_playlist',
            child: ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(l10n.addToPlaylist),
              contentPadding: EdgeInsets.zero,
            ),
          ));
          items.add(PopupMenuItem(
            value: 'download',
            child: ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.download),
              contentPadding: EdgeInsets.zero,
            ),
          ));
        }
        
        items.add(PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: const Icon(Icons.share),
            title: Text(l10n.share),
            contentPadding: EdgeInsets.zero,
          ),
        ));
        
        // Media type specific items
        if (widget.mediaType == MediaType.album) {
          items.add(PopupMenuItem(
            value: 'artist',
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(l10n.goToArtist),
              contentPadding: EdgeInsets.zero,
            ),
          ));
        } else {
          items.add(PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.editPlaylist),
              contentPadding: EdgeInsets.zero,
            ),
          ));
          items.add(PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.deletePlaylist, style: const TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
            ),
          ));
        }
        
        return items;
      },
    );
  }

  Widget _buildMediaHeader(ThemeData theme, AppState appState, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Media artwork - responsive size
            LayoutBuilder(
              builder: (context, constraints) {
                // Use different sizes based on media type and screen size
                final artworkSize = widget.mediaType == MediaType.playlist
                    ? (constraints.maxWidth < 800 ? 150.0 : 200.0)
                    : (constraints.maxWidth < 800 ? 180.0 : 250.0);
                final iconSize = widget.mediaType == MediaType.playlist
                    ? (constraints.maxWidth < 800 ? 60.0 : 80.0)
                    : (constraints.maxWidth < 800 ? 70.0 : 100.0);
                
                final imageUrl = widget.mediaType == MediaType.playlist
                    ? widget.playlist!.imageUrl
                    : widget.album!.imageUrl;
                
                final defaultIcon = widget.mediaType == MediaType.playlist
                    ? Icons.playlist_play
                    : Icons.album;
                
                return Container(
                  width: artworkSize,
                  height: artworkSize,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: widget.mediaType == MediaType.album ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ] : null,
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _getImageUrl(appState, imageUrl)!,
                            width: artworkSize,
                            height: artworkSize,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                defaultIcon,
                                size: iconSize,
                                color: theme.colorScheme.onSurfaceVariant,
                              );
                            },
                          ),
                        )
                      : Icon(
                          defaultIcon,
                          size: iconSize,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                );
              },
            ),
            
            SizedBox(width: widget.mediaType == MediaType.album ? 20 : 16),
            
            // Media info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.mediaType == MediaType.playlist ? l10n.playlist : l10n.album,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _title,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.mediaType == MediaType.album) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _navigateToArtist(l10n),
                      child: Text(
                        widget.album!.artistName ?? l10n.unknownArtist,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (widget.mediaType == MediaType.album && widget.album!.year != null) ...[
                        Text(
                          widget.album!.year.toString(),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(
                        l10n.countSongs(_tracks.length),
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
                  if (widget.mediaType == MediaType.album) ...[
                    const SizedBox(height: 8),
                    if (widget.album!.dateCreated != null)
                      Text(
                        '${l10n.added} ${_formatDate(widget.album!.dateCreated!, l10n)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(ThemeData theme, AppState appState, AppLocalizations l10n) {
    if (_tracks.isEmpty && !_isLoading) {
      return Column(
        children: [
          const SizedBox(height: 64), // Add some spacing from the header
          Icon(
            Icons.music_note,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.mediaType == MediaType.playlist ? l10n.noTracksInPlaylist : l10n.noTracksFound,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.mediaType == MediaType.playlist 
                ? l10n.addSongsToGetStarted
                : l10n.albumTracksEmptyMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (widget.mediaType == MediaType.playlist)
            ElevatedButton.icon(
              onPressed: () {
                // Add tracks to playlist
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.addSongs),
            )
          else
            ElevatedButton.icon(
              onPressed: _refreshTracks,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
        ],
      );
    }

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track list header
          _buildTrackListHeader(theme, l10n),
          
          const Divider(height: 1),
          
          // Track list items (using Column instead of ListView for scrollable parent)
          ...List.generate(_tracks.length, (index) {
            final track = _tracks[index];
            return _buildTrackItem(theme, appState, track, index, l10n);
          }),
        ],
      ),
    );
  }

  Widget _buildTrackListHeader(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (widget.mediaType == MediaType.playlist) ...[
            const SizedBox(width: 60), // Space for artwork
            const SizedBox(width: 16),
          ],
          SizedBox(
            width: 40,
            child: Text(
              '#',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              l10n.title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.mediaType == MediaType.playlist) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Text(
                l10n.artist,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Text(
                l10n.album,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            child: Text(
              l10n.duration,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 48), // Space for menu button
        ],
      ),
    );
  }

  Widget _buildTrackItem(ThemeData theme, AppState appState, Track track, int index, AppLocalizations l10n) {
    return InkWell(
      onTap: () async {
        if (widget.mediaType == MediaType.album && kDebugMode) {
          if (kDebugMode) {
            print('=== TRACK CLICKED ===');
          }
          if (kDebugMode) {
            print('Track: ${track.name}');
          }
          if (kDebugMode) {
            print('Track ID: ${track.id}');
          }
          if (kDebugMode) {
            print('Track number: ${index + 1}');
          }
          if (kDebugMode) {
            print('Album: ${widget.album!.name}');
          }
        }
        await appState.playPlaylist(_tracks, index);
        if (widget.mediaType == MediaType.album && kDebugMode) {
          if (kDebugMode) {
            print('=== TRACK CLICK COMPLETED ===');
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Track artwork (only for playlists)
            if (widget.mediaType == MediaType.playlist) ...[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: track.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _getImageUrl(appState, track.imageUrl)!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.music_note,
                              color: theme.colorScheme.onSurfaceVariant,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.music_note,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: 16),
            ],
            
            // Track number
            SizedBox(
              width: 40,
              child: Text(
                track.trackNumber?.toString() ?? (index + 1).toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Track title
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
                  if (widget.mediaType == MediaType.album && track.artistName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      track.artistName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Artist (only for playlists)
            if (widget.mediaType == MediaType.playlist) ...[
              const SizedBox(width: 16),
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
              
              // Album (only for playlists)
              const SizedBox(width: 16),
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
            ],
            
            const SizedBox(width: 16),
            
            // Duration
            SizedBox(
              width: 60,
              child: Text(
                _formatDuration(track.duration ?? 0),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            
            // Menu button
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'remove':
                    if (widget.mediaType == MediaType.playlist) {
                      _removeTrackFromPlaylist(track, l10n);
                    }
                    break;
                  case 'download':
                    // Download track
                    break;
                }
              },
              itemBuilder: (context) {
                List<PopupMenuEntry<String>> items = [];
                
                if (widget.mediaType == MediaType.playlist) {
                  items.add(PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: const Icon(Icons.remove),
                      title: Text(l10n.removeFromPlaylist),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ));
                }
                
                items.add(PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: const Icon(Icons.download),
                    title: Text(l10n.download),
                    contentPadding: EdgeInsets.zero,
                  ),
                ));
                
                return items;
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getTotalDuration() {
    final totalMs = _tracks.fold<int>(
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

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return l10n.today;
    } else if (difference.inDays < 7) {
      return l10n.daysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      return l10n.weeksAgo((difference.inDays / 7).floor());
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Album-specific methods
  void _navigateToArtist(AppLocalizations l10n) {
    if (widget.mediaType != MediaType.album) return;
    
    if (widget.album!.artistName == null) {
      if (kDebugMode) {
        print('No artist name available for album: ${widget.album!.name}');
      }
      return;
    }

    final appState = context.read<AppState>();
    
    // Find the artist by name in the artists list
    final artist = appState.artists.firstWhere(
      (artist) => artist.name.toLowerCase() == widget.album!.artistName!.toLowerCase(),
      orElse: () => Artist(
        id: '', // We'll use empty ID as a fallback
        name: widget.album!.artistName!,
      ),
    );

    if (artist.id.isEmpty) {
      if (kDebugMode) {
        print('Artist not found in artists list: ${widget.album!.artistName}');
      }
      // Show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.artistNotFound(widget.album!.artistName!)),
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

  void _downloadAlbum(AppLocalizations l10n) async {
    if (widget.mediaType != MediaType.album) return;
    
    final appState = context.read<AppState>();
    
    if (_tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noTracksToDownload),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadAlbum),
        content: Text(l10n.downloadAlbumConfirmation(_tracks.length, widget.album!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.downloadAllTracks),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Open all tracks in browser for download
    int successCount = 0;
    int failCount = 0;

    for (final track in _tracks) {
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
            content: Text(l10n.openedTracksInBrowser(successCount, widget.album!.name)),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.openedTracksPartialSuccess(successCount, failCount, widget.album!.name)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showAddToPlaylistDialog() {
    final appState = context.read<AppState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${widget.mediaType == MediaType.album ? 'Album' : 'Tracks'} to Playlist'),
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
                        // Add tracks to playlist
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${widget.mediaType == MediaType.album ? 'album' : 'tracks'} to "${playlist.name}"'),
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
                // Create playlist with tracks
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Created playlist "${nameController.text}" with ${widget.mediaType == MediaType.album ? 'album' : ''} tracks'),
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

  // Playlist-specific methods
  void _showEditPlaylistDialog() {
    if (widget.mediaType != MediaType.playlist) return;
    
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
              controller: TextEditingController(text: widget.playlist!.name),
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
    if (widget.mediaType != MediaType.playlist) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${widget.playlist!.name}"? This action cannot be undone.'),
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
    if (widget.mediaType != MediaType.playlist) return;
    
    setState(() {
      _tracks.remove(track);
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