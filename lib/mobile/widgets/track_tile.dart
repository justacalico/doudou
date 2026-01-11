import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import 'cached_artwork.dart';
import '../../models/jellyfin_models.dart';

/// Apple Music-style track list tile - used across all screens
class TrackTile extends StatelessWidget {
  final Track track;
  final int? trackNumber;
  final bool showArtwork;
  final bool showArtist;
  final bool isPlaying;
  final bool isDownloaded;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const TrackTile({
    super.key,
    required this.track,
    this.trackNumber,
    this.showArtwork = true,
    this.showArtist = true,
    this.isPlaying = false,
    this.isDownloaded = false,
    this.onTap,
    this.onMoreTap,
    this.getImageUrl,
  });

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return '';
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingM,
        ),
        child: Row(
          children: [
            // Track number or artwork
            if (trackNumber != null && !showArtwork)
              SizedBox(
                width: 28,
                child: Text(
                  '$trackNumber',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: isPlaying ? AppTheme.accentPink : textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (showArtwork) ...[
              CachedArtwork(
                imageUrl: track.imageUrl != null && getImageUrl != null
                    ? getImageUrl!(track.imageUrl!, width: 120, height: 120)
                    : null,
                size: AppTheme.albumArtMedium,
                borderRadius: AppTheme.radiusS,
              ),
              const SizedBox(width: AppTheme.spacingM),
            ],
            
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.name,
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: isPlaying ? AppTheme.accentPink : textPrimary,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDownloaded)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            CupertinoIcons.arrow_down_circle_fill,
                            size: 14,
                            color: textSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (showArtist && track.artistName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        track.artistName!,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeFootnote,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            
            // Duration
            if (track.duration != null)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacingS),
                child: Text(
                  _formatDuration(track.duration),
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeFootnote,
                    color: textSecondary,
                  ),
                ),
              ),
            
            // More button
            if (onMoreTap != null)
              CupertinoButton(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                minSize: 0,
                onPressed: onMoreTap,
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: 20,
                  color: textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Builds a list of tracks with optional header
class TrackList extends StatelessWidget {
  final List<Track> tracks;
  final String? currentTrackId;
  final Set<String>? downloadedTrackIds;
  final bool showArtwork;
  final bool showTrackNumbers;
  final void Function(Track track, int index)? onTrackTap;
  final void Function(Track track)? onMoreTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;
  final Widget? header;
  final EdgeInsets padding;

  const TrackList({
    super.key,
    required this.tracks,
    this.currentTrackId,
    this.downloadedTrackIds,
    this.showArtwork = true,
    this.showTrackNumbers = false,
    this.onTrackTap,
    this.onMoreTap,
    this.getImageUrl,
    this.header,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (header != null && index == 0) {
              return header;
            }
            
            final trackIndex = header != null ? index - 1 : index;
            if (trackIndex < 0 || trackIndex >= tracks.length) return null;
            
            final track = tracks[trackIndex];
            final isPlaying = track.id == currentTrackId;
            final isDownloaded = downloadedTrackIds?.contains(track.id) ?? false;
            
            return Column(
              children: [
                TrackTile(
                  track: track,
                  trackNumber: showTrackNumbers ? track.trackNumber : null,
                  showArtwork: showArtwork && !showTrackNumbers,
                  isPlaying: isPlaying,
                  isDownloaded: isDownloaded,
                  getImageUrl: getImageUrl,
                  onTap: onTrackTap != null
                      ? () => onTrackTap!(track, trackIndex)
                      : null,
                  onMoreTap: onMoreTap != null
                      ? () => onMoreTap!(track)
                      : null,
                ),
                if (trackIndex < tracks.length - 1)
                  Padding(
                    padding: EdgeInsets.only(
                      left: showArtwork && !showTrackNumbers 
                          ? AppTheme.spacingL + AppTheme.albumArtMedium + AppTheme.spacingM
                          : AppTheme.spacingL + (showTrackNumbers ? 28 : 0),
                    ),
                    child: Container(
                      height: 0.5,
                      color: AppTheme.separator(context),
                    ),
                  ),
              ],
            );
          },
          childCount: tracks.length + (header != null ? 1 : 0),
        ),
      ),
    );
  }
}
