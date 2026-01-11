import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../models/download_models.dart';
import '../../../widgets/apple_design/apple_theme.dart';
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
    final isDark = theme.brightness == Brightness.dark;

    if (tracks.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppleDesignSystem.blurRegular,
          sigmaY: AppleDesignSystem.blurRegular,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppleColors.backgroundSecondaryDark.withValues(alpha: 0.7)
                : AppleColors.backgroundSecondary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              // Track list header with Apple styling
              _buildHeader(context, isDark),

              // Subtle gradient divider
              Container(
                height: 0.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isDark
                              ? AppleColors.separatorDark
                              : AppleColors.separator)
                          .withValues(alpha: 0),
                      isDark
                          ? AppleColors.separatorDark
                          : AppleColors.separator,
                      (isDark
                              ? AppleColors.separatorDark
                              : AppleColors.separator)
                          .withValues(alpha: 0),
                    ],
                  ),
                ),
              ),

              // Track list with custom scroll physics
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return _AppleTrackListItem(
                      track: track,
                      index: index,
                      totalTracks: tracks.length,
                      showTrackNumber: showTrackNumber,
                      showArtist: showArtist,
                      showAlbum: showAlbum,
                      showArtwork: showArtwork,
                      tracks: tracks,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppleDesignSystem.blurRegular,
          sigmaY: AppleDesignSystem.blurRegular,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppleColors.backgroundSecondaryDark.withValues(alpha: 0.7)
                : AppleColors.backgroundSecondary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(AppleDesignSystem.spacing48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (isDark
                              ? AppleColors.systemGray3Dark
                              : AppleColors.systemGray3)
                          .withValues(alpha: 0.5),
                      (isDark
                              ? AppleColors.systemGray4Dark
                              : AppleColors.systemGray4)
                          .withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 40,
                  color: isDark
                      ? AppleColors.labelSecondaryDark
                      : AppleColors.labelSecondary,
                ),
              ),
              const SizedBox(height: AppleDesignSystem.spacing24),
              Text(
                emptyStateTitle,
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: AppleDesignSystem.typeScaleTitle3,
                  fontWeight: AppleDesignSystem.weightSemiBold,
                  color: isDark
                      ? AppleColors.labelPrimaryDark
                      : AppleColors.labelPrimary,
                ),
              ),
              const SizedBox(height: AppleDesignSystem.spacing8),
              Text(
                emptyStateMessage,
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: AppleDesignSystem.typeScaleSubheadline,
                  color: isDark
                      ? AppleColors.labelSecondaryDark
                      : AppleColors.labelSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (emptyStateAction != null) ...[
                const SizedBox(height: AppleDesignSystem.spacing24),
                emptyStateAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppleDesignSystem.spacing16),
      child: Row(
        children: [
          if (showTrackNumber)
            SizedBox(
              width: 40,
              child: Text(
                '#',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: AppleDesignSystem.typeScaleCaption1,
                  fontWeight: AppleDesignSystem.weightMedium,
                  letterSpacing: 0.5,
                  color: isDark
                      ? AppleColors.labelTertiaryDark
                      : AppleColors.labelTertiary,
                ),
              ),
            ),

          if (showTrackNumber)
            const SizedBox(width: AppleDesignSystem.spacing16),

          if (showArtwork)
            const SizedBox(width: 52), // Space for artwork + margin

          Expanded(
            flex: showArtist || showAlbum ? 3 : 1,
            child: Text(
              'TITLE',
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                fontSize: AppleDesignSystem.typeScaleCaption1,
                fontWeight: AppleDesignSystem.weightMedium,
                letterSpacing: 0.5,
                color: isDark
                    ? AppleColors.labelTertiaryDark
                    : AppleColors.labelTertiary,
              ),
            ),
          ),

          if (showArtist)
            Expanded(
              flex: 2,
              child: Text(
                'ARTIST',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: AppleDesignSystem.typeScaleCaption1,
                  fontWeight: AppleDesignSystem.weightMedium,
                  letterSpacing: 0.5,
                  color: isDark
                      ? AppleColors.labelTertiaryDark
                      : AppleColors.labelTertiary,
                ),
              ),
            ),

          if (showAlbum)
            Expanded(
              flex: 2,
              child: Text(
                'ALBUM',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: AppleDesignSystem.typeScaleCaption1,
                  fontWeight: AppleDesignSystem.weightMedium,
                  letterSpacing: 0.5,
                  color: isDark
                      ? AppleColors.labelTertiaryDark
                      : AppleColors.labelTertiary,
                ),
              ),
            ),

          SizedBox(
            width: 80,
            child: Text(
              'TIME',
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                fontSize: AppleDesignSystem.typeScaleCaption1,
                fontWeight: AppleDesignSystem.weightMedium,
                letterSpacing: 0.5,
                color: isDark
                    ? AppleColors.labelTertiaryDark
                    : AppleColors.labelTertiary,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          const SizedBox(width: 48), // Space for actions
        ],
      ),
    );
  }
}

class _AppleTrackListItem extends StatefulWidget {
  final Track track;
  final int index;
  final int totalTracks;
  final bool showTrackNumber;
  final bool showArtist;
  final bool showAlbum;
  final bool showArtwork;
  final List<Track> tracks;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _AppleTrackListItem({
    required this.track,
    required this.index,
    required this.totalTracks,
    required this.showTrackNumber,
    required this.showArtist,
    required this.showAlbum,
    required this.showArtwork,
    required this.tracks,
    required this.onTap,
    this.onRemove,
  });

  @override
  State<_AppleTrackListItem> createState() => _AppleTrackListItemState();
}

class _AppleTrackListItemState extends State<_AppleTrackListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appState = context.watch<AppState>();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing16,
            vertical: AppleDesignSystem.spacing12,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03))
                : Colors.transparent,
            border: widget.index < widget.totalTracks - 1
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppleColors.separatorDark.withValues(alpha: 0.5)
                          : AppleColors.separator.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Track number or play indicator
              if (widget.showTrackNumber)
                SizedBox(
                  width: 40,
                  child: AnimatedSwitcher(
                    duration: AppleDesignSystem.durationFast,
                    child: _isHovered
                        ? Icon(
                            Icons.play_arrow_rounded,
                            key: const ValueKey('play'),
                            size: 20,
                            color: theme.colorScheme.primary,
                          )
                        : Text(
                            (widget.index + 1).toString(),
                            key: const ValueKey('number'),
                            style: TextStyle(
                              fontFamily: AppleDesignSystem.fontFamily,
                              fontSize: AppleDesignSystem.typeScaleSubheadline,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: isDark
                                  ? AppleColors.labelSecondaryDark
                                  : AppleColors.labelSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),

              if (widget.showTrackNumber)
                const SizedBox(width: AppleDesignSystem.spacing16),

              // Track artwork
              if (widget.showArtwork) ...[
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(
                    right: AppleDesignSystem.spacing12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppleColors.systemGray5Dark
                        : AppleColors.systemGray5,
                    borderRadius: BorderRadius.circular(
                      AppleDesignSystem.radiusSmall,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppleDesignSystem.radiusSmall,
                    ),
                    child: widget.track.imageUrl != null
                        ? Image.network(
                            appState.getImageUrl(widget.track.imageUrl!),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.music_note_rounded,
                                size: 20,
                                color: isDark
                                    ? AppleColors.labelTertiaryDark
                                    : AppleColors.labelTertiary,
                              );
                            },
                          )
                        : Icon(
                            Icons.music_note_rounded,
                            size: 20,
                            color: isDark
                                ? AppleColors.labelTertiaryDark
                                : AppleColors.labelTertiary,
                          ),
                  ),
                ),
              ],

              // Track title
              Expanded(
                flex: widget.showArtist || widget.showAlbum ? 3 : 1,
                child: Text(
                  widget.track.name,
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: AppleDesignSystem.typeScaleBody,
                    fontWeight: AppleDesignSystem.weightMedium,
                    color: isDark
                        ? AppleColors.labelPrimaryDark
                        : AppleColors.labelPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Artist name
              if (widget.showArtist)
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.track.artistName ?? 'Unknown Artist',
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: AppleDesignSystem.typeScaleSubheadline,
                      color: isDark
                          ? AppleColors.labelSecondaryDark
                          : AppleColors.labelSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Album name
              if (widget.showAlbum)
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.track.albumName ?? 'Unknown Album',
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: AppleDesignSystem.typeScaleSubheadline,
                      color: isDark
                          ? AppleColors.labelSecondaryDark
                          : AppleColors.labelSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Duration
              SizedBox(
                width: 80,
                child: Text(
                  widget.track.duration != null
                      ? _formatDuration(widget.track.duration!)
                      : '--:--',
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: AppleDesignSystem.typeScaleSubheadline,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isDark
                        ? AppleColors.labelSecondaryDark
                        : AppleColors.labelSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              // Actions menu
              const SizedBox(width: AppleDesignSystem.spacing8),
              _AppleTrackMenu(
                track: widget.track,
                index: widget.index,
                tracks: widget.tracks,
                onRemove: widget.onRemove,
              ),
            ],
          ),
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
}

class _AppleTrackMenu extends StatelessWidget {
  final Track track;
  final int index;
  final List<Track> tracks;
  final VoidCallback? onRemove;

  const _AppleTrackMenu({
    required this.track,
    required this.index,
    required this.tracks,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: isDark
            ? AppleColors.labelSecondaryDark
            : AppleColors.labelSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
      ),
      color: isDark
          ? AppleColors.backgroundTertiaryDark.withValues(alpha: 0.95)
          : AppleColors.backgroundTertiary.withValues(alpha: 0.95),
      elevation: 8,
      onSelected: (value) => _handleMenuAction(context, value),
      itemBuilder: (context) => [
        _buildMenuItem(context, 'play', Icons.play_arrow_rounded, 'Play'),
        _buildMenuItem(
          context,
          'play_next',
          Icons.skip_next_rounded,
          'Play Next',
        ),
        _buildMenuItem(
          context,
          'add_queue',
          Icons.queue_music_rounded,
          'Add to Queue',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          context,
          'add_playlist',
          Icons.playlist_add_rounded,
          'Add to Playlist',
        ),
        _buildMenuItem(
          context,
          'favorite',
          track.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
        ),
        const PopupMenuDivider(),
        _buildDownloadMenuItem(context),
        if (onRemove != null) ...[
          const PopupMenuDivider(),
          _buildMenuItem(
            context,
            'remove',
            Icons.remove_circle_outline_rounded,
            'Remove from List',
            isDestructive: true,
          ),
        ],
      ],
    );
  }

  PopupMenuItem<String> _buildDownloadMenuItem(BuildContext context) {
    final appState = context.read<AppState>();
    final downloadService = appState.downloadService;
    final isDownloaded = downloadService.isTrackDownloaded(track.id);
    final status = downloadService.getDownloadStatus(track.id);
    final isDownloading = status == DownloadStatus.downloading;

    IconData icon;
    String label;
    
    if (isDownloaded) {
      icon = Icons.download_done_rounded;
      label = 'Downloaded';
    } else if (isDownloading) {
      icon = Icons.downloading_rounded;
      label = 'Downloading...';
    } else {
      icon = Icons.download_rounded;
      label = 'Download';
    }

    return _buildMenuItem(context, 'download', icon, label);
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label, {
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDestructive
        ? AppleColors.systemRed
        : (isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary);

    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppleDesignSystem.spacing12),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppleDesignSystem.fontFamily,
              fontSize: AppleDesignSystem.typeScaleSubheadline,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) async {
    final appState = context.read<AppState>();

    switch (action) {
      case 'play':
        await appState.playPlaylist(tracks, index);
        break;

      case 'play_next':
        appState.addNextInQueue(track);
        _showSnackBar(context, 'Added "${track.name}" to play next');
        break;

      case 'add_queue':
        appState.addToQueue(track);
        _showSnackBar(context, 'Added "${track.name}" to queue');
        break;

      case 'add_playlist':
        await DesktopLayout.showAddToPlaylistDialog(context, track);
        break;

      case 'download':
        await _downloadTrack(context, appState);
        break;

      case 'favorite':
        await _toggleFavorite(context, appState);
        break;

      case 'remove':
        if (onRemove != null) {
          onRemove!();
        }
        break;
    }
  }

  Future<void> _downloadTrack(BuildContext context, AppState appState) async {
    final downloadService = appState.downloadService;
    final isDownloaded = downloadService.isTrackDownloaded(track.id);
    final status = downloadService.getDownloadStatus(track.id);

    if (isDownloaded) {
      // Show options for downloaded track
      _showDownloadedOptions(context, appState);
      return;
    }

    if (status == DownloadStatus.downloading) {
      // Already downloading - show cancel option
      _showDownloadingOptions(context, appState);
      return;
    }

    // Start download
    try {
      await downloadService.downloadTrack(track);
      if (context.mounted) {
        _showSnackBar(context, 'Started downloading "${track.name}"');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Failed to start download: $e', isError: true);
      }
    }
  }

  void _showDownloadedOptions(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Downloaded'),
        content: Text('"${track.name}" is already downloaded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.downloadService.deleteDownload(track.id);
              _showSnackBar(context, 'Deleted download for "${track.name}"');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Download'),
          ),
        ],
      ),
    );
  }

  void _showDownloadingOptions(BuildContext context, AppState appState) {
    final progress = appState.downloadService.getDownloadProgress(track.id);
    final progressPercent = (progress * 100).toInt();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Downloading'),
        content: Text('"${track.name}" is downloading ($progressPercent%)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.downloadService.cancelDownload(track.id);
              _showSnackBar(context, 'Cancelled download for "${track.name}"');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context, AppState appState) async {
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

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: AppleDesignSystem.fontFamily,
            fontSize: AppleDesignSystem.typeScaleSubheadline,
          ),
        ),
        backgroundColor: isError
            ? AppleColors.systemRed
            : (isDark ? AppleColors.systemGreenDark : AppleColors.systemGreen),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
        ),
        margin: const EdgeInsets.all(AppleDesignSystem.spacing16),
      ),
    );
  }
}
