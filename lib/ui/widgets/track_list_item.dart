import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/ui/widgets/cached_image_widget.dart';

class TrackListItem extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final int? trackNumber;
  final bool showAlbumArt;
  final bool showTrackNumber;
  final bool showDuration;
  final bool showDownloadButton;
  final bool showFavoriteButton;
  final VoidCallback? onRemoveFromPlaylist;

  const TrackListItem({
    super.key,
    required this.track,
    required this.onTap,
    this.trackNumber,
    this.showAlbumArt = true,
    this.showTrackNumber = false,
    this.showDuration = true,
    this.showDownloadButton = true,
    this.showFavoriteButton = true,
    this.onRemoveFromPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onLongPress: () => _handleLongPress(context, appState),
                onSecondaryTapDown: (_) =>
                    _showTrackContextMenu(context, appState),
                child: _buildContent(context, appState),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLongPress(BuildContext context, AppState appState) async {
    await HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    _showTrackContextMenu(context, appState);
  }

  void _showTrackContextMenu(BuildContext context, AppState appState) {
    // Use Consumer to make the context menu reactive to favorite changes
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Consumer<AppState>(
        builder: (context, appState, child) {
          // Get the current track state (it might have been updated)
          final currentTrack = appState.tracks.firstWhere(
            (t) => t.id == track.id,
            orElse: () => track,
          );

          return CupertinoActionSheet(
            actions: [
              // Only show download button if track is not already downloaded
              if (showDownloadButton &&
                  !appState.downloadService.isTrackDownloaded(currentTrack.id))
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    appState.downloadService.downloadTrack(currentTrack);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_down_circle,
                        size: 18,
                        color: Color(0xFF06B6D4),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Download',
                        style: TextStyle(color: Color(0xFF06B6D4)),
                      ),
                    ],
                  ),
                ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  appState.addToQueue(currentTrack);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.plus,
                      size: 18,
                      color: Color(0xFF8B5CF6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Add to Queue',
                      style: TextStyle(color: Color(0xFF8B5CF6)),
                    ),
                  ],
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  appState.addNextInQueue(currentTrack);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.play_arrow_solid,
                      size: 18,
                      color: Color(0xFF8B5CF6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Play Next',
                      style: TextStyle(color: Color(0xFF8B5CF6)),
                    ),
                  ],
                ),
              ),
              if (onRemoveFromPlaylist != null)
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.pop(context);
                    onRemoveFromPlaylist?.call();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.minus_circle,
                        size: 18,
                        color: Color(0xFFEC4899),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Remove from Playlist',
                        style: TextStyle(color: Color(0xFFEC4899)),
                      ),
                    ],
                  ),
                ),
              if (showFavoriteButton)
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    appState.toggleFavorite(currentTrack);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        currentTrack.isFavorite
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        size: 18,
                        color: currentTrack.isFavorite
                            ? const Color(0xFFEC4899)
                            : const Color(0xFFEC4899),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentTrack.isFavorite
                            ? 'Remove from Favorites'
                            : 'Add to Favorites',
                        style: const TextStyle(color: Color(0xFFEC4899)),
                      ),
                    ],
                  ),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppState appState) {
    if (showAlbumArt) {
      // Favorites-style layout with album art
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Album artwork with glow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: track.imageUrl != null
                    ? CachedImageWidget(
                        imageUrl: appState.getImageUrl(
                          track.imageUrl!,
                          width: 180,
                          height: 180,
                        ),
                        fit: BoxFit.cover,
                        placeholder: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: CupertinoColors.white,
                            size: 24,
                          ),
                        ),
                        errorWidget: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: CupertinoColors.white,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.music_note,
                          color: CupertinoColors.white,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (track.artistName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      track.artistName!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (track.albumName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      track.albumName!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Duration only
            if (showDuration && track.duration != null)
              Text(
                _formatDuration(Duration(milliseconds: track.duration!)),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      );
    } else if (showTrackNumber) {
      // Album detail style with track numbers
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Track number with gradient background
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  track.trackNumber?.toString() ?? trackNumber.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (track.artistName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      track.artistName!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Duration
            if (showDuration && track.duration != null)
              Text(
                _formatDuration(Duration(milliseconds: track.duration!)),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      );
    } else {
      // Songs list style with album art
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Album artwork with glow
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: track.imageUrl != null
                    ? CachedImageWidget(
                        imageUrl: appState.getImageUrl(
                          track.imageUrl!,
                          width: 162,
                          height: 162,
                        ),
                        fit: BoxFit.cover,
                        placeholder: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: CupertinoColors.white,
                            size: 22,
                          ),
                        ),
                        errorWidget: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: CupertinoColors.white,
                            size: 22,
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.music_note,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (track.artistName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      track.artistName!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Duration only
            if (showDuration && track.duration != null)
              Text(
                _formatDuration(Duration(milliseconds: track.duration!)),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
