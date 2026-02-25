import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/widgets/universal_image.dart';

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
    if (tracks.isEmpty) {
      return _EmptyState(
        title: emptyStateTitle,
        message: emptyStateMessage,
        action: emptyStateAction,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundTertiary.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(DesktopTheme.radiusLg),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: tracks.length,
        separatorBuilder: (context, index) => Divider(
          color: DesktopTheme.glassBorder,
          height: 1,
          indent: showArtwork ? 80 : 16,
        ),
        itemBuilder: (context, index) {
          final track = tracks[index];
          return _TrackRow(
            key: ValueKey(track.id),
            track: track,
            index: index,
            showTrackNumber: showTrackNumber,
            showArtist: showArtist,
            showAlbum: showAlbum,
            showArtwork: showArtwork,
            onTap: () {
              if (onTrackTap != null) {
                onTrackTap!(track, index);
              } else {
                context.read<AppState>().playPlaylist(tracks, index);
              }
            },
            onRemove: onRemoveTrack != null
                ? () => onRemoveTrack!(track)
                : null,
          );
        },
      ),
    );
  }
}

class _TrackRow extends StatefulWidget {
  final Track track;
  final int index;
  final bool showTrackNumber;
  final bool showArtist;
  final bool showAlbum;
  final bool showArtwork;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _TrackRow({
    super.key,
    required this.track,
    required this.index,
    required this.showTrackNumber,
    required this.showArtist,
    required this.showAlbum,
    required this.showArtwork,
    required this.onTap,
    this.onRemove,
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();
    final subtitleParts = <String>[];

    if (widget.showArtist &&
        widget.track.artistName != null &&
        widget.track.artistName!.isNotEmpty) {
      subtitleParts.add(widget.track.artistName!);
    }
    if (widget.showAlbum &&
        widget.track.albumName != null &&
        widget.track.albumName!.isNotEmpty) {
      subtitleParts.add(widget.track.albumName!);
    }

    final subtitle = subtitleParts.join(' • ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          ),
          child: Row(
            children: [
              if (widget.showTrackNumber)
                SizedBox(
                  width: 28,
                  child: Text(
                    '${widget.index + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: DesktopTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              if (widget.showTrackNumber) const SizedBox(width: 12),
              if (widget.showArtwork)
                _TrackArt(
                  imageUrl: widget.track.imageUrl != null
                      ? appState.getImageUrl(
                          widget.track.imageUrl!,
                          width: 120,
                          height: 120,
                        )
                      : null,
                ),
              if (widget.showArtwork) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DesktopTheme.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: DesktopTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _durationLabel(widget.track.duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: DesktopTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  tooltip: AppLocalizations.of(context).remove,
                  color: theme.colorScheme.error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _durationLabel(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '--:--';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TrackArt extends StatelessWidget {
  final String? imageUrl;

  const _TrackArt({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageUrl != null
            ? buildSmartImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: () => _fallback(context),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: DesktopTheme.backgroundElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;

  const _EmptyState({required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesktopTheme.radiusLg),
          border: Border.all(color: DesktopTheme.glassBorder),
          color: DesktopTheme.backgroundTertiary.withValues(alpha: 0.7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 54,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: DesktopTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DesktopTheme.textSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
