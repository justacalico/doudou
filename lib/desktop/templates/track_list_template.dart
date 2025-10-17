import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import 'desktop_layout.dart';

class TrackListTemplate extends StatelessWidget {
  final List<Track> tracks;
  final String emptyStateTitle;
  final String emptyStateMessage;
  final Widget? emptyStateAction;
  final bool showTrackNumber;
  final bool showArtist;
  final bool showAlbum;
  final bool showArtwork;
  final Function(Track track, int index)? onTrackTap;
  final Function(Track track)? onRemoveTrack;

  const TrackListTemplate({
    super.key,
    required this.tracks,
    this.emptyStateTitle = 'No tracks found',
    this.emptyStateMessage = 'No tracks available',
    this.emptyStateAction,
    this.showTrackNumber = true,
    this.showArtist = false,
    this.showAlbum = false,
    this.showArtwork = false,
    this.onTrackTap,
    this.onRemoveTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (tracks.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Card(
      child: Column(
        children: [
          // Track list header
          _buildHeader(theme),
          
          const Divider(height: 1),
          
          // Track list
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _buildTrackItem(theme, track, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
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
              emptyStateTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              emptyStateMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (emptyStateAction != null) ...[
              const SizedBox(height: 16),
              emptyStateAction!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (showTrackNumber)
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
          
          if (showTrackNumber) const SizedBox(width: 16),
          
          if (showArtwork) const SizedBox(width: 52), // Space for artwork + margin
          
          Expanded(
            flex: showArtist || showAlbum ? 3 : 1,
            child: Text(
              'Title',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          if (showArtist)
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
          
          if (showAlbum)
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
    );
  }

  Widget _buildTrackItem(ThemeData theme, Track track, int index) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: showTrackNumber
              ? SizedBox(
                  width: 40,
                  child: Text(
                    (index + 1).toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : null,
          title: _buildTrackTitle(theme, appState, track),
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
              _buildPopupMenu(context, appState, track, index),
            ],
          ),
          onTap: () {
            if (onTrackTap != null) {
              onTrackTap!(track, index);
            } else {
              // Default behavior: play the track
              appState.playPlaylist(tracks, index);
            }
          },
        );
      },
    );
  }

  Widget _buildTrackTitle(ThemeData theme, AppState appState, Track track) {
    if (!showArtist && !showAlbum && !showArtwork) {
      // Simple title only
      return Text(
        track.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      children: [
        // Track artwork
        if (showArtwork) ...[
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
                      appState.getImageUrl(track.imageUrl!),
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
        ],
        
        // Track info
        Expanded(
          flex: showArtist || showAlbum ? 3 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        if (showArtist)
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
        
        if (showAlbum)
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
      ],
    );
  }

  Widget _buildPopupMenu(BuildContext context, AppState appState, Track track, int index) {
    final menuItems = <PopupMenuEntry<String>>[
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
    ];

    // Add remove option if callback is provided
    if (onRemoveTrack != null) {
      menuItems.add(
        const PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: Icon(Icons.remove, color: Colors.red),
            title: Text('Remove from List', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuAction(context, appState, track, index, value),
      itemBuilder: (context) => menuItems,
    );
  }

  void _handleMenuAction(BuildContext context, AppState appState, Track track, int index, String action) async {
    switch (action) {
      case 'play':
        await appState.playPlaylist(tracks, index);
        break;
        
      case 'play_next':
        // TODO: Implement play next functionality
        _showSnackBar(context, 'Play Next not yet implemented', isError: true);
        break;
        
      case 'add_queue':
        // TODO: Implement add to queue functionality
        _showSnackBar(context, 'Add to Queue not yet implemented', isError: true);
        break;
        
      case 'add_playlist':
        await DesktopLayout.showAddToPlaylistDialog(context, track);
        break;
        
      case 'download':
        await _downloadTrack(context, appState, track);
        break;
        
      case 'favorite':
        await _toggleFavorite(context, appState, track);
        break;
        
      case 'remove':
        if (onRemoveTrack != null) {
          onRemoveTrack!(track);
        }
        break;
    }
  }

  Future<void> _downloadTrack(BuildContext context, AppState appState, Track track) async {
    try {
      final streamUrl = appState.mediaServiceManager.getStreamUrl(track.id);
      final uri = Uri.parse(streamUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          _showSnackBar(context, 'Opening download for "${track.name}" in browser');
        }
      } else {
        if (context.mounted) {
          _showSnackBar(context, 'Cannot open download URL for "${track.name}"', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Failed to download "${track.name}": $e', isError: true);
      }
    }
  }

  Future<void> _toggleFavorite(BuildContext context, AppState appState, Track track) async {
    try {
      await appState.toggleFavorite(track);
      if (context.mounted) {
        final message = track.isFavorite 
            ? 'Added "${track.name}" to favorites'
            : 'Removed "${track.name}" from favorites';
        _showSnackBar(context, message);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Failed to toggle favorite: $e', isError: true);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}