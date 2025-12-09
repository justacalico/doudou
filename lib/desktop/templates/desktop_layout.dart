import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../pages/home.dart';
import '../services/navigation_service.dart';
import '../../providers/app_state.dart';
import '../pages/albums.dart';
import '../pages/playlists.dart';
import '../pages/artists.dart';
import '../pages/search.dart';
import '../pages/library.dart';
import '../pages/tracks.dart';
import '../pages/settings.dart';
import '../../services/desktop_lyrics_service.dart';
import '../../models/jellyfin_models.dart';

class DesktopLayout extends StatefulWidget {
  final Widget? child;
  final int? selectedIndex;
  final VoidCallback? onNavigationChanged;
  final bool showBackButton;
  final String? title;
  final Function(int)? onMainPageNavigation;

  const DesktopLayout({
    super.key,
    this.child,
    this.selectedIndex,
    this.onNavigationChanged,
    this.showBackButton = false,
    this.title,
    this.onMainPageNavigation,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();

  /// Shows a dialog to add a track to a playlist
  static Future<void> showAddToPlaylistDialog(
    BuildContext context,
    Track track,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Consumer<AppState>(
          builder: (context, appState, child) {
            return _AddToPlaylistDialog(
              track: track,
              playlists: appState.playlists,
              onAddToPlaylist: (playlistId) async {
                final success = await appState.addToPlaylist(
                  playlistId,
                  track.id,
                );
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${track.name}" to playlist'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to add track to playlist'),
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _selectedIndex = 0;
  final NavigationService _navigationService = NavigationService();

  final List<String> _navigationItems = [
    'Home',
    'Search',
    'Library',
    'Tracks',
    'Playlists',
    'Albums',
    'Artists',
    'Settings',
  ];

  final List<IconData> _navigationIcons = [
    Icons.home_outlined,
    Icons.search,
    Icons.library_music_outlined,
    Icons.music_note_outlined,
    Icons.playlist_play_outlined,
    Icons.album_outlined,
    Icons.person_outline,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex ?? 0;
  }

  @override
  void didUpdateWidget(DesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != null &&
        widget.selectedIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = widget.selectedIndex!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Main content area with sidebar
          Expanded(
            child: Row(
              children: [
                // Left Sidebar
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // App title/logo area with optional back button
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            if (widget.showBackButton) ...[
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back),
                                tooltip: 'Back',
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              Icons.music_note,
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.title ?? 'Doudou',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Navigation items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _navigationItems.length,
                          itemBuilder: (context, index) {
                            final currentSelectedIndex =
                                widget.selectedIndex ?? _selectedIndex;
                            final isSelected = index == currentSelectedIndex;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: ListTile(
                                selected: isSelected,
                                selectedTileColor:
                                    theme.colorScheme.primaryContainer,
                                leading: Icon(
                                  _navigationIcons[index],
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  _navigationItems[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                onTap: () {
                                  if (widget.child != null &&
                                      widget.showBackButton) {
                                    // If we're on a detail page, navigate back to main app
                                    Navigator.popUntil(
                                      context,
                                      (route) => route.isFirst,
                                    );
                                    // Update the navigation service to show correct page
                                    _navigationService.navigateToMainPage(
                                      index,
                                    );
                                  } else {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                    // Also update the navigation service for consistency
                                    _navigationService.selectPage(index);
                                    widget.onNavigationChanged?.call();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content area
                Expanded(
                  child: Container(
                    color: theme.colorScheme.background,
                    child: widget.child ?? _buildMainContent(),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Player Bar
          _buildBottomPlayerBar(theme),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const SearchPage();
      case 2:
        return const LibraryPage();
      case 3:
        return const TracksPage();
      case 4:
        return const PlaylistsPage();
      case 5:
        return const AlbumsPage();
      case 6:
        return const ArtistsPage();
      case 7:
        return const SettingsPage();
      default:
        return const HomePage();
    }
  }

  Widget _buildBottomPlayerBar(ThemeData theme) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;

        return StreamBuilder<PlaybackState>(
          stream: audioHandler?.playbackState,
          builder: (context, playbackSnapshot) {
            return StreamBuilder<MediaItem?>(
              stream: audioHandler?.mediaItem,
              builder: (context, mediaSnapshot) {
                final currentTrack = mediaSnapshot.data;

                return StreamBuilder<Duration>(
                  stream: audioHandler?.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration?>(
                      stream: audioHandler?.durationStream,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ?? Duration.zero;
                        final progress = duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0;

                        return Container(
                          height: 88,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withOpacity(
                                  0.1,
                                ),
                                offset: const Offset(0, -2),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Slim progress bar
                              SizedBox(
                                height: 4,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 0,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 0,
                                    ),
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: theme
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.1),
                                  ),
                                  child: Slider(
                                    value: progress.clamp(0.0, 1.0),
                                    onChanged:
                                        currentTrack != null &&
                                            audioHandler != null
                                        ? (value) {
                                            final newPosition = Duration(
                                              milliseconds:
                                                  (value *
                                                          duration
                                                              .inMilliseconds)
                                                      .round(),
                                            );
                                            audioHandler.seek(newPosition);
                                          }
                                        : null,
                                    min: 0.0,
                                    max: 1.0,
                                  ),
                                ),
                              ),

                              // Main player content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    12,
                                    20,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      // Album art with hover effect
                                      GestureDetector(
                                        onTap: currentTrack != null
                                            ? () =>
                                                  _showNowPlayingDialog(context)
                                            : null,
                                        child: Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.shadow
                                                    .withOpacity(0.1),
                                                offset: const Offset(0, 2),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: currentTrack?.artUri != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.network(
                                                    currentTrack!.artUri
                                                        .toString(),
                                                    width: 64,
                                                    height: 64,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return Icon(
                                                            Icons
                                                                .music_note_rounded,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                            size: 32,
                                                          );
                                                        },
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.music_note_rounded,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  size: 32,
                                                ),
                                        ),
                                      ),

                                      const SizedBox(width: 20),

                                      // Track info - improved layout
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: currentTrack != null
                                              ? () => _showNowPlayingDialog(
                                                  context,
                                                )
                                              : null,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                currentTrack?.title ??
                                                    'No track playing',
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      currentTrack?.artist ??
                                                          'Select a song to play',
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (currentTrack != null) ...[
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),
                                                      width: 4,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.6),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Consumer<AppState>(
                                                      builder: (context, appState, child) {
                                                        final timeText =
                                                            '${_formatDuration(position)} / ${_formatDuration(duration)}';

                                                        return Text(
                                                          timeText,
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                                fontFamily:
                                                                    'monospace',
                                                                fontSize: 12,
                                                              ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 24),

                                      // Player controls - enhanced design
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed:
                                                  audioHandler != null &&
                                                      audioHandler.hasPrevious
                                                  ? () => appState
                                                        .skipToPrevious()
                                                  : null,
                                              icon: const Icon(
                                                Icons.skip_previous_rounded,
                                              ),
                                              iconSize: 24,
                                              style: IconButton.styleFrom(
                                                foregroundColor: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.3),
                                                    offset: const Offset(0, 4),
                                                    blurRadius: 12,
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: Consumer<AppState>(
                                                builder: (context, appState, child) {
                                                  return StreamBuilder<
                                                    PlaybackState
                                                  >(
                                                    stream: audioHandler
                                                        ?.playbackState,
                                                    builder: (context, playbackSnapshot) {
                                                      final playbackState =
                                                          playbackSnapshot.data;
                                                      final currentIsPlaying =
                                                          playbackState
                                                              ?.playing ==
                                                          true;
                                                      final currentIsBuffering =
                                                          playbackState
                                                              ?.processingState ==
                                                          AudioProcessingState
                                                              .buffering;

                                                      // Debug logs for main desktop button
                                                      if (kDebugMode) {
                                                        print(
                                                          '=== MAIN DESKTOP BUTTON REBUILD ===',
                                                        );
                                                        print(
                                                          'DateTime: ${DateTime.now()}',
                                                        );
                                                        print(
                                                          'audioHandler != null: ${audioHandler != null}',
                                                        );
                                                        print(
                                                          'currentTrack != null: ${currentTrack != null}',
                                                        );
                                                        print(
                                                          'RAW playbackState: $playbackState',
                                                        );
                                                        print(
                                                          'playbackState?.playing: ${playbackState?.playing}',
                                                        );
                                                        print(
                                                          'playbackState?.processingState: ${playbackState?.processingState}',
                                                        );
                                                        print(
                                                          'currentIsPlaying: $currentIsPlaying',
                                                        );
                                                        print(
                                                          'currentIsBuffering: $currentIsBuffering',
                                                        );
                                                        print(
                                                          'Button should be enabled: ${audioHandler != null && currentTrack != null && !currentIsBuffering}',
                                                        );
                                                      }

                                                      return IconButton(
                                                        onPressed:
                                                            audioHandler !=
                                                                    null &&
                                                                currentTrack !=
                                                                    null &&
                                                                !currentIsBuffering
                                                            ? () {
                                                                if (kDebugMode) {
                                                                  print(
                                                                    '=== MAIN DESKTOP PLAY/PAUSE BUTTON CLICKED ===',
                                                                  );
                                                                  print(
                                                                    'DateTime: ${DateTime.now()}',
                                                                  );
                                                                  print(
                                                                    'currentIsPlaying: $currentIsPlaying',
                                                                  );
                                                                  print(
                                                                    'currentIsBuffering: $currentIsBuffering',
                                                                  );
                                                                  print(
                                                                    'currentTrack: ${currentTrack.displayTitle}',
                                                                  );
                                                                  print(
                                                                    'audioHandler: available',
                                                                  );
                                                                  print(
                                                                    'About to call appState.playPause()...',
                                                                  );
                                                                }
                                                                appState
                                                                    .playPause();
                                                              }
                                                            : () {
                                                                if (kDebugMode) {
                                                                  print(
                                                                    '=== MAIN DESKTOP BUTTON DISABLED ===',
                                                                  );
                                                                  print(
                                                                    'Button disabled - audioHandler: ${audioHandler != null}, currentTrack: ${currentTrack != null}, isBuffering: $currentIsBuffering',
                                                                  );
                                                                }
                                                              },
                                                        icon: currentIsBuffering
                                                            ? SizedBox(
                                                                width: 24,
                                                                height: 24,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onPrimary,
                                                                ),
                                                              )
                                                            : Icon(
                                                                currentIsPlaying
                                                                    ? Icons
                                                                          .pause_rounded
                                                                    : Icons
                                                                          .play_arrow_rounded,
                                                                size: 28,
                                                              ),
                                                        style: IconButton.styleFrom(
                                                          foregroundColor: theme
                                                              .colorScheme
                                                              .onPrimary,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  24,
                                                                ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed:
                                                  audioHandler != null &&
                                                      audioHandler.hasNext
                                                  ? () => appState.skipToNext()
                                                  : null,
                                              icon: const Icon(
                                                Icons.skip_next_rounded,
                                              ),
                                              iconSize: 24,
                                              style: IconButton.styleFrom(
                                                foregroundColor: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 24),

                                      // Right side controls - cleaner layout
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Favorite button
                                          Consumer<AppState>(
                                            builder: (context, appState, child) {
                                              if (currentTrack == null) {
                                                return const SizedBox.shrink();
                                              }

                                              // Find the track in the app state
                                              final trackInState = appState
                                                  .tracks
                                                  .firstWhere(
                                                    (t) =>
                                                        t.id == currentTrack.id,
                                                    orElse: () => Track(
                                                      id: currentTrack.id,
                                                      name: currentTrack.title,
                                                      albumName:
                                                          currentTrack.album,
                                                      artistName:
                                                          currentTrack.artist,
                                                      albumId:
                                                          currentTrack
                                                                  .extras?['albumId']
                                                              as String? ??
                                                          '',
                                                      duration:
                                                          currentTrack
                                                              .duration
                                                              ?.inSeconds ??
                                                          0,
                                                      trackNumber: null,
                                                      imageUrl: null,
                                                      isFavorite:
                                                          false, // Default to false, will be updated after server response
                                                    ),
                                                  );

                                              final isFavorite =
                                                  trackInState.isFavorite;
                                              final trackFound = appState.tracks
                                                  .any(
                                                    (t) =>
                                                        t.id == currentTrack.id,
                                                  );

                                              if (kDebugMode) {
                                                print(
                                                  'Desktop Heart UI: currentTrack=${currentTrack.title}, isFavorite=$isFavorite, trackFound=$trackFound, trackId=${currentTrack.id}',
                                                );
                                              }

                                              return IconButton(
                                                onPressed: () {
                                                  if (kDebugMode) {
                                                    print(
                                                      'Desktop Heart Button Clicked: Track=${trackInState.name}, Current isFavorite=${trackInState.isFavorite}',
                                                    );
                                                  }
                                                  appState.toggleFavorite(
                                                    trackInState,
                                                  );
                                                },
                                                icon: Icon(
                                                  isFavorite
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: 20,
                                                ),
                                                style: IconButton.styleFrom(
                                                  foregroundColor: isFavorite
                                                      ? Colors.red
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                tooltip: isFavorite
                                                    ? 'Remove from favorites'
                                                    : 'Add to favorites',
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          StreamBuilder<double>(
                                            stream: audioHandler?.volumeStream,
                                            builder: (context, volumeSnapshot) {
                                              final currentVolume =
                                                  volumeSnapshot.data ?? 1.0;

                                              return IconButton(
                                                onPressed: () =>
                                                    _showVolumeDialog(context),
                                                onLongPress:
                                                    audioHandler != null
                                                    ? () => audioHandler
                                                          .toggleMute()
                                                    : null,
                                                icon: Icon(
                                                  currentVolume == 0.0
                                                      ? Icons.volume_off_rounded
                                                      : currentVolume < 0.5
                                                      ? Icons
                                                            .volume_down_rounded
                                                      : Icons.volume_up_rounded,
                                                  size: 20,
                                                ),
                                                style: IconButton.styleFrom(
                                                  foregroundColor: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                tooltip:
                                                    'Volume ${(currentVolume * 100).round()}%',
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: currentTrack != null
                                                ? () => _showNowPlayingDialog(
                                                    context,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.open_in_full_rounded,
                                              size: 20,
                                            ),
                                            style: IconButton.styleFrom(
                                              foregroundColor: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            tooltip: 'Show Now Playing',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  void _showNowPlayingDialog(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _YouTubeMusicNowPlaying(navigationService: _navigationService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNowPlayingControls(BuildContext context, dynamic audioHandler) {
    final theme = Theme.of(context);

    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, playbackSnapshot) {
        return StreamBuilder<MediaItem?>(
          stream: audioHandler?.mediaItem,
          builder: (context, mediaSnapshot) {
            final currentTrack = mediaSnapshot.data;

            return StreamBuilder<Duration>(
              stream: audioHandler?.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;

                return StreamBuilder<Duration>(
                  stream: audioHandler?.durationStream,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;

                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Compact progress bar with time labels
                          Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Column(
                              children: [
                                // Progress slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 6,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14,
                                    ),
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor:
                                        theme.colorScheme.surfaceVariant,
                                    thumbColor: theme.colorScheme.primary,
                                    overlayColor: theme.colorScheme.primary
                                        .withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: progress.clamp(0.0, 1.0),
                                    onChanged:
                                        currentTrack != null &&
                                            audioHandler != null
                                        ? (value) {
                                            final newPosition = Duration(
                                              milliseconds:
                                                  (value *
                                                          duration
                                                              .inMilliseconds)
                                                      .round(),
                                            );
                                            audioHandler.seek(newPosition);
                                          }
                                        : null,
                                    min: 0.0,
                                    max: 1.0,
                                  ),
                                ),

                                // Time labels
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Compact player controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Shuffle button
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: StreamBuilder<PlaybackState>(
                                  stream: audioHandler?.playbackState,
                                  builder: (context, playbackSnapshot) {
                                    final playbackState = playbackSnapshot.data;
                                    final isShuffled =
                                        playbackState?.shuffleMode ==
                                        AudioServiceShuffleMode.all;
                                    return IconButton(
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                      onPressed: audioHandler != null
                                          ? () => audioHandler.setShuffleMode(
                                              isShuffled
                                                  ? AudioServiceShuffleMode.none
                                                  : AudioServiceShuffleMode.all,
                                            )
                                          : null,
                                      icon: Icon(
                                        Icons.shuffle_rounded,
                                        color: isShuffled
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                      iconSize: 20,
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Previous button
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  onPressed:
                                      audioHandler != null &&
                                          audioHandler.hasPrevious
                                      ? () => Provider.of<AppState>(
                                          context,
                                          listen: false,
                                        ).skipToPrevious()
                                      : null,
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    color:
                                        audioHandler != null &&
                                            audioHandler.hasPrevious
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurfaceVariant
                                              .withOpacity(0.5),
                                  ),
                                  iconSize: 24,
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Enhanced play/pause button
                              Consumer<AppState>(
                                builder: (context, appState, child) {
                                  return StreamBuilder<PlaybackState>(
                                    stream: audioHandler?.playbackState,
                                    builder: (context, playbackSnapshot) {
                                      final playbackState =
                                          playbackSnapshot.data;
                                      final isPlaying =
                                          playbackState?.playing == true;
                                      final isBuffering =
                                          playbackState?.processingState ==
                                          AudioProcessingState.buffering;

                                      return Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.primary
                                                  .withOpacity(0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            onTap:
                                                audioHandler != null &&
                                                    currentTrack != null
                                                ? () {
                                                    if (kDebugMode) {
                                                      print(
                                                        '=== ENHANCED DESKTOP PLAY/PAUSE BUTTON CLICKED ===',
                                                      );
                                                    }
                                                    try {
                                                      appState.playPause();
                                                    } catch (e) {
                                                      if (kDebugMode) {
                                                        print(
                                                          'ERROR calling playPause(): $e',
                                                        );
                                                      }
                                                    }
                                                  }
                                                : null,
                                            child: Center(
                                              child: isBuffering
                                                  ? SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              theme
                                                                  .colorScheme
                                                                  .onPrimary,
                                                            ),
                                                      ),
                                                    )
                                                  : Icon(
                                                      isPlaying
                                                          ? Icons.pause_rounded
                                                          : Icons
                                                                .play_arrow_rounded,
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimary,
                                                      size: 28,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),

                              const SizedBox(width: 16),

                              // Next button
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  onPressed:
                                      audioHandler != null &&
                                          audioHandler.hasNext
                                      ? () => Provider.of<AppState>(
                                          context,
                                          listen: false,
                                        ).skipToNext()
                                      : null,
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color:
                                        audioHandler != null &&
                                            audioHandler.hasNext
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurfaceVariant
                                              .withOpacity(0.5),
                                  ),
                                  iconSize: 24,
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Repeat button
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: StreamBuilder<PlaybackState>(
                                  stream: audioHandler?.playbackState,
                                  builder: (context, playbackSnapshot) {
                                    final playbackState = playbackSnapshot.data;
                                    final repeatMode =
                                        playbackState?.repeatMode ??
                                        AudioServiceRepeatMode.none;
                                    return IconButton(
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                      onPressed: audioHandler != null
                                          ? () async {
                                              switch (repeatMode) {
                                                case AudioServiceRepeatMode
                                                    .none:
                                                  await audioHandler
                                                      .setRepeatMode(
                                                        AudioServiceRepeatMode
                                                            .all,
                                                      );
                                                  break;
                                                case AudioServiceRepeatMode.all:
                                                  await audioHandler
                                                      .setRepeatMode(
                                                        AudioServiceRepeatMode
                                                            .one,
                                                      );
                                                  break;
                                                case AudioServiceRepeatMode.one:
                                                  await audioHandler
                                                      .setRepeatMode(
                                                        AudioServiceRepeatMode
                                                            .none,
                                                      );
                                                  break;
                                                case AudioServiceRepeatMode
                                                    .group:
                                                  await audioHandler
                                                      .setRepeatMode(
                                                        AudioServiceRepeatMode
                                                            .none,
                                                      );
                                                  break;
                                              }
                                            }
                                          : null,
                                      icon: Icon(
                                        repeatMode == AudioServiceRepeatMode.one
                                            ? Icons.repeat_one_rounded
                                            : Icons.repeat_rounded,
                                        color:
                                            repeatMode ==
                                                AudioServiceRepeatMode.none
                                            ? theme.colorScheme.onSurfaceVariant
                                                  .withOpacity(0.5)
                                            : theme.colorScheme.primary,
                                      ),
                                      iconSize: 20,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Compact additional controls row with favorites
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Favorites button
                              Consumer<AppState>(
                                builder: (context, appState, child) {
                                  if (currentTrack == null) {
                                    return const SizedBox.shrink();
                                  }

                                  // Find the track in the state or create a default one
                                  final trackInState = appState.tracks
                                      .firstWhere(
                                        (t) => t.id == currentTrack.id,
                                        orElse: () => Track(
                                          id: currentTrack.id,
                                          name: currentTrack.title,
                                          albumName: currentTrack.album,
                                          artistName: currentTrack.artist,
                                          albumId:
                                              currentTrack.extras?['albumId']
                                                  as String? ??
                                              '',
                                          duration:
                                              currentTrack
                                                  .duration
                                                  ?.inSeconds ??
                                              0,
                                          trackNumber: null,
                                          imageUrl: null,
                                          isFavorite: false,
                                        ),
                                      );

                                  final isFavorite = trackInState.isFavorite;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isFavorite
                                          ? theme.colorScheme.primaryContainer
                                                .withOpacity(0.8)
                                          : theme.colorScheme.surfaceVariant
                                                .withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isFavorite
                                            ? theme.colorScheme.primary
                                                  .withOpacity(0.3)
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => appState.toggleFavorite(
                                          trackInState,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isFavorite
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                          .favorite_border_rounded,
                                                color: isFavorite
                                                    ? Colors.red.shade400
                                                    : theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isFavorite
                                                    ? 'Favorited'
                                                    : 'Favorite',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: isFavorite
                                                          ? theme
                                                                .colorScheme
                                                                .onPrimaryContainer
                                                          : theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(width: 12),

                              // Queue button
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      // TODO: Show queue
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.queue_music_rounded,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Queue',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Lyrics button
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      // TODO: Show lyrics
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lyrics_rounded,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Lyrics',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  void _showVolumeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Consumer<AppState>(
        builder: (context, appState, child) {
          final audioHandler = appState.audioHandler;

          return Dialog(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Volume Control',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        iconSize: 20,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Volume slider
                  if (audioHandler != null)
                    StreamBuilder<double>(
                      stream: audioHandler.volumeStream,
                      builder: (context, volumeSnapshot) {
                        final currentVolume = volumeSnapshot.data ?? 1.0;

                        return Column(
                          children: [
                            // Volume percentage display
                            Text(
                              '${(currentVolume * 100).round()}%',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontFamily: 'monospace',
                                  ),
                            ),

                            const SizedBox(height: 16),

                            // Volume slider
                            Row(
                              children: [
                                Icon(
                                  currentVolume == 0
                                      ? Icons.volume_off
                                      : currentVolume < 0.5
                                      ? Icons.volume_down
                                      : Icons.volume_up,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 18,
                                          ),
                                      activeTrackColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      inactiveTrackColor: Theme.of(
                                        context,
                                      ).colorScheme.outline.withOpacity(0.2),
                                      thumbColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      overlayColor: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.2),
                                    ),
                                    child: Slider(
                                      value: currentVolume.clamp(0.0, 1.0),
                                      onChanged: (value) {
                                        audioHandler.setVolume(value);
                                      },
                                      min: 0.0,
                                      max: 1.0,
                                      divisions: 20,
                                    ),
                                  ),
                                ),
                                Text(
                                  '100%',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontFamily: 'monospace',
                                      ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Quick volume buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildQuickVolumeButton(
                                  context,
                                  audioHandler,
                                  Icons.volume_off,
                                  'Mute',
                                  0.0,
                                ),
                                _buildQuickVolumeButton(
                                  context,
                                  audioHandler,
                                  Icons.volume_down,
                                  '25%',
                                  0.25,
                                ),
                                _buildQuickVolumeButton(
                                  context,
                                  audioHandler,
                                  Icons.volume_up,
                                  '50%',
                                  0.5,
                                ),
                                _buildQuickVolumeButton(
                                  context,
                                  audioHandler,
                                  Icons.volume_up,
                                  '75%',
                                  0.75,
                                ),
                                _buildQuickVolumeButton(
                                  context,
                                  audioHandler,
                                  Icons.volume_up,
                                  '100%',
                                  1.0,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.volume_off,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No audio handler available',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickVolumeButton(
    BuildContext context,
    dynamic audioHandler,
    IconData icon,
    String label,
    double volume,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => audioHandler?.setVolume(volume),
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
}

// YouTube Music-style Now Playing Screen
class _YouTubeMusicNowPlaying extends StatefulWidget {
  final NavigationService navigationService;

  const _YouTubeMusicNowPlaying({required this.navigationService});

  @override
  State<_YouTubeMusicNowPlaying> createState() => _YouTubeMusicNowPlayingState();
}

class _YouTubeMusicNowPlayingState extends State<_YouTubeMusicNowPlaying>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;

        return StreamBuilder<MediaItem?>(
          stream: audioHandler?.mediaItem,
          builder: (context, mediaItemSnapshot) {
            final currentTrack = mediaItemSnapshot.data;

            return Scaffold(
              backgroundColor: const Color(0xFF0F0F0F),
              body: Row(
                children: [
                  // Main content area (left side - like YouTube Music video area)
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        // Background with album art blur
                        if (currentTrack?.artUri != null)
                          Positioned.fill(
                            child: Image.network(
                              currentTrack!.artUri.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(color: const Color(0xFF0F0F0F));
                              },
                            ),
                          ),
                        
                        // Dark overlay gradient
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF0F0F0F).withOpacity(0.3),
                                  const Color(0xFF0F0F0F).withOpacity(0.7),
                                  const Color(0xFF0F0F0F).withOpacity(0.95),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Main content
                        Column(
                          children: [
                            // Top bar with close button and Song/Video toggle
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Close button
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  
                                  const Spacer(),

                                  // Song/Video toggle (like YouTube Music)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildToggleButton('Song', true),
                                        _buildToggleButton('Video', false),
                                      ],
                                    ),
                                  ),

                                  const Spacer(),

                                  // More options button
                                  IconButton(
                                    onPressed: () {
                                      // Show options menu
                                    },
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Center content area
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Album art or lyrics
                                    if (_showLyrics)
                                      Expanded(
                                        child: _YouTubeMusicLyrics(
                                          audioHandler: audioHandler,
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: Center(
                                          child: _buildAlbumArt(currentTrack),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Track info and controls at bottom
                            _buildBottomSection(context, appState, audioHandler, currentTrack),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right sidebar - Up Next queue (like YouTube Music)
                  Container(
                    width: 350,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1D1D),
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Tabs header
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _buildSidebarTab('UP NEXT', 0),
                              const SizedBox(width: 24),
                              _buildSidebarTab('LYRICS', 1),
                              const SizedBox(width: 24),
                              _buildSidebarTab('RELATED', 2),
                              const Spacer(),
                              // Save button
                              TextButton.icon(
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.playlist_add,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Save',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Playing from indicator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                'Playing from ',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  currentTrack?.album ?? 'Unknown Album',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildFilterChip('All', true),
                              const SizedBox(width: 8),
                              _buildFilterChip('Familiar', false),
                              const SizedBox(width: 8),
                              _buildFilterChip('Upbeat', false),
                              const SizedBox(width: 8),
                              _buildFilterChip('Alternative', false),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Queue list
                        Expanded(
                          child: _buildQueueList(appState, audioHandler),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToggleButton(String label, bool isSong) {
    final isActive = isSong; // Currently only Song mode is active
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.black : Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSidebarTab(String label, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: label.length * 6.0,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAlbumArt(MediaItem? currentTrack) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 400,
        maxHeight: 400,
      ),
      margin: const EdgeInsets.all(32),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 8,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: currentTrack?.artUri != null
                ? Image.network(
                    currentTrack!.artUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderArt();
                    },
                  )
                : _buildPlaceholderArt(),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      color: const Color(0xFF282828),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 100,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    AppState appState,
    dynamic audioHandler,
    MediaItem? currentTrack,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          // Track info row
          Row(
            children: [
              // Track details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are listening to',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack?.title ?? 'No track playing',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'By ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            currentTrack?.artist ?? 'Unknown Artist',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'From ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            currentTrack?.album ?? 'unknown',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Row(
                children: [
                  // Thumbs down
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.thumb_down_outlined),
                    color: Colors.white.withOpacity(0.7),
                    iconSize: 24,
                  ),
                  const SizedBox(width: 8),
                  // Favorite/Like button
                  Consumer<AppState>(
                    builder: (context, appState, child) {
                      if (currentTrack == null) {
                        return const SizedBox.shrink();
                      }
                      final trackInState = appState.tracks.firstWhere(
                        (t) => t.id == currentTrack.id,
                        orElse: () => Track(
                          id: currentTrack.id,
                          name: currentTrack.title,
                          albumName: currentTrack.album,
                          artistName: currentTrack.artist,
                          albumId: currentTrack.extras?['albumId'] as String? ?? '',
                          duration: currentTrack.duration?.inSeconds ?? 0,
                          trackNumber: null,
                          imageUrl: null,
                          isFavorite: false,
                        ),
                      );
                      final isFavorite = trackInState.isFavorite;

                      return IconButton(
                        onPressed: () => appState.toggleFavorite(trackInState),
                        icon: Icon(
                          isFavorite ? Icons.thumb_up : Icons.thumb_up_outlined,
                        ),
                        color: isFavorite ? Colors.white : Colors.white.withOpacity(0.7),
                        iconSize: 24,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Lyrics toggle
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showLyrics = !_showLyrics;
                      });
                    },
                    icon: Icon(
                      _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
                    ),
                    color: _showLyrics ? Colors.white : Colors.white.withOpacity(0.7),
                    iconSize: 24,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          StreamBuilder<Duration>(
            stream: audioHandler?.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;

              return StreamBuilder<Duration?>(
                stream: audioHandler?.durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return Column(
                    children: [
                      // Progress slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withOpacity(0.2),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: currentTrack != null && audioHandler != null
                              ? (value) {
                                  final newPosition = Duration(
                                    milliseconds:
                                        (value * duration.inMilliseconds).round(),
                                  );
                                  audioHandler.seek(newPosition);
                                }
                              : null,
                          min: 0.0,
                          max: 1.0,
                        ),
                      ),

                      // Time labels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 8),

          // Playback controls
          StreamBuilder<PlaybackState>(
            stream: audioHandler?.playbackState,
            builder: (context, playbackSnapshot) {
              final playbackState = playbackSnapshot.data;
              final isPlaying = playbackState?.playing == true;
              final isBuffering =
                  playbackState?.processingState == AudioProcessingState.buffering;
              final shuffleMode = playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
              final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shuffle
                  IconButton(
                    onPressed: audioHandler != null
                        ? () => audioHandler.setShuffleMode(
                            shuffleMode == AudioServiceShuffleMode.all
                                ? AudioServiceShuffleMode.none
                                : AudioServiceShuffleMode.all,
                          )
                        : null,
                    icon: const Icon(Icons.shuffle_rounded),
                    color: shuffleMode == AudioServiceShuffleMode.all
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    iconSize: 24,
                  ),

                  const SizedBox(width: 16),

                  // Previous
                  IconButton(
                    onPressed: audioHandler != null && audioHandler.hasPrevious
                        ? () => appState.skipToPrevious()
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: audioHandler?.hasPrevious == true
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    iconSize: 36,
                  ),

                  const SizedBox(width: 16),

                  // Play/Pause
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: audioHandler != null && currentTrack != null
                            ? () => appState.playPause()
                            : null,
                        child: Center(
                          child: isBuffering
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 36,
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Next
                  IconButton(
                    onPressed: audioHandler != null && audioHandler.hasNext
                        ? () => appState.skipToNext()
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    color: audioHandler?.hasNext == true
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    iconSize: 36,
                  ),

                  const SizedBox(width: 16),

                  // Repeat
                  IconButton(
                    onPressed: audioHandler != null
                        ? () async {
                            switch (repeatMode) {
                              case AudioServiceRepeatMode.none:
                                await audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                                break;
                              case AudioServiceRepeatMode.all:
                                await audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
                                break;
                              case AudioServiceRepeatMode.one:
                              case AudioServiceRepeatMode.group:
                                await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                                break;
                            }
                          }
                        : null,
                    icon: Icon(
                      repeatMode == AudioServiceRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                    ),
                    color: repeatMode != AudioServiceRepeatMode.none
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    iconSize: 24,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(AppState appState, dynamic audioHandler) {
    final queue = appState.queue;

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No songs in queue',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaSnapshot) {
        final currentMediaItem = mediaSnapshot.data;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: queue.length,
          itemBuilder: (context, index) {
            final track = queue[index];
            final isCurrentTrack = currentMediaItem?.id == track.id;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isCurrentTrack
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: track.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                appState.getImageUrl(track.imageUrl!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.music_note,
                                    color: Colors.white.withOpacity(0.3),
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.music_note,
                              color: Colors.white.withOpacity(0.3),
                              size: 24,
                            ),
                    ),
                    if (isCurrentTrack)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  track.name,
                  style: TextStyle(
                    color: isCurrentTrack ? Colors.white : Colors.white.withOpacity(0.9),
                    fontWeight: isCurrentTrack ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  track.artistName ?? 'Unknown Artist',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatDuration(Duration(seconds: track.duration)),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () {
                  appState.skipToIndex(index);
                },
              ),
            );
          },
        );
      },
    );
  }
}

// YouTube Music-style Lyrics Widget
class _YouTubeMusicLyrics extends StatefulWidget {
  final dynamic audioHandler;

  const _YouTubeMusicLyrics({required this.audioHandler});

  @override
  State<_YouTubeMusicLyrics> createState() => _YouTubeMusicLyricsState();
}

class _YouTubeMusicLyricsState extends State<_YouTubeMusicLyrics> {
  String? _cachedTrackId;
  Future<DesktopLyrics?>? _cachedLyricsFuture;
  final ScrollController _scrollController = ScrollController();
  int _previousCurrentLine = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getCurrentLyricLineIndex(List<DesktopLyricsLine> lines, Duration position) {
    if (lines.isEmpty) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        return i;
      }
    }
    return -1;
  }

  void _scrollToCurrentLine(int currentLineIndex) {
    if (currentLineIndex >= 0 &&
        currentLineIndex != _previousCurrentLine &&
        _scrollController.hasClients) {
      _previousCurrentLine = currentLineIndex;

      const itemHeight = 60.0;
      final targetOffset =
          (currentLineIndex * itemHeight) -
          (_scrollController.position.viewportDimension / 2) +
          (itemHeight / 2);

      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final currentTrack = snapshot.data;

        if (currentTrack == null) {
          return _buildEmptyState('No track playing');
        }

        final trackId = currentTrack.id;

        if (_cachedTrackId != trackId) {
          _cachedTrackId = trackId;
          _previousCurrentLine = -1;
          _cachedLyricsFuture = DesktopLyricsService.fetchLyrics(
            trackName: currentTrack.title,
            artistName: currentTrack.artist ?? 'Unknown Artist',
            albumName: currentTrack.album,
            durationSeconds: currentTrack.duration?.inSeconds,
          );
        }

        return FutureBuilder<DesktopLyrics?>(
          future: _cachedLyricsFuture,
          builder: (context, lyricsSnapshot) {
            if (lyricsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            final lyrics = lyricsSnapshot.data;
            if (lyrics == null) {
              return _buildEmptyState('Lyrics not found');
            }

            if (lyrics.isTimeSynced && lyrics.syncedLines.isNotEmpty) {
              return _buildSyncedLyrics(lyrics.syncedLines);
            }

            if (lyrics.plainText != null) {
              return _buildPlainLyrics(lyrics.plainText!);
            }

            return _buildEmptyState('No lyrics available');
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Loading lyrics...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyrics(String lyrics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Text(
        lyrics,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 20,
          height: 1.8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSyncedLyrics(List<DesktopLyricsLine> lines) {
    return StreamBuilder<Duration>(
      stream: widget.audioHandler?.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final currentLineIndex = _getCurrentLyricLineIndex(lines, position);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentLine(currentLineIndex);
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            final isCurrentLine = index == currentLineIndex;
            final isPastLine = index < currentLineIndex;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                line.text,
                style: TextStyle(
                  color: isCurrentLine
                      ? Colors.white
                      : isPastLine
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white.withOpacity(0.6),
                  fontSize: isCurrentLine ? 28 : 22,
                  fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }
}

class _NowPlayingTabs extends StatefulWidget {
  final dynamic audioHandler;

  const _NowPlayingTabs({required this.audioHandler});

  @override
  State<_NowPlayingTabs> createState() => _NowPlayingTabsState();
}

class _NowPlayingTabsState extends State<_NowPlayingTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  // Cache for lyrics to prevent constant reloading
  String? _cachedTrackId;
  Future<DesktopLyrics?>? _cachedLyricsFuture;

  @override
  void initState() {
    super.initState();
    // Always start with lyrics tab (index 0) as the default
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    // Listen to track changes and automatically switch to lyrics tab
    _mediaItemSubscription = widget.audioHandler?.mediaItem?.listen((
      mediaItem,
    ) {
      if (mediaItem != null && mounted && _tabController.index != 0) {
        // Switch to lyrics tab when a new track starts
        _tabController.animateTo(0);
      }
    });
  }

  @override
  void dispose() {
    _mediaItemSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.onPrimary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                Tab(
                  text: 'Lyrics',
                  icon: Stack(
                    children: [
                      const Icon(Icons.lyrics),
                      // Add a small indicator dot to show this is the primary tab
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  text: 'Queue',
                  icon: const Icon(Icons.queue_music),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLyricsTab(), _buildQueueTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsTab() {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final currentTrack = snapshot.data;

        if (currentTrack == null) {
          // Reset cache when no track is playing
          _cachedTrackId = null;
          _cachedLyricsFuture = null;
          return _buildLyricsEmptyState('No track playing');
        }

        // Use track ID as cache key (fallback to title if ID not available)
        final trackId = currentTrack.id;

        // Only fetch lyrics if the track has changed
        if (_cachedTrackId != trackId) {
          _cachedTrackId = trackId;
          _cachedLyricsFuture = DesktopLyricsService.fetchLyrics(
            trackName: currentTrack.title,
            artistName: currentTrack.artist ?? 'Unknown Artist',
            albumName: currentTrack.album,
            durationSeconds: currentTrack.duration?.inSeconds,
          );
        }

        return FutureBuilder<DesktopLyrics?>(
          future: _cachedLyricsFuture,
          builder: (context, lyricsSnapshot) {
            if (lyricsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLyricsLoadingState();
            }

            final lyrics = lyricsSnapshot.data;
            if (lyrics == null) {
              return _buildLyricsEmptyState('Lyrics not found');
            }

            // Show synced lyrics if available
            if (lyrics.isTimeSynced && lyrics.syncedLines.isNotEmpty) {
              return _buildSyncedLyricsView(lyrics.syncedLines);
            }

            // Fall back to plain lyrics
            if (lyrics.plainText != null) {
              return _buildPlainLyricsView(lyrics.plainText!);
            }

            return _buildLyricsEmptyState('No lyrics available');
          },
        );
      },
    );
  }

  Widget _buildLyricsLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading lyrics...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lyrics powered by LRCLib.net • Desktop Enhanced',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyricsView(String lyrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.lyrics,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Lyrics',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lyrics content
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                lyrics,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedLyricsView(List<DesktopLyricsLine> lyricsLines) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.lyrics,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Synced Lyrics',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIVE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Synced lyrics content
          Expanded(
            child: _SyncedLyricsContent(
              audioHandler: widget.audioHandler,
              lyricsLines: lyricsLines,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTab() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final queue = appState.queue;
        final audioHandler = appState.audioHandler;

        if (queue.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.queue_music,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No songs in queue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add songs to your queue to see them here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<MediaItem?>(
            stream: audioHandler?.mediaItem,
            builder: (context, mediaSnapshot) {
              final currentMediaItem = mediaSnapshot.data;

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final track = queue[index];
                  final isCurrentTrack = currentMediaItem?.id == track.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrentTrack
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentTrack
                          ? Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                            )
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: track.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  appState.getImageUrl(track.imageUrl!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.music_note,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 20,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.music_note,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                      ),
                      title: Text(
                        track.name,
                        style: TextStyle(
                          color: isCurrentTrack
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isCurrentTrack
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${track.artistName} • ${track.albumName}',
                        style: TextStyle(
                          color: isCurrentTrack
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrentTrack
                          ? Icon(
                              Icons.play_arrow,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        // Play the selected track
                        appState.skipToIndex(index);
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SyncedLyricsContent extends StatefulWidget {
  final dynamic audioHandler;
  final List<DesktopLyricsLine> lyricsLines;

  const _SyncedLyricsContent({
    required this.audioHandler,
    required this.lyricsLines,
  });

  @override
  State<_SyncedLyricsContent> createState() => _SyncedLyricsContentState();
}

class _SyncedLyricsContentState extends State<_SyncedLyricsContent> {
  final ScrollController _scrollController = ScrollController();
  int _previousCurrentLine = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getCurrentLyricLineIndex(
    List<DesktopLyricsLine> lines,
    Duration position,
  ) {
    if (lines.isEmpty) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        return i;
      }
    }

    return -1; // Before first line
  }

  void _scrollToCurrentLine(int currentLineIndex) {
    if (currentLineIndex >= 0 &&
        currentLineIndex != _previousCurrentLine &&
        _scrollController.hasClients) {
      _previousCurrentLine = currentLineIndex;

      // Calculate the position to scroll to (center the current line)
      const itemHeight = 56.0; // Approximate height of each lyrics line item
      final targetOffset =
          (currentLineIndex * itemHeight) -
          (_scrollController.position.viewportDimension / 2) +
          (itemHeight / 2);

      // Animate to the target position
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.audioHandler?.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final currentLineIndex = _getCurrentLyricLineIndex(
          widget.lyricsLines,
          position,
        );

        // Auto-scroll to current line
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentLine(currentLineIndex);
        });

        return ListView.builder(
          controller: _scrollController,
          itemCount: widget.lyricsLines.length,
          itemBuilder: (context, index) {
            final line = widget.lyricsLines[index];
            final isCurrentLine = index == currentLineIndex;
            final isPastLine = index < currentLineIndex;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentLine
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : null,
                borderRadius: BorderRadius.circular(8),
                border: isCurrentLine
                    ? Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                      )
                    : null,
              ),
              child: Text(
                line.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isCurrentLine
                      ? Theme.of(context).colorScheme.primary
                      : isPastLine
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.6)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isCurrentLine
                      ? FontWeight.w600
                      : FontWeight.normal,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }
}

class AnimatedDialog extends StatefulWidget {
  final Widget child;

  const AnimatedDialog({super.key, required this.child});

  @override
  State<AnimatedDialog> createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<AnimatedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> closeDialog() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await closeDialog();
        return false;
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

class _AddToPlaylistDialog extends StatefulWidget {
  final Track track;
  final List<Playlist> playlists;
  final Function(String playlistId) onAddToPlaylist;

  const _AddToPlaylistDialog({
    required this.track,
    required this.playlists,
    required this.onAddToPlaylist,
  });

  @override
  State<_AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<_AddToPlaylistDialog> {
  String? _selectedPlaylistId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.playlist_add),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Add to Playlist', style: theme.textTheme.titleLarge),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Track info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.track.artistName} • ${widget.track.albumName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Playlist selection
            Text('Select Playlist:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),

            if (widget.playlists.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_remove,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No playlists available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = widget.playlists[index];
                    final isSelected = _selectedPlaylistId == playlist.id;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.trackCount} tracks'),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(
                        0.1,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPlaylistId = playlist.id;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _isLoading ||
                  _selectedPlaylistId == null ||
                  widget.playlists.isEmpty
              ? null
              : () async {
                  setState(() {
                    _isLoading = true;
                  });

                  await widget.onAddToPlaylist(_selectedPlaylistId!);

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add to Playlist'),
        ),
      ],
    );
  }
}
