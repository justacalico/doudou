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
import 'package:doudou/ui/pages/details/artist_details.dart';
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
        return _AlbumDetailView(
          album: detailPage.data as Album,
          onBack: navigationService.goBack,
        );
      case DetailPageType.artist:
        return _ArtistDetailView(
          artist: detailPage.data as Artist,
          onBack: navigationService.goBack,
        );
      case DetailPageType.playlist:
        return _PlaylistDetailView(
          playlist: detailPage.data as Playlist,
          onBack: navigationService.goBack,
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

    showAppleDialog(
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

    showAppleDialog(
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
                final list =
                    appState.playlists.where((p) => p.name == name).toList();
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
        color: DesktopTheme.backgroundSecondary,
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
                    ),
                  ),
                  // Right: Volume and extras
                  Expanded(
                    flex: 1,
                    child: _PlayerExtras(
                      audioHandler: audioHandler,
                      onQueueTap: () => _showNowPlaying(context),
                      onClose: () => appState.closePlayerAndClearQueue(),
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
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
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
          tooltip: 'More options',
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
                        builder: (context) => ArtistDetailsPage(artist: artist),
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
                downloadLabel = 'Downloaded';
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
        showAppleDialog(
          context: context,
          title: 'Downloaded',
          content: Text(
            '"${track.name}" is already downloaded.',
            style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
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
        showAppleDialog(
          context: context,
          title: l10n.downloading,
          content: Text(
            '"${track.name}" is currently downloading.',
            style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
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

  const _PlaybackControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.isShuffled,
    required this.repeatMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        DesktopIconButton(
          icon: Icons.shuffle_rounded,
          isActive: isShuffled,
          activeColor: theme.colorScheme.primary,
          onPressed: onShuffle,
          tooltip: 'Shuffle',
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        // Previous
        DesktopIconButton(
          icon: Icons.skip_previous_rounded,
          size: 24,
          onPressed: onPrevious,
          tooltip: 'Previous',
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
          tooltip: 'Next',
        ),
        const SizedBox(width: DesktopTheme.spacingMd),
        // Repeat
        DesktopIconButton(
          icon: repeatMode == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          isActive: repeatMode != RepeatMode.none,
          activeColor: theme.colorScheme.primary,
          onPressed: onRepeat,
          tooltip: 'Repeat',
        ),
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
          transform: Matrix4.identity()..scale(_isHovered ? 1.08 : 1.0),
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

  const _PlayerExtras({
    required this.audioHandler,
    required this.onQueueTap,
    this.onClose,
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
            tooltip: 'Close and clear queue',
            onPressed: widget.onClose,
          ),
          const SizedBox(width: DesktopTheme.spacingSm),
        ],
        // Queue button
        DesktopIconButton(
          icon: Icons.queue_music_rounded,
          tooltip: 'Queue',
          onPressed: widget.onQueueTap,
        ),
        const SizedBox(width: DesktopTheme.spacingSm),
        // Volume
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
        // Fullscreen/Now Playing
        DesktopIconButton(
          icon: Icons.open_in_full_rounded,
          tooltip: 'Now Playing',
          onPressed: widget.onQueueTap,
        ),
      ],
    );
  }
}

/// Add to playlist dialog content (used inside [showAppleDialog]).
class _AddToPlaylistDialogContent extends StatelessWidget {
  final Track track;
  final List<Playlist> playlists;

  const _AddToPlaylistDialogContent({required this.track, required this.playlists});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline, color: CupertinoColors.activeBlue),
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
            padding: const EdgeInsets.symmetric(vertical: DesktopTheme.spacingSm),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _PlaylistItem(
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

  const _PlaylistItem({required this.playlist, required this.onTap});

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

// =============================================================================
// DETAIL VIEW WIDGETS - Inline pages that keep sidebar visible
// =============================================================================

/// Album detail view - displayed inline within the layout
class _AlbumDetailView extends StatefulWidget {
  final Album album;
  final VoidCallback onBack;

  const _AlbumDetailView({required this.album, required this.onBack});

  @override
  State<_AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<_AlbumDetailView> {
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();
    setState(() => _isLoading = true);

    try {
      _tracks = await appState.getAlbumTracks(widget.album.id);
      _tracks.sort((a, b) {
        final aTrack = a.trackNumber ?? 999;
        final bTrack = b.trackNumber ?? 999;
        return aTrack.compareTo(bTrack);
      });
    } catch (e) {
      _tracks = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final imageUrl = _getImageUrl(appState, widget.album.imageUrl);

        return Container(
          color: DesktopTheme.backgroundPrimary,
          child: Column(
            children: [
              // Header with back button
              _DetailHeader(
                onBack: widget.onBack,
                title: widget.album.name,
                subtitle: widget.album.artistName,
                imageUrl: imageUrl,
                year: widget.album.year?.toString(),
                trackCount: _tracks.length,
                onPlay: () => appState.playPlaylist(_tracks, 0),
                onShuffle: () {
                  final shuffled = List<Track>.from(_tracks)..shuffle();
                  appState.playPlaylist(shuffled, 0);
                },
              ),
              // Track list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tracks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noTracksFound,
                          style: TextStyle(color: DesktopTheme.textSecondary),
                        ),
                      )
                    : _TrackListView(
                        tracks: _tracks,
                        appState: appState,
                        showTrackNumber: true,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Artist detail view - displayed inline within the layout
class _ArtistDetailView extends StatefulWidget {
  final Artist artist;
  final VoidCallback onBack;

  const _ArtistDetailView({required this.artist, required this.onBack});

  @override
  State<_ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends State<_ArtistDetailView> {
  List<Album> _albums = [];
  List<Track> _tracks = [];
  bool _isLoading = true;
  String _selectedTab = 'albums';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final appState = context.read<AppState>();
    setState(() => _isLoading = true);

    try {
      _albums = appState.albums
          .where((album) => album.artistName == widget.artist.name)
          .toList();
      _albums.sort((a, b) {
        final aYear = a.year ?? 0;
        final bYear = b.year ?? 0;
        return bYear.compareTo(aYear);
      });

      _tracks = appState.tracks
          .where((track) => track.artistName == widget.artist.name)
          .toList();

      if (_albums.isEmpty) {
        _selectedTab = 'songs';
      }
    } catch (e) {
      _albums = [];
      _tracks = [];
      _selectedTab = 'songs';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigationService = NavigationService();

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final imageUrl = _getImageUrl(appState, widget.artist.imageUrl);

        return Container(
          color: DesktopTheme.backgroundPrimary,
          child: Column(
            children: [
              // Header with back button
              _DetailHeader(
                onBack: widget.onBack,
                title: widget.artist.name,
                subtitle: _albums.isNotEmpty
                    ? '${_albums.length} ${l10n.albums} • ${_tracks.length} ${l10n.songs}'
                    : '${_tracks.length} ${l10n.songs}',
                imageUrl: imageUrl,
                isCircular: true,
                onPlay: () => appState.playPlaylist(_tracks, 0),
                onShuffle: () {
                  final shuffled = List<Track>.from(_tracks)..shuffle();
                  appState.playPlaylist(shuffled, 0);
                },
              ),
              // Tab selector
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesktopTheme.spacingLg,
                  vertical: DesktopTheme.spacingSm,
                ),
                child: _ArtistTabSegmentedControl(
                  showAlbums: _albums.isNotEmpty,
                  selectedTab: _selectedTab,
                  onTabChanged: (tab) => setState(() => _selectedTab = tab),
                  albumsLabel: l10n.albums,
                  songsLabel: l10n.songs,
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _albums.isNotEmpty && _selectedTab == 'albums'
                    ? _AlbumGridView(
                        albums: _albums,
                        appState: appState,
                        onAlbumTap: (album) =>
                            navigationService.navigateToAlbum(album),
                      )
                    : _TrackListView(tracks: _tracks, appState: appState),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Playlist detail view - displayed inline within the layout
class _PlaylistDetailView extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onBack;

  const _PlaylistDetailView({required this.playlist, required this.onBack});

  @override
  State<_PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<_PlaylistDetailView> {
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final appState = context.read<AppState>();
    setState(() => _isLoading = true);

    try {
      _tracks = await appState.getPlaylistTracks(widget.playlist.id);
    } catch (e) {
      _tracks = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final imageUrl = _getImageUrl(appState, widget.playlist.imageUrl);

        return Container(
          color: DesktopTheme.backgroundPrimary,
          child: Column(
            children: [
              // Header with back button
              _DetailHeader(
                onBack: widget.onBack,
                title: widget.playlist.name,
                subtitle: '${_tracks.length} ${l10n.songs}',
                imageUrl: imageUrl,
                onPlay: () => appState.playPlaylist(_tracks, 0),
                onShuffle: () {
                  final shuffled = List<Track>.from(_tracks)..shuffle();
                  appState.playPlaylist(shuffled, 0);
                },
              ),
              // Track list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tracks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noTracksFound,
                          style: TextStyle(color: DesktopTheme.textSecondary),
                        ),
                      )
                    : _TrackListView(tracks: _tracks, appState: appState),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared detail header widget
class _DetailHeader extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? year;
  final int? trackCount;
  final bool isCircular;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  const _DetailHeader({
    required this.onBack,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.year,
    this.trackCount,
    this.isCircular = false,
    this.onPlay,
    this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(DesktopTheme.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            DesktopTheme.backgroundPrimary,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          DesktopIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
            tooltip: l10n.back,
          ),
          const SizedBox(height: DesktopTheme.spacingMd),
          // Content row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Image
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    isCircular ? 90 : DesktopTheme.radiusMd,
                  ),
                  color: DesktopTheme.backgroundElevated,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null
                    ? buildSmartImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: () => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: DesktopTheme.spacingLg),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: DesktopTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DesktopTheme.spacingSm),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 16,
                          color: DesktopTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (year != null || trackCount != null) ...[
                      const SizedBox(height: DesktopTheme.spacingSm),
                      Text(
                        [
                          if (year != null) year,
                          if (trackCount != null) '$trackCount ${l10n.songs}',
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 14,
                          color: DesktopTheme.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: DesktopTheme.spacingLg),
                    // Action buttons
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (onPlay != null)
                            DesktopPlayButton(
                              isPlaying: false,
                              onPressed: onPlay!,
                            ),
                          const SizedBox(width: DesktopTheme.spacingMd),
                          if (onShuffle != null)
                            DesktopGlassButton(
                              onPressed: onShuffle!,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shuffle_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(l10n.shuffle),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DesktopTheme.backgroundTertiary,
      child: Icon(
        isCircular ? Icons.person_rounded : Icons.album_rounded,
        size: 64,
        color: DesktopTheme.textTertiary,
      ),
    );
  }
}

/// Segmented control for artist detail: Songs / Albums as a single pill.
class _ArtistTabSegmentedControl extends StatelessWidget {
  final bool showAlbums;
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final String albumsLabel;
  final String songsLabel;

  const _ArtistTabSegmentedControl({
    required this.showAlbums,
    required this.selectedTab,
    required this.onTabChanged,
    required this.albumsLabel,
    required this.songsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = 20.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: DesktopTheme.glassBorder),
        color: DesktopTheme.backgroundTertiary,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAlbums)
              _Segment(
                label: albumsLabel,
                isSelected: selectedTab == 'albums',
                onTap: () => onTabChanged('albums'),
                theme: theme,
                isFirst: true,
                isLast: false,
              ),
            if (showAlbums)
              _Segment(
                label: songsLabel,
                isSelected: selectedTab == 'songs',
                onTap: () => onTabChanged('songs'),
                theme: theme,
                isFirst: !showAlbums,
                isLast: true,
              )
            else
              _Segment(
                label: songsLabel,
                isSelected: true,
                onTap: () => onTabChanged('songs'),
                theme: theme,
                isFirst: true,
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isFirst;
  final bool isLast;

  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = 20.0;
    BorderRadius? borderRadius;
    if (widget.isFirst && widget.isLast) {
      borderRadius = BorderRadius.circular(radius);
    } else if (widget.isFirst) {
      borderRadius = BorderRadius.horizontal(left: Radius.circular(radius));
    } else if (widget.isLast) {
      borderRadius = BorderRadius.horizontal(right: Radius.circular(radius));
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingLg,
            vertical: DesktopTheme.spacingSm + 2,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.theme.colorScheme.primary
                : _hover
                    ? DesktopTheme.glassOverlay
                    : Colors.transparent,
            borderRadius: borderRadius,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isSelected
                  ? Colors.white
                  : DesktopTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab chip for switching between views
class _TabChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: DesktopTheme.spacingMd,
            vertical: DesktopTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : _isHovered
                ? DesktopTheme.glassOverlay
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusRound),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : DesktopTheme.glassBorder,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.isSelected
                  ? Colors.white
                  : DesktopTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Track list view widget
class _TrackListView extends StatelessWidget {
  final List<Track> tracks;
  final AppState appState;
  final bool showTrackNumber;

  const _TrackListView({
    required this.tracks,
    required this.appState,
    this.showTrackNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopTheme.spacingLg,
        vertical: DesktopTheme.spacingSm,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _TrackRow(
          track: track,
          index: index,
          showTrackNumber: showTrackNumber,
          onTap: () => appState.playPlaylist(tracks, index),
          onAddToQueue: () => appState.addToQueue(track),
        );
      },
    );
  }
}

/// Single track row widget
class _TrackRow extends StatefulWidget {
  final Track track;
  final int index;
  final bool showTrackNumber;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;

  const _TrackRow({
    required this.track,
    required this.index,
    required this.showTrackNumber,
    required this.onTap,
    required this.onAddToQueue,
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _isHovered = false;

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return '--:--';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleDownload(BuildContext context) async {
    final appState = context.read<AppState>();
    final downloadService = appState.downloadService;
    final isDownloaded = downloadService.isTrackDownloaded(widget.track.id);
    final status = downloadService.getDownloadStatus(widget.track.id);

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
      await downloadService.downloadTrack(widget.track);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading "${widget.track.name}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDownloadedOptions(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    showAppleDialog(
      context: context,
      title: 'Downloaded',
      content: Text(
        '"${widget.track.name}" is already downloaded.',
        style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.ok)),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            appState.downloadService.deleteDownload(widget.track.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted download for "${widget.track.name}"'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(l10n.deleteDownload),
        ),
      ],
    );
  }

  void _showDownloadingOptions(BuildContext context, AppState appState) {
    final l10n = AppLocalizations.of(context);
    final progress = appState.downloadService.getDownloadProgress(
      widget.track.id,
    );
    final progressPercent = (progress * 100).toInt();

    showAppleDialog(
      context: context,
      title: l10n.downloading,
      content: Text(
        '"${widget.track.name}" is downloading ($progressPercent%)',
        style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.ok)),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            appState.downloadService.cancelDownload(widget.track.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cancelled download for "${widget.track.name}"',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(l10n.cancelDownload),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final imageUrl = widget.track.imageUrl != null
        ? appState.getImageUrl(widget.track.imageUrl!)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
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
              // Track number or play icon
              SizedBox(
                width: 40,
                child: Center(
                  child: _isHovered
                      ? Icon(
                          Icons.play_arrow_rounded,
                          color: DesktopTheme.textPrimary,
                          size: 20,
                        )
                      : Text(
                          widget.showTrackNumber
                              ? '${widget.track.trackNumber ?? widget.index + 1}'
                              : '${widget.index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            color: DesktopTheme.textTertiary,
                          ),
                        ),
                ),
              ),
              // Album art
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: DesktopTheme.spacingMd),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: DesktopTheme.backgroundElevated,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null
                    ? buildSmartImage(
                        imageUrl: imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: () => Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: DesktopTheme.textTertiary,
                        ),
                      )
                    : Icon(
                        Icons.music_note_rounded,
                        size: 20,
                        color: DesktopTheme.textTertiary,
                      ),
              ),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: DesktopTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.track.artistName ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesktopTheme.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Album name
              if (widget.track.albumName != null)
                Expanded(
                  child: Text(
                    widget.track.albumName!,
                    style: TextStyle(
                      fontSize: 14,
                      color: DesktopTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Duration
              SizedBox(
                width: 60,
                child: Text(
                  _formatDuration(widget.track.duration),
                  style: TextStyle(
                    fontSize: 14,
                    color: DesktopTheme.textTertiary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // More button
              if (_isHovered)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: DesktopTheme.textSecondary,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'queue') {
                      widget.onAddToQueue();
                    } else if (value == 'playlist') {
                      DesktopLayout.showAddToPlaylistDialog(
                        context,
                        widget.track,
                      );
                    } else if (value == 'download') {
                      _handleDownload(context);
                    }
                  },
                  itemBuilder: (context) {
                    final l10n = AppLocalizations.of(context);
                    final appState = context.read<AppState>();
                    final downloadService = appState.downloadService;
                    final isDownloaded = downloadService.isTrackDownloaded(
                      widget.track.id,
                    );
                    final status = downloadService.getDownloadStatus(
                      widget.track.id,
                    );
                    final isDownloading = status == DownloadStatus.downloading;

                    IconData downloadIcon;
                    String downloadLabel;
                    if (isDownloaded) {
                      downloadIcon = Icons.download_done_rounded;
                      downloadLabel = 'Downloaded';
                    } else if (isDownloading) {
                      downloadIcon = Icons.downloading_rounded;
                      downloadLabel = l10n.downloading;
                    } else {
                      downloadIcon = Icons.download_rounded;
                      downloadLabel = l10n.download;
                    }

                    return [
                      PopupMenuItem(
                        value: 'queue',
                        child: Row(
                          children: [
                            const Icon(Icons.queue_music_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.addToQueue),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'playlist',
                        child: Row(
                          children: [
                            const Icon(Icons.playlist_add_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.addToPlaylist),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(downloadIcon, size: 20),
                            const SizedBox(width: 8),
                            Text(downloadLabel),
                          ],
                        ),
                      ),
                    ];
                  },
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Album grid view widget
class _AlbumGridView extends StatelessWidget {
  final List<Album> albums;
  final AppState appState;
  final Function(Album) onAlbumTap;

  const _AlbumGridView({
    required this.albums,
    required this.appState,
    required this.onAlbumTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minCardWidth = 160.0;
        final crossAxisCount = (constraints.maxWidth / minCardWidth)
            .floor()
            .clamp(2, 6);

        return GridView.builder(
          padding: const EdgeInsets.all(DesktopTheme.spacingLg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.8,
            crossAxisSpacing: DesktopTheme.spacingMd,
            mainAxisSpacing: DesktopTheme.spacingMd,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return _AlbumCard(
              album: album,
              imageUrl: album.imageUrl != null
                  ? appState.getImageUrl(album.imageUrl!)
                  : null,
              onTap: () => onAlbumTap(album),
            );
          },
        );
      },
    );
  }
}

/// Album card widget
class _AlbumCard extends StatefulWidget {
  final Album album;
  final String? imageUrl;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _isHovered
                ? DesktopTheme.backgroundElevated
                : DesktopTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
          ),
          padding: const EdgeInsets.all(DesktopTheme.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album art
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          DesktopTheme.radiusSm,
                        ),
                        color: DesktopTheme.backgroundTertiary,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.imageUrl != null
                          ? buildSmartImage(
                              imageUrl: widget.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: () => Center(
                                child: Icon(
                                  Icons.album_rounded,
                                  size: 48,
                                  color: DesktopTheme.textTertiary,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.album_rounded,
                                size: 48,
                                color: DesktopTheme.textTertiary,
                              ),
                            ),
                    ),
                    // Play button overlay
                    if (_isHovered)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DesktopTheme.spacingSm),
              // Album name
              Text(
                widget.album.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DesktopTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Artist name
              Text(
                widget.album.artistName ?? '',
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
      ),
    );
  }
}
