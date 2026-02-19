import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/jellyfin_models.dart';
import '../../providers/app_state.dart';
import '../theme.dart';
import 'source_pill.dart';
import 'universal_image.dart';

/// Single track row: artwork, title, artist, SourcePill, duration, context menu. Not Material ListTile.
class TrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final List<Track> playlist;
  final bool showTrackNumber;
  final bool showArtwork;
  final bool isCurrentTrack;
  final Color? accentColor;
  final VoidCallback? onRemove;

  const TrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.playlist,
    this.showTrackNumber = true,
    this.showArtwork = true,
    this.isCurrentTrack = false,
    this.accentColor,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final serverType = appState.mediaServiceManager.currentServerType;
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    final imageUrl = track.imageUrl != null
        ? appState.getImageUrl(track.imageUrl!)
        : null;

    return Material(
      color: isCurrentTrack ? accent.withValues(alpha: 0.12) : Colors.transparent,
      child: InkWell(
        onTap: () => appState.playPlaylist(playlist, index),
        onLongPress: () => HapticFeedback.mediumImpact(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: 12,
          ),
          child: Row(
            children: [
              if (showTrackNumber)
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              if (showTrackNumber) const SizedBox(width: AppTheme.spacingSm),
              if (showArtwork) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: UniversalImage(
                    imageUrl: imageUrl,
                    width: 44,
                    height: 44,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isCurrentTrack ? accent : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistName ?? 'Unknown Artist',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              SourcePill(source: serverType, fontSize: 9),
              const SizedBox(width: AppTheme.spacingSm),
              SizedBox(
                width: 44,
                child: Text(
                  track.duration != null
                      ? _formatDuration(track.duration!)
                      : '--:--',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 20, color: AppTheme.textSecondary),
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleMenuAction(context, value, appState),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'play', child: Text('Play')),
                  const PopupMenuItem(value: 'play_next', child: Text('Play Next')),
                  const PopupMenuItem(value: 'add_queue', child: Text('Add to Queue')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'add_playlist', child: Text('Add to Playlist')),
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  ),
                  if (onRemove != null) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from List', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _handleMenuAction(BuildContext context, String value, AppState appState) async {
    switch (value) {
      case 'play':
        await appState.playPlaylist(playlist, index);
        break;
      case 'play_next':
        appState.addNextInQueue(track);
        _showSnack(context, 'Added to play next');
        break;
      case 'add_queue':
        appState.addToQueue(track);
        _showSnack(context, 'Added to queue');
        break;
      case 'add_playlist':
        await _showAddToPlaylistDialog(context, appState);
        break;
      case 'favorite':
        await appState.toggleFavorite(track);
        break;
      case 'remove':
        onRemove?.call();
        break;
    }
  }

  Future<void> _showAddToPlaylistDialog(BuildContext context, AppState appState) async {
    final playlists = appState.playlists;
    if (!context.mounted) return;
    if (playlists.isEmpty) {
      _showSnack(context, 'Create a playlist first');
      return;
    }
    final chosen = await showDialog<Playlist>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add to Playlist'),
        children: [
          ...playlists.take(10).map((p) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: Text(p.name),
          )),
        ],
      ),
    );
    if (chosen != null) {
      final ok = await appState.addToPlaylist(chosen.id, track.id);
      if (context.mounted) _showSnack(context, ok ? 'Added to ${chosen.name}' : 'Failed');
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
