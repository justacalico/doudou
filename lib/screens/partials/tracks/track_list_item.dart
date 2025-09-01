import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../widgets/download_button.dart';

class TrackListItem extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final int? trackNumber;
  final bool showAlbumArt;
  final bool showTrackNumber;
  final bool showDuration;
  final bool showDownloadButton;
  final bool showFavoriteButton;

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
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: BoxDecoration(
        color: showAlbumArt 
            ? const Color(0xFF000000) 
            : const Color(0xFF000000), // Pure black for OLED
        borderRadius: BorderRadius.circular(showAlbumArt ? 16 : 12),
        border: showAlbumArt ? Border.all(
          color: const Color(0xFF1D1D1F),
          width: 0.5,
        ) : null,
      ),
      child: CupertinoContextMenu(
        actions: [
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_down_circle,
                  size: 18,
                  color: Color(0xFF007AFF),
                ),
                SizedBox(width: 8),
                Text(
                  'Download',
                  style: TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.downloadService.downloadTrack(track);
            },
          ),
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(
                  CupertinoIcons.plus,
                  size: 18,
                  color: Color(0xFF007AFF),
                ),
                SizedBox(width: 8),
                Text(
                  'Add to Queue',
                  style: TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.addToQueue(track);
            },
          ),
          CupertinoContextMenuAction(
            child: const Row(
              children: [
                Icon(
                  CupertinoIcons.play_arrow_solid,
                  size: 18,
                  color: Color(0xFF007AFF),
                ),
                SizedBox(width: 8),
                Text(
                  'Play Next',
                  style: TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.addNextInQueue(track);
            },
          ),
          CupertinoContextMenuAction(
            child: Row(
              children: [
                Icon(
                  track.isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 18,
                  color: track.isFavorite 
                      ? const Color(0xFFFF453A) 
                      : const Color(0xFF007AFF),
                ),
                const SizedBox(width: 8),
                Text(
                  track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  style: const TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
          ),
        ],
        child: _buildContent(context, appState),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppState appState) {
    if (showAlbumArt) {
      // Favorites-style layout with album art
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Album artwork
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: track.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: appState.jellyfinService.getImageUrl(
                            track.imageUrl!,
                            width: 180,
                            height: 180,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1C1C1E),
                                  const Color(0xFF2C2C2E),
                                ],
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: Color(0xFF8E8E93),
                              size: 28,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1C1C1E),
                                  const Color(0xFF2C2C2E),
                                ],
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: Color(0xFF8E8E93),
                              size: 28,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1C1C1E),
                                const Color(0xFF2C2C2E),
                              ],
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: Color(0xFF8E8E93),
                            size: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artistName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.artistName!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF8E8E93),
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF636366),
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Duration and action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showDuration && track.duration != null)
                    Text(
                      _formatDuration(Duration(milliseconds: track.duration!)),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8E8E93),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showDownloadButton) ...[
                        DownloadButton(track: track),
                        const SizedBox(width: 8),
                      ],
                      if (showFavoriteButton)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 36,
                          onPressed: () => appState.toggleFavorite(track),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: track.isFavorite 
                                  ? const Color(0xFFFF453A).withOpacity(0.15)
                                  : const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: track.isFavorite 
                                    ? const Color(0xFFFF453A).withOpacity(0.3)
                                    : const Color(0xFF2C2C2E),
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              track.isFavorite 
                                  ? CupertinoIcons.heart_fill 
                                  : CupertinoIcons.heart,
                              color: track.isFavorite 
                                  ? const Color(0xFFFF453A) 
                                  : const Color(0xFF8E8E93),
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (showTrackNumber) {
      // Album detail style with track numbers
      return CupertinoListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              track.trackNumber?.toString() ?? trackNumber.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
        title: Text(
          track.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: track.artistName != null
            ? Text(
                track.artistName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDuration && track.duration != null) ...[
              Text(
                _formatDuration(Duration(milliseconds: track.duration!)),
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (showDownloadButton)
              DownloadButton(track: track),
          ],
        ),
        onTap: onTap,
      );
    } else {
      // Songs list style with album art
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Album artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: track.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: appState.jellyfinService.getImageUrl(
                            track.imageUrl!,
                            width: 150,
                            height: 150,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF2C2C2E),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: CupertinoColors.systemGrey,
                              size: 24,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF2C2C2E),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: CupertinoColors.systemGrey,
                              size: 24,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF2C2C2E),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            color: CupertinoColors.systemGrey,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artistName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        track.artistName!,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Duration and actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showDuration && track.duration != null) ...[
                    Text(
                      _formatDuration(Duration(milliseconds: track.duration!)),
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (showDownloadButton) ...[
                    DownloadButton(track: track),
                    const SizedBox(width: 4),
                  ],
                  if (showFavoriteButton)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 32,
                      onPressed: () => appState.toggleFavorite(track),
                      child: Icon(
                        track.isFavorite 
                            ? CupertinoIcons.heart_fill 
                            : CupertinoIcons.heart,
                        color: track.isFavorite 
                            ? CupertinoColors.systemRed 
                            : CupertinoColors.systemGrey,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
