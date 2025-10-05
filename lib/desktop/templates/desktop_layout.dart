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
            final isPlaying = playbackState?.playing ?? false;
            
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
                          height: 96,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border(
                              top: BorderSide(
                                color: theme.colorScheme.outline.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Progress bar with seeking
                              SizedBox(
                                height: 20,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
                              
                              // Main player content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      // Album art
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceVariant,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: currentTrack?.artUri != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  currentTrack!.artUri.toString(),
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.music_note,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      size: 28,
                                                    );
                                                  },
                                                ),
                                              )
                                            : Icon(
                                                Icons.music_note,
                                                color: theme.colorScheme.onSurfaceVariant,
                                                size: 28,
                                              ),
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Track info with time
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: currentTrack != null ? () {
                                                // Navigate to now playing screen
                                                _showNowPlayingDialog(context);
                                              } : null,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    currentTrack?.title ?? 'No track playing',
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        currentTrack?.artist ?? 'Select a song to play',
                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                          color: theme.colorScheme.onSurfaceVariant,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (currentTrack != null) ...[
                                                        Text(
                                                          ' • ',
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            fontFamily: 'monospace',
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Player controls
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: audioHandler != null && audioHandler.hasPrevious
                                                ? () => appState.skipToPrevious()
                                                : null,
                                            icon: const Icon(Icons.skip_previous),
                                            iconSize: 28,
                                          ),
                                          IconButton(
                                            onPressed: audioHandler != null && currentTrack != null
                                                ? () => appState.playPause()
                                                : null,
                                            icon: Icon(
                                              isPlaying ? Icons.pause : Icons.play_arrow,
                                            ),
                                            iconSize: 32,
                                            style: IconButton.styleFrom(
                                              backgroundColor: theme.colorScheme.primary,
                                              foregroundColor: theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: audioHandler != null && audioHandler.hasNext
                                                ? () => appState.skipToNext()
                                                : null,
                                            icon: const Icon(Icons.skip_next),
                                            iconSize: 28,
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Volume and additional controls
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: currentTrack != null ? () {
                                              // Toggle favorite
                                            } : null,
                                            icon: const Icon(Icons.favorite_border),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              // Show volume slider
                                              _showVolumeDialog(context);
                                            },
                                            icon: const Icon(Icons.volume_up),
                                          ),
                                          IconButton(
                                            onPressed: currentTrack != null ? () {
                                              _showNowPlayingDialog(context);
                                            } : null,
                                            icon: const Icon(Icons.fullscreen),
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
          
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
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
                    child: StreamBuilder<MediaItem?>(
                      stream: audioHandler?.mediaItem,
                      builder: (context, mediaSnapshot) {
                        final currentTrack = mediaSnapshot.data;
                        
                        return Row(
                          children: [
                            // Left side - Album art
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Album art
                                    Container(
                                      width: 280,
                                      height: 280,
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
                                                width: 280,
                                                height: 280,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.music_note,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    size: 80,
                                                  );
                                                },
                                              ),
                                            )
                                          : Icon(
                                              Icons.music_note,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              size: 80,
                                            ),
                                    ),
                                    
                                    const SizedBox(height: 24),
                                    
                                    // Track info
                                    Text(
                                      currentTrack?.title ?? 'No track playing',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
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
                                      const SizedBox(height: 4),
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
                                  ],
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
      ),
    );
  }

  Widget _buildNowPlayingControls(BuildContext context, dynamic audioHandler) {
    final theme = Theme.of(context);
    
    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, playbackSnapshot) {
        final playbackState = playbackSnapshot.data;
        final isPlaying = playbackState?.playing ?? false;
        
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
      builder: (context) => AlertDialog(
        title: const Text('Volume'),
        content: const Text('Volume control coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
              tabs: const [
                Tab(
                  text: 'Lyrics',
                  icon: Icon(Icons.lyrics),
                ),
                Tab(
                  text: 'Queue',
                  icon: Icon(Icons.queue_music),
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
          return _buildLyricsEmptyState('No track playing');
        }
        
        return FutureBuilder<DesktopLyrics?>(
          future: DesktopLyricsService.fetchLyrics(
            trackName: currentTrack.title,
            artistName: currentTrack.artist ?? 'Unknown Artist',
            albumName: currentTrack.album,
            durationSeconds: currentTrack.duration?.inSeconds,
          ),
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
            'Lyrics powered by LRCLib.net',
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
            child: StreamBuilder<Duration>(
              stream: widget.audioHandler?.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                final currentLineIndex = _getCurrentLyricLineIndex(lyricsLines, position);
                
                return ListView.builder(
                  itemCount: lyricsLines.length,
                  itemBuilder: (context, index) {
                    final line = lyricsLines[index];
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
            ),
          ),
        ],
      ),
    );
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