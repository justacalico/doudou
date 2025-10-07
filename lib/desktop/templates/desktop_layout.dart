import 'dart:async';
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
  static Future<void> showAddToPlaylistDialog(BuildContext context, Track track) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Consumer<AppState>(
          builder: (context, appState, child) {
            return _AddToPlaylistDialog(
              track: track,
              playlists: appState.playlists,
              onAddToPlaylist: (playlistId) async {
                try {
                  final success = await appState.jellyfinService.addToPlaylist(playlistId, track.id);
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added "${track.name}" to playlist')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to add track to playlist')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
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
    if (widget.selectedIndex != null && widget.selectedIndex != _selectedIndex) {
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
                            final currentSelectedIndex = widget.selectedIndex ?? _selectedIndex;
                            final isSelected = index == currentSelectedIndex;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: ListTile(
                                selected: isSelected,
                                selectedTileColor: theme.colorScheme.primaryContainer,
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
                                  if (widget.child != null && widget.showBackButton) {
                                    // If we're on a detail page, navigate back to main app
                                    Navigator.popUntil(context, (route) => route.isFirst);
                                    // Update the navigation service to show correct page
                                    _navigationService.navigateToMainPage(index);
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
            final playbackState = playbackSnapshot.data;
            // More robust playing state detection
            final isPlaying = playbackState?.playing == true && 
                              (playbackState?.processingState == AudioProcessingState.ready ||
                               playbackState?.processingState == AudioProcessingState.buffering);
            final isBuffering = playbackState?.processingState == AudioProcessingState.buffering;
            
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
                                color: theme.colorScheme.shadow.withOpacity(0.1),
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
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: theme.colorScheme.outline.withOpacity(0.1),
                                  ),
                                  child: Slider(
                                    value: progress.clamp(0.0, 1.0),
                                    onChanged: currentTrack != null && audioHandler != null ? (value) {
                                      final newPosition = Duration(
                                        milliseconds: (value * duration.inMilliseconds).round(),
                                      );
                                      audioHandler.seek(newPosition);
                                    } : null,
                                    min: 0.0,
                                    max: 1.0,
                                  ),
                                ),
                              ),
                              
                              // Main player content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                                  child: Row(
                                    children: [
                                      // Album art with hover effect
                                      GestureDetector(
                                        onTap: currentTrack != null ? () => _showNowPlayingDialog(context) : null,
                                        child: Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surfaceVariant,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.shadow.withOpacity(0.1),
                                                offset: const Offset(0, 2),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: currentTrack?.artUri != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    currentTrack!.artUri.toString(),
                                                    width: 64,
                                                    height: 64,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Icon(
                                                        Icons.music_note_rounded,
                                                        color: theme.colorScheme.onSurfaceVariant,
                                                        size: 32,
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.music_note_rounded,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                  size: 32,
                                                ),
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 20),
                                      
                                      // Track info - improved layout
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: currentTrack != null ? () => _showNowPlayingDialog(context) : null,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                currentTrack?.title ?? 'No track playing',
                                                style: theme.textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      currentTrack?.artist ?? 'Select a song to play',
                                                      style: theme.textTheme.bodyMedium?.copyWith(
                                                        color: theme.colorScheme.onSurfaceVariant,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (currentTrack != null) ...[
                                                    Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                                      width: 4,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Consumer<AppState>(
                                                      builder: (context, appState, child) {
                                                        final timeText = '${_formatDuration(position)} / ${_formatDuration(duration)}';
                                                        
                                                        return Text(
                                                          timeText,
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            fontFamily: 'monospace',
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
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: audioHandler != null && audioHandler.hasPrevious
                                                  ? () => appState.skipToPrevious()
                                                  : null,
                                              icon: const Icon(Icons.skip_previous_rounded),
                                              iconSize: 24,
                                              style: IconButton.styleFrom(
                                                foregroundColor: theme.colorScheme.onSurfaceVariant,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary,
                                                borderRadius: BorderRadius.circular(24),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                                    offset: const Offset(0, 4),
                                                    blurRadius: 12,
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: IconButton(
                                                onPressed: audioHandler != null && currentTrack != null
                                                    ? () => appState.playPause()
                                                    : null,
                                                icon: Icon(
                                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                  size: 28,
                                                ),
                                                style: IconButton.styleFrom(
                                                  foregroundColor: theme.colorScheme.onPrimary,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(24),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed: audioHandler != null && audioHandler.hasNext
                                                  ? () => appState.skipToNext()
                                                  : null,
                                              icon: const Icon(Icons.skip_next_rounded),
                                              iconSize: 24,
                                              style: IconButton.styleFrom(
                                                foregroundColor: theme.colorScheme.onSurfaceVariant,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
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
                                          StreamBuilder<double>(
                                            stream: audioHandler?.volumeStream,
                                            builder: (context, volumeSnapshot) {
                                              final currentVolume = volumeSnapshot.data ?? 1.0;
                                              
                                              return IconButton(
                                                onPressed: () => _showVolumeDialog(context),
                                                onLongPress: audioHandler != null ? () => audioHandler.toggleMute() : null,
                                                icon: Icon(
                                                  currentVolume == 0.0
                                                    ? Icons.volume_off_rounded
                                                    : currentVolume < 0.5
                                                      ? Icons.volume_down_rounded
                                                      : Icons.volume_up_rounded,
                                                  size: 20,
                                                ),
                                                style: IconButton.styleFrom(
                                                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                tooltip: 'Volume ${(currentVolume * 100).round()}%',
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: currentTrack != null ? () => _showNowPlayingDialog(context) : null,
                                            icon: const Icon(Icons.open_in_full_rounded, size: 20),
                                            style: IconButton.styleFrom(
                                              foregroundColor: theme.colorScheme.onSurfaceVariant,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Consumer<AppState>(
        builder: (context, appState, child) {
          final audioHandler = appState.audioHandler;
          
          return StreamBuilder<MediaItem?>(
            stream: audioHandler?.mediaItem,
            builder: (context, mediaItemSnapshot) {
              return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.85,
              constraints: const BoxConstraints(
                minWidth: 700,
                minHeight: 500,
                maxWidth: 1200,
                maxHeight: 900,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Header with close button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Now Playing',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  
                  // Main content area
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final currentTrack = mediaItemSnapshot.data;
                        
                        return Row(
                          children: [
                            // Left side - Album art
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Album art
                                        Flexible(
                                          flex: 3,
                                          child: LayoutBuilder(
                                            builder: (context, artConstraints) {
                                              final availableHeight = artConstraints.maxHeight;
                                              final availableWidth = artConstraints.maxWidth;
                                              final maxSize = availableHeight * 0.9;
                                              final size = (availableWidth * 0.8).clamp(120.0, maxSize.clamp(150.0, 250.0));
                                          return Container(
                                            width: size,
                                            height: size,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceVariant,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 20,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: currentTrack?.artUri != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: Image.network(
                                                    currentTrack!.artUri.toString(),
                                                    width: size,
                                                    height: size,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Icon(
                                                        Icons.music_note,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        size: size * 0.3,
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.music_note,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  size: size * 0.3,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Track info
                                        Flexible(
                                          flex: 1,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                          Text(
                                            currentTrack?.title ?? 'No track playing',
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          
                                          const SizedBox(height: 4),
                                          
                                          Text(
                                            currentTrack?.artist ?? 'Unknown Artist',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          
                                          if (currentTrack?.album != null) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              currentTrack!.album!,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          
                                          // Show play count if available
                                          Consumer<AppState>(
                                            builder: (context, appState, child) {
                                              final track = appState.findTrackById(currentTrack?.id);
                                              final playCount = track?.playCount;
                                              
                                              if (playCount != null && playCount > 0) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    '$playCount plays',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Right side - Tabs (Lyrics & Queue)
                            Expanded(
                              flex: 1,
                              child: _NowPlayingTabs(audioHandler: audioHandler),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  // Bottom player controls
                  _buildNowPlayingControls(context, audioHandler),
                ],
              ),
            ),
            );
          },
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
        final playbackState = playbackSnapshot.data;
        // More robust playing state detection
        final isPlaying = playbackState?.playing == true && 
                          (playbackState?.processingState == AudioProcessingState.ready ||
                           playbackState?.processingState == AudioProcessingState.buffering);
        
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Progress bar with time labels
                          Row(
                            children: [
                              Text(
                                _formatDuration(position),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                      activeTrackColor: theme.colorScheme.primary,
                                      inactiveTrackColor: theme.colorScheme.outline.withOpacity(0.2),
                                      thumbColor: theme.colorScheme.primary,
                                      overlayColor: theme.colorScheme.primary.withOpacity(0.2),
                                    ),
                                    child: Slider(
                                      value: progress.clamp(0.0, 1.0),
                                      onChanged: currentTrack != null && audioHandler != null ? (value) {
                                        final newPosition = Duration(
                                          milliseconds: (value * duration.inMilliseconds).round(),
                                        );
                                        audioHandler.seek(newPosition);
                                      } : null,
                                      min: 0.0,
                                      max: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Player controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: audioHandler != null && audioHandler.hasPrevious
                                    ? () => Provider.of<AppState>(context, listen: false).skipToPrevious()
                                    : null,
                                icon: const Icon(Icons.skip_previous),
                                iconSize: 36,
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: audioHandler != null && currentTrack != null
                                    ? () => Provider.of<AppState>(context, listen: false).playPause()
                                    : null,
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                ),
                                iconSize: 48,
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: audioHandler != null && audioHandler.hasNext
                                    ? () => Provider.of<AppState>(context, listen: false).skipToNext()
                                    : null,
                                icon: const Icon(Icons.skip_next),
                                iconSize: 36,
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
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                                      activeTrackColor: Theme.of(context).colorScheme.primary,
                                      inactiveTrackColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                      thumbColor: Theme.of(context).colorScheme.primary,
                                      overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No audio handler available',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _NowPlayingTabs extends StatefulWidget {
  final dynamic audioHandler;
  
  const _NowPlayingTabs({required this.audioHandler});
  
  @override
  State<_NowPlayingTabs> createState() => _NowPlayingTabsState();
}

class _NowPlayingTabsState extends State<_NowPlayingTabs> with SingleTickerProviderStateMixin {
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
    _mediaItemSubscription = widget.audioHandler?.mediaItem?.listen((mediaItem) {
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
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
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
              children: [
                _buildLyricsTab(),
                _buildQueueTab(),
              ],
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
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
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.queue_music,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
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
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentTrack 
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                                  track.imageUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.music_note,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      size: 20,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                      ),
                      title: Text(
                        track.name,
                        style: TextStyle(
                          color: isCurrentTrack 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isCurrentTrack ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${track.artistName} • ${track.albumName}',
                        style: TextStyle(
                          color: isCurrentTrack 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
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

  int _getCurrentLyricLineIndex(List<DesktopLyricsLine> lines, Duration position) {
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
      final targetOffset = (currentLineIndex * itemHeight) - 
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
        final currentLineIndex = _getCurrentLyricLineIndex(widget.lyricsLines, position);
        
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    )
                  : null,
              ),
              child: Text(
                line.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isCurrentLine
                    ? Theme.of(context).colorScheme.primary
                    : isPastLine
                      ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isCurrentLine ? FontWeight.w600 : FontWeight.normal,
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
            child: Text(
              'Add to Playlist',
              style: theme.textTheme.titleLarge,
            ),
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
            Text(
              'Select Playlist:',
              style: theme.textTheme.titleSmall,
            ),
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
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
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
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.trackCount} tracks'),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
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
          onPressed: _isLoading || _selectedPlaylistId == null || widget.playlists.isEmpty
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