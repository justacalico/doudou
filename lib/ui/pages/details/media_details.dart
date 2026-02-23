import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/models/download_models.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';

import 'artist_details.dart';

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
        _tracks = await appState.getPlaylistTracks(widget.playlist!.id);
      } else {
        _tracks = await appState.getAlbumTracks(widget.album!.id);
        
        _tracks.sort((a, b) {
          final aTrack = a.trackNumber ?? 999;
          final bTrack = b.trackNumber ?? 999;
          return aTrack.compareTo(bTrack);
        });
        
        if (_tracks.isEmpty) {
          final fallbackTracks = appState.tracks.where((track) => 
            track.albumId == widget.album!.id || 
            track.albumName?.toLowerCase() == widget.album!.name.toLowerCase()
          ).toList();
          
          if (fallbackTracks.isNotEmpty) {
            _tracks = fallbackTracks;
          }
        }
      }
    } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final theme = Theme.of(context);
        
        return PageTemplate(
          showBackButton: true,
          title: _title,
          onBackPressed: () => Navigator.of(context).pop(),
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
                    await appState.playPlaylist(_tracks, 0);
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
                // Download album button (albums only)
                if (widget.mediaType == MediaType.album && appState.downloadsEnabled)
                  _buildAlbumDownloadButton(appState, l10n),
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
                _buildMoreOptionsMenu(l10n),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumDownloadButton(AppState appState, AppLocalizations l10n) {
    final downloadService = appState.downloadService;
    final toDownload = _tracks.where((t) => !downloadService.isTrackDownloaded(t.id)).toList();
    final isAllDownloaded = toDownload.isEmpty;
    final anyDownloading = _tracks.any((t) =>
        downloadService.getDownloadStatus(t.id) == DownloadStatus.downloading);

    return Tooltip(
      message: isAllDownloaded
          ? l10n.downloadedSection
          : anyDownloading
              ? l10n.downloading
              : l10n.download,
      child: IconButton(
        onPressed: isAllDownloaded
            ? null
            : () async {
                if (toDownload.isEmpty) return;
                for (final track in toDownload) {
                  downloadService.downloadTrack(track);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.startedDownloading(toDownload.length, l10n.songs),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
        icon: Icon(
          isAllDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
          size: 24,
        ),
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
      ),
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
          if (context.read<AppState>().downloadsEnabled) {
            items.add(PopupMenuItem(
              value: 'download',
              child: ListTile(
                leading: const Icon(Icons.download),
                title: Text(l10n.download),
                contentPadding: EdgeInsets.zero,
              ),
            ));
          }
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
            ElevatedButton(
              onPressed: _refreshTracks,
              child: Text(l10n.retry),
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
        await appState.playPlaylist(_tracks, index);
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
                
                if (context.read<AppState>().downloadsEnabled) {
                  items.add(PopupMenuItem(
                    value: 'download',
                    child: ListTile(
                      leading: const Icon(Icons.download),
                      title: Text(l10n.download),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ));
                }
                
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
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }
  }

  // Album-specific methods
  void _navigateToArtist(AppLocalizations l10n) {
    if (widget.mediaType != MediaType.album) return;
    
    if (widget.album!.artistName == null) {
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
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.downloadAlbum,
      message: l10n.downloadAlbumConfirmation(_tracks.length, widget.album!.name),
      confirmLabel: l10n.downloadAllTracks,
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
        }
      } catch (e) {
        failCount++;
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

  void _showAddToPlaylistDialog(AppLocalizations l10n) {
    final appState = context.read<AppState>();
    showAppDialog(
      context: context,
      title: widget.mediaType == MediaType.album ? l10n.addAlbumToPlaylist : l10n.addTracksToPlaylist,
      width: 320,
      maxHeight: 420,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l10n.createNewPlaylist),
            onTap: () {
              Navigator.of(context).pop();
              _showCreatePlaylistDialog(l10n);
            },
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            itemCount: appState.playlists.length,
              itemBuilder: (context, index) {
                final playlist = appState.playlists[index];
                return ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist.name),
                  subtitle: Text(l10n.countSongs(playlist.trackCount)),
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.addedToPlaylist(widget.mediaType == MediaType.album ? l10n.album : 'tracks', playlist.name, _title)),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(AppLocalizations l10n) {
    final nameController = TextEditingController();
    showAppDialog(
      context: context,
      title: l10n.createPlaylist,
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(
          labelText: l10n.playlistName,
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.createdPlaylistWithTracks(nameController.text, widget.mediaType == MediaType.album ? l10n.album : '')),
                ),
              );
            }
          },
          child: Text(l10n.create),
        ),
      ],
    );
  }

  // Playlist-specific methods
  void _showEditPlaylistDialog(AppLocalizations l10n) {
    if (widget.mediaType != MediaType.playlist) return;
    showAppDialog(
      context: context,
      title: l10n.editPlaylist,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: l10n.playlistName,
              border: const OutlineInputBorder(),
            ),
            controller: TextEditingController(text: widget.playlist!.name),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: l10n.descriptionOptional,
              border: const OutlineInputBorder(),
            ),
            controller: TextEditingController(text: ''),
            maxLines: 3,
          ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            // Save playlist changes
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }

  void _showDeletePlaylistDialog(AppLocalizations l10n) async {
    if (widget.mediaType != MediaType.playlist) return;
    final ok = await showAppConfirmDialog(
      context: context,
      title: l10n.deletePlaylist,
      message: l10n.deletePlaylistConfirmation(widget.playlist!.name),
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(); // Go back to playlists page
      // Delete playlist
    }
  }

  void _removeTrackFromPlaylist(Track track, AppLocalizations l10n) {
    if (widget.mediaType != MediaType.playlist) return;
    
    setState(() {
      _tracks.remove(track);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.removedFromPlaylist(track.name)),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () {
            // Undo remove track
          },
        ),
      ),
    );
  }
}