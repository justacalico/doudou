import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/models/download_models.dart';
import 'package:doudou/services/audio/unified_audio_handler.dart';
import 'package:doudou/services/navigation_service.dart';
import 'package:doudou/ui/pages/details/media_details.dart';
import 'package:doudou/ui/widgets/universal_image.dart';
import 'package:doudou/ui/playing/now_playing.dart' show NowPlayingScreen;
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';

/// Static helpers for detail overlay and dialogs (main shell is [AppShell]).
class DesktopLayout {
  DesktopLayout._();

  /// Build detail overlay (album/artist/playlist) for use in responsive shell.
  static Widget? buildDetailOverlay(
    BuildContext context,
    NavigationService navigationService,
  ) {
    final detailPage = navigationService.currentDetailPage;
    if (detailPage == null) return null;
    switch (detailPage.type) {
      case DetailPageType.album:
        return MediaDetailsPage.album(
          album: detailPage.data as Album,
          onBackPressed: navigationService.goBack,
        );
      case DetailPageType.artist:
        return MediaDetailsPage.artist(
          artist: detailPage.data as Artist,
          onBackPressed: navigationService.goBack,
        );
      case DetailPageType.playlist:
        return MediaDetailsPage.playlist(
          playlist: detailPage.data as Playlist,
          onBackPressed: navigationService.goBack,
        );
    }
  }

  /// Show add to playlist dialog (single track). Includes "Create New Playlist" and list of playlists.
  static Future<void> showAddToPlaylistDialog(
    BuildContext context,
    Track track,
  ) async {
    final l10n = AppLocalizations.of(context);
    final appState = context.read<AppState>();
    final playlists = appState.playlists;

    showAppDialog(
      context: context,
      title: l10n.addToPlaylist,
      width: 400,
      maxHeight: 500,
      content: _AddToPlaylistDialogContent(track: track, playlists: playlists),
    );
  }

  /// Show create-playlist dialog then add [track] to the new playlist.
  static Future<void> showCreatePlaylistAndAddTrack(
    BuildContext context,
    Track track,
  ) async {
    final l10n = AppLocalizations.of(context);
    final appState = context.read<AppState>();
    final nameController = TextEditingController();

    showAppDialog(
      context: context,
      title: l10n.newPlaylist,
      width: 320,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.enterPlaylistName,
            style: TextStyle(
              color: DesktopTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: l10n.playlistName,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(dialogContext).pop();
            try {
              final created = await appState.createPlaylist(name);
              if (!context.mounted) return;
              if (created) {
                final list = appState.playlists
                    .where((p) => p.name == name)
                    .toList();
                if (list.isNotEmpty) {
                  final newPlaylist = list.first;
                  await appState.addToPlaylist(newPlaylist.id, track.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.addedToPlaylist(
                            'track',
                            newPlaylist.name,
                            track.name,
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.errorCreatingPlaylist(name)),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.errorAddingToPlaylist(e.toString())),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: Text(l10n.create),
        ),
      ],
    );
  }
}

/// Bottom player bar (public for use in new UI app shell).
class DesktopPlayerBar extends StatelessWidget {
  const DesktopPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final audioHandler = appState.audioHandler;
        if (audioHandler == null) return const SizedBox.shrink();

        return StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, mediaSnapshot) {
            final mediaItem = mediaSnapshot.data;

            // Hide player bar when no track is playing
            if (mediaItem == null) return const SizedBox.shrink();

            return StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, playbackSnapshot) {
                final playbackState = playbackSnapshot.data;
                final isPlaying = playbackState?.playing ?? false;

                return StreamBuilder<Duration>(
                  stream: audioHandler.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration?>(
                      stream: audioHandler.durationStream,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ?? Duration.zero;

                        return _PlayerBarContent(
                          mediaItem: mediaItem,
                          isPlaying: isPlaying,
                          position: position,
                          duration: duration,
                          appState: appState,
                          audioHandler: audioHandler,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PlayerBarContent extends StatelessWidget {
  final MediaItem? mediaItem;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final AppState appState;
  final dynamic audioHandler;

  const _PlayerBarContent({
    required this.mediaItem,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.appState,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      height: DesktopTheme.playerBarHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DesktopTheme.backgroundSecondary.withValues(alpha: 0.96),
            DesktopTheme.backgroundTertiary.withValues(alpha: 0.96),
          ],
        ),
        border: Border(
          top: BorderSide(color: DesktopTheme.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Progress bar at top
          _ProgressBar(
            progress: progress,
            position: position,
            duration: duration,
            onSeek: (value) {
              final newPosition = Duration(
                milliseconds: (value * duration.inMilliseconds).round(),
              );
              audioHandler.seek(newPosition);
            },
          ),
          // Player content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesktopTheme.spacingLg,
              ),
              child: Row(
                children: [
                  // Left: Track info
                  Expanded(
                    flex: 1,
                    child: _TrackInfo(mediaItem: mediaItem, appState: appState),
                  ),
                  // Center: Playback controls
                  Expanded(
                    flex: 2,
                    child: _PlaybackControls(
                      isPlaying: isPlaying,
                      onPlayPause: appState.playPause,
                      onPrevious: appState.skipToPrevious,
                      onNext: appState.skipToNext,
                      onShuffle: () => audioHandler.setShuffleMode(
                        !(audioHandler.shuffleEnabled ?? false),
                      ),
                      onRepeat: () {
                        final currentMode = audioHandler.repeatMode;
                        final nextMode = currentMode == RepeatMode.none
                            ? RepeatMode.all
                            : currentMode == RepeatMode.all
                            ? RepeatMode.one
                            : RepeatMode.none;
                        audioHandler.setRepeatMode(nextMode);
                      },
                      isShuffled: audioHandler.shuffleEnabled ?? false,
                      repeatMode: audioHandler.repeatMode ?? RepeatMode.none,
                      showShuffleRepeat: appState.showShuffleRepeatOnPlayerBar,
                    ),
                  ),
                  // Right: Volume and extras
                  Expanded(
                    flex: 1,
                    child: _PlayerExtras(
                      audioHandler: audioHandler,
                      onQueueTap: () => _showNowPlaying(context),
                      onClose: () => appState.closePlayerAndClearQueue(),
                      showVolume: appState.showVolumeOnPlayerBar,
                      showQueue: appState.showQueueOnPlayerBar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const NowPlayingScreen(),
          );
        },
      ),
    );
  }
}

/// Progress bar widget
class _ProgressBar extends StatefulWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _ProgressBar({
    required this.progress,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _isHovered = false;
  bool _isDragging = false;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentProgress = _dragValue ?? widget.progress;
    final isExpanded = _isHovered || _isDragging;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          setState(() => _isDragging = true);
          _updateDrag(details.localPosition);
        },
        onHorizontalDragUpdate: (details) => _updateDrag(details.localPosition),
        onHorizontalDragEnd: (_) {
          if (_dragValue != null) widget.onSeek(_dragValue!);
          setState(() {
            _isDragging = false;
            _dragValue = null;
          });
        },
        onTapDown: (details) {
          _updateDrag(details.localPosition);
          if (_dragValue != null) widget.onSeek(_dragValue!);
          _dragValue = null;
        },
        child: SizedBox(
          height: isExpanded ? 6 : 4,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    decoration: BoxDecoration(
                      color: DesktopTheme.backgroundElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Active track
                  FractionallySizedBox(
                    widthFactor: currentProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? theme.colorScheme.primary
                            : DesktopTheme.textPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _updateDrag(Offset localPosition) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
    setState(() => _dragValue = progress);
  }
}

/// Track info widget
class _TrackInfo extends StatelessWidget {
  final MediaItem? mediaItem;
  final AppState appState;

  const _TrackInfo({required this.mediaItem, required this.appState});

  @override
  Widget build(BuildContext context) {
    if (mediaItem == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final trackId = mediaItem!.id;
    final isFavorite = appState.isFavorite(trackId);

    return Row(
      children: [
        // Album art
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
            color: DesktopTheme.backgroundElevated,
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildAlbumArt(),
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        // Track details
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mediaItem!.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DesktopTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                mediaItem!.artist ?? 'Unknown Artist',
                style: TextStyle(
                  fontSize: 12,
                  color: DesktopTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Like button
        DesktopIconButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: isFavorite ? const Color(0xFFEC4899) : null,
          tooltip: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
          onPressed: () {
            final track = appState.tracks
                .where((t) => t.id == trackId)
                .firstOrNull;
            if (track != null) {
              appState.toggleFavorite(track);
            }
          },
        ),
        // More options button
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: DesktopTheme.textSecondary,
            size: 20,
          ),
          tooltip: l10n.moreOptions,
          onSelected: (value) {
            final track = appState.tracks
                .where((t) => t.id == trackId)
                .firstOrNull;
            if (track == null) return;

            switch (value) {
              case 'addToQueue':
                appState.addToQueue(track);
                break;
              case 'addToPlaylist':
                DesktopLayout.showAddToPlaylistDialog(context, track);
                break;
              case 'showAlbum':
                if (track.albumId != null) {
                  final album = appState.albums
                      .where((a) => a.id == track.albumId)
                      .firstOrNull;
                  if (album != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MediaDetailsPage.album(album: album),
                      ),
                    );
                  }
                }
                break;
              case 'showArtist':
                if (track.artistName != null) {
                  final artist = appState.artists
                      .where((a) => a.name == track.artistName)
                      .firstOrNull;
                  if (artist != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MediaDetailsPage.artist(artist: artist),
                      ),
                    );
                  }
                }
                break;
              case 'download':
                _handleDownload(context, appState, track);
                break;
            }
          },
          itemBuilder: (context) {
            final l10n = AppLocalizations.of(context);
            final track = appState.tracks
                .where((t) => t.id == trackId)
                .firstOrNull;

            // Get download status
            IconData downloadIcon = Icons.download_rounded;
            String downloadLabel = l10n.download;
            if (track != null) {
              final downloadStatus = appState.downloadService.getDownloadStatus(
                track.id,
              );
              if (downloadStatus == DownloadStatus.downloaded) {
                downloadIcon = Icons.download_done_rounded;
                downloadLabel = l10n.downloaded;
              } else if (downloadStatus == DownloadStatus.downloading) {
                downloadIcon = Icons.downloading_rounded;
                downloadLabel = l10n.downloading;
              }
            }

            return [
              PopupMenuItem(
                value: 'addToQueue',
                child: ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(l10n.addToQueue),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'addToPlaylist',
                child: ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: Text(l10n.addToPlaylist),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'showAlbum',
                child: ListTile(
                  leading: const Icon(Icons.album_rounded),
                  title: Text(l10n.showAlbum),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'showArtist',
                child: ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text(l10n.showArtist),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(downloadIcon),
                  title: Text(downloadLabel),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  void _handleDownload(BuildContext context, AppState appState, Track track) {
    final l10n = AppLocalizations.of(context);
    final downloadStatus = appState.downloadService.getDownloadStatus(track.id);

    switch (downloadStatus) {
      case DownloadStatus.downloaded:
        // Show option to delete
        showAppDialog(
          context: context,
          title: l10n.downloaded,
          content: Text(
            '"${track.name}" is already downloaded.',
            style: TextStyle(
              color: DesktopTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          actionsBuilder: (dialogContext) => [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                appState.downloadService.deleteDownload(track.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.deleteDownload),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.deleteDownload),
            ),
          ],
        );
        break;
      case DownloadStatus.downloading:
        // Show option to cancel
        showAppDialog(
          context: context,
          title: l10n.downloading,
          content: Text(
            '"${track.name}" is currently downloading.',
            style: TextStyle(
              color: DesktopTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          actionsBuilder: (dialogContext) => [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                appState.downloadService.cancelDownload(track.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.cancelDownload),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.cancelDownload),
            ),
          ],
        );
        break;
      case DownloadStatus.paused:
      case DownloadStatus.failed:
      case DownloadStatus.notDownloaded:
        appState.downloadService.downloadTrack(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.downloadStarted}: ${track.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Widget _buildAlbumArt() {
    // Try artUri first (HTTP/HTTPS URLs)
    if (mediaItem!.artUri != null) {
      return buildSmartImage(
        imageUrl: mediaItem!.artUri.toString(),
        fit: BoxFit.cover,
        errorBuilder: () => _buildPlaceholder(),
      );
    }

    // Fall back to localImageUrl from extras (supports file:// URIs)
    final localImageUrl = mediaItem!.extras?['localImageUrl'] as String?;
    if (localImageUrl != null && localImageUrl.isNotEmpty) {
      return buildSmartImage(
        imageUrl: localImageUrl,
        fit: BoxFit.cover,
        errorBuilder: () => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DesktopTheme.backgroundTertiary,
      child: Icon(
        Icons.music_note_rounded,
        color: DesktopTheme.textTertiary,
        size: 24,
      ),
    );
  }
}

/// Playback controls widget
class _PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final bool isShuffled;
  final RepeatMode repeatMode;
  final bool showShuffleRepeat;

  const _PlaybackControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.isShuffled,
    required this.repeatMode,
    this.showShuffleRepeat = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showShuffleRepeat) ...[
          DesktopIconButton(
            icon: Icons.shuffle_rounded,
            isActive: isShuffled,
            activeColor: theme.colorScheme.primary,
            onPressed: onShuffle,
            tooltip: AppLocalizations.of(context).shuffle,
          ),
          const SizedBox(width: DesktopTheme.spacingMd),
        ],
        // Previous
        DesktopIconButton(
          icon: Icons.skip_previous_rounded,
          size: 24,
          onPressed: onPrevious,
          tooltip: AppLocalizations.of(context).previousTrack,
        ),
        const SizedBox(width: DesktopTheme.spacingSm),
        // Play/Pause
        _PlayPauseButton(isPlaying: isPlaying, onPressed: onPlayPause),
        const SizedBox(width: DesktopTheme.spacingSm),
        // Next
        DesktopIconButton(
          icon: Icons.skip_next_rounded,
          size: 24,
          onPressed: onNext,
          tooltip: AppLocalizations.of(context).nextTrack,
        ),
        if (showShuffleRepeat) ...[
          const SizedBox(width: DesktopTheme.spacingMd),
          // Repeat
          DesktopIconButton(
            icon: repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            isActive: repeatMode != RepeatMode.none,
            activeColor: theme.colorScheme.primary,
            onPressed: onRepeat,
            tooltip: AppLocalizations.of(context).repeatTrack,
          ),
        ],
      ],
    );
  }
}

/// Play/Pause button
class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({required this.isPlaying, required this.onPressed});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          width: 40,
          height: 40,
          transform: Matrix4.identity()
            ..scaleByDouble(
              _isHovered ? 1.08 : 1.0,
              _isHovered ? 1.08 : 1.0,
              1.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: DesktopTheme.textPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: DesktopTheme.backgroundDeep,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Player extras (volume, queue, close)
class _PlayerExtras extends StatefulWidget {
  final dynamic audioHandler;
  final VoidCallback onQueueTap;
  final VoidCallback? onClose;
  final bool showVolume;
  final bool showQueue;

  const _PlayerExtras({
    required this.audioHandler,
    required this.onQueueTap,
    this.onClose,
    this.showVolume = true,
    this.showQueue = true,
  });

  @override
  State<_PlayerExtras> createState() => _PlayerExtrasState();
}

class _PlayerExtrasState extends State<_PlayerExtras> {
  bool _showVolume = false;
  double _volume = 1.0;
  dynamic _volumeSubscription;

  @override
  void initState() {
    super.initState();
    _volume = widget.audioHandler?.volume ?? 1.0;
    _volumeSubscription = widget.audioHandler?.volumeStream?.listen((vol) {
      if (mounted) setState(() => _volume = vol);
    });
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onClose != null) ...[
          DesktopIconButton(
            icon: Icons.close_rounded,
            tooltip: AppLocalizations.of(context).closeAndClearQueue,
            onPressed: widget.onClose,
          ),
          const SizedBox(width: DesktopTheme.spacingSm),
        ],
        if (widget.showQueue) ...[
          DesktopIconButton(
            icon: Icons.queue_music_rounded,
            tooltip: AppLocalizations.of(context).queue,
            onPressed: widget.onQueueTap,
          ),
          const SizedBox(width: DesktopTheme.spacingSm),
        ],
        if (widget.showVolume) ...[
          MouseRegion(
            onEnter: (_) => setState(() => _showVolume = true),
            onExit: (_) => setState(() => _showVolume = false),
            child: Row(
              children: [
                DesktopIconButton(
                  icon: _volume == 0
                      ? Icons.volume_off_rounded
                      : _volume < 0.5
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
                  onPressed: () {
                    final newVolume = _volume == 0 ? 1.0 : 0.0;
                    setState(() => _volume = newVolume);
                    widget.audioHandler?.setVolume(newVolume);
                  },
                ),
                AnimatedContainer(
                  duration: DesktopTheme.durationFast,
                  width: _showVolume ? 80 : 0,
                  child: _showVolume
                      ? SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: DesktopTheme.textPrimary,
                            inactiveTrackColor: DesktopTheme.backgroundElevated,
                            thumbColor: DesktopTheme.textPrimary,
                          ),
                          child: Slider(
                            value: _volume,
                            onChanged: (value) {
                              setState(() => _volume = value);
                              widget.audioHandler?.setVolume(value);
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesktopTheme.spacingSm),
        ],
        // Fullscreen/Now Playing
        DesktopIconButton(
          icon: Icons.open_in_full_rounded,
          tooltip: AppLocalizations.of(context).nowPlaying,
          onPressed: widget.onQueueTap,
        ),
      ],
    );
  }
}

/// Add to playlist dialog content (used inside [showAppDialog]).
class _AddToPlaylistDialogContent extends StatelessWidget {
  final Track track;
  final List<Playlist> playlists;

  const _AddToPlaylistDialogContent({
    required this.track,
    required this.playlists,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(
            Icons.add_circle_outline,
            color: CupertinoColors.activeBlue,
          ),
          title: Text(l10n.createNewPlaylist),
          onTap: () {
            Navigator.of(context).pop();
            DesktopLayout.showCreatePlaylistAndAddTrack(context, track);
          },
        ),
        if (playlists.isNotEmpty) const Divider(),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noPlaylistsAvailable,
              style: TextStyle(
                fontSize: 13,
                color: DesktopTheme.textTertiary,
                decoration: TextDecoration.none,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              vertical: DesktopTheme.spacingSm,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _PlaylistItem(
                key: ValueKey(playlist.id),
                playlist: playlist,
                onTap: () => _addToPlaylist(context, playlist),
              );
            },
          ),
      ],
    );
  }

  void _addToPlaylist(BuildContext context, Playlist playlist) async {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);

    try {
      await appState.addToPlaylist(playlist.id, track.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.addedToPlaylist('track', playlist.name, track.name),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorAddingToPlaylist(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Playlist item in add to playlist dialog
class _PlaylistItem extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistItem({super.key, required this.playlist, required this.onTap});

  @override
  State<_PlaylistItem> createState() => _PlaylistItemState();
}

class _PlaylistItemState extends State<_PlaylistItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          margin: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingSm,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? DesktopTheme.glassOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
          ),
          child: Row(
            children: [
              // Playlist icon/image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: DesktopTheme.backgroundElevated,
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.playlist.imageUrl != null
                    ? buildSmartImage(
                        imageUrl: widget.playlist.imageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: () => Icon(
                          Icons.queue_music_rounded,
                          size: 24,
                          color: DesktopTheme.textTertiary,
                        ),
                      )
                    : Icon(
                        Icons.queue_music_rounded,
                        size: 24,
                        color: DesktopTheme.textTertiary,
                      ),
              ),
              const SizedBox(width: DesktopTheme.spacingMd),
              // Playlist info
              Expanded(
                child: Text(
                  widget.playlist.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DesktopTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
