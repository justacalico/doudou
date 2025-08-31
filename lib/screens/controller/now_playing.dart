import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/app_state.dart';
import '../../widgets/music_visualizer.dart';
import '../../widgets/lyrics_overlay.dart';
import '../queue/queue.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000), // Pure black for OLED
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          final audioHandler = appState.audioHandler;
          final currentTrack = audioHandler?.currentTrack;
          
          if (currentTrack == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.music_note, size: 64, color: CupertinoColors.systemGrey),
                  SizedBox(height: 16),
                  Text(
                    'No music playing',
                    style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top bar with chevron down and cast icon
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(context),
                              child: const Icon(
                                CupertinoIcons.chevron_down,
                                color: Color(0xFFFFFFFF),
                                size: 28,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {}, // Cast functionality placeholder
                              child: const Icon(
                                CupertinoIcons.antenna_radiowaves_left_right,
                                color: Color(0xFFFFFFFF),
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Album Art - responsive size (clickable)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => MusicVisualizerScreen(
                                trackName: currentTrack.name,
                                artistName: currentTrack.artistName,
                                imageUrl: currentTrack.imageUrl,
                                isPlaying: audioHandler?.isPlaying ?? false,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.75,
                          height: MediaQuery.of(context).size.width * 0.75,
                          constraints: const BoxConstraints(
                            maxWidth: 320,
                            maxHeight: 320,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF000000).withOpacity(0.8),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: currentTrack.imageUrl != null
                                ? Image.network(
                                    appState.jellyfinService.getImageUrl(
                                      currentTrack.imageUrl!,
                                      width: 800,
                                      height: 800,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF1C1C1E),
                                        child: const Icon(CupertinoIcons.music_albums, size: 80, color: CupertinoColors.systemGrey2),
                                      );
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFF1C1C1E),
                                    child: const Icon(CupertinoIcons.music_albums, size: 80, color: CupertinoColors.systemGrey2),
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Track info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          children: [
                            Text(
                              currentTrack.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFFFFF),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            if (currentTrack.artistName != null)
                              Text(
                                currentTrack.artistName!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: CupertinoColors.systemGrey2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Progress slider
                      StreamBuilder<Duration>(
                        stream: audioHandler?.positionStream ?? Stream.value(Duration.zero),
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = audioHandler?.duration ?? Duration.zero;
                          
                          // Calculate slider value with bounds checking
                          double sliderValue = 0.0;
                          if (duration.inMilliseconds > 0) {
                            sliderValue = position.inMilliseconds / duration.inMilliseconds;
                            // Ensure the value is within valid bounds (0.0 to 1.0)
                            sliderValue = sliderValue.clamp(0.0, 1.0);
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Column(
                              children: [
                                CupertinoSlider(
                                  value: sliderValue,
                                  onChanged: (value) {
                                    final newPosition = Duration(
                                      milliseconds: (value * duration.inMilliseconds).round(),
                                    );
                                    appState.seekTo(newPosition);
                                  },
                                  activeColor: const Color(0xFFFFFFFF),
                                  thumbColor: const Color(0xFFFFFFFF),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(color: CupertinoColors.systemGrey2, fontSize: 14),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(color: CupertinoColors.systemGrey2, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Control buttons
                      StreamBuilder(
                        stream: audioHandler?.playerStateStream,
                        builder: (context, snapshot) {
                          final isPlaying = audioHandler?.isPlaying ?? false;
                          final processingState = audioHandler?.playerState.processingState;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    final audioHandler = appState.audioHandler;
                                    if (audioHandler?.isShuffled == true) {
                                      audioHandler?.unshuffle();
                                    } else {
                                      audioHandler?.shuffle();
                                    }
                                  },
                                  child: Icon(
                                    CupertinoIcons.shuffle,
                                    color: audioHandler?.isShuffled == true 
                                        ? const Color(0xFFFF453A)
                                        : CupertinoColors.systemGrey2,
                                    size: 28,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: audioHandler?.hasPrevious == true
                                      ? () => appState.skipToPrevious()
                                      : null,
                                  child: Icon(
                                    CupertinoIcons.backward_fill,
                                    size: 40,
                                    color: audioHandler?.hasPrevious == true 
                                        ? const Color(0xFFFFFFFF)
                                        : CupertinoColors.systemGrey2,
                                  ),
                                ),
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFFFFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: processingState == ProcessingState.loading ||
                                          processingState == ProcessingState.buffering
                                      ? const Center(
                                          child: CupertinoActivityIndicator(
                                            color: Color(0xFF000000),
                                          ),
                                        )
                                      : CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            appState.playPause();
                                          },
                                          child: Icon(
                                            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                                            size: 35,
                                            color: const Color(0xFF000000),
                                          ),
                                        ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: audioHandler?.hasNext == true
                                      ? () => appState.skipToNext()
                                      : null,
                                  child: Icon(
                                    CupertinoIcons.forward_fill,
                                    size: 40,
                                    color: audioHandler?.hasNext == true 
                                        ? const Color(0xFFFFFFFF)
                                        : CupertinoColors.systemGrey2,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {}, // Repeat placeholder
                                  child: const Icon(
                                    CupertinoIcons.repeat,
                                    color: CupertinoColors.systemGrey2,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Bottom controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => const QueueScreen(),
                                  ),
                                );
                              },
                              child: const Icon(
                                CupertinoIcons.list_bullet,
                                color: Color(0xFFFFFFFF),
                                size: 24,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _showLyricsOverlay(context, currentTrack);
                              },
                              child: const Icon(
                                CupertinoIcons.text_quote,
                                color: Color(0xFFFFFFFF),
                                size: 24,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                appState.toggleFavorite(currentTrack);
                              },
                              child: Icon(
                                currentTrack.isFavorite 
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                color: currentTrack.isFavorite 
                                    ? const Color(0xFFFF453A)
                                    : CupertinoColors.systemRed,
                                size: 24,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _showMoreOptions(context, currentTrack, appState),
                              child: const Icon(
                                CupertinoIcons.ellipsis,
                                color: Color(0xFFFFFFFF),
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLyricsOverlay(BuildContext context, dynamic currentTrack) {
    showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => _LyricsOverlay(
        trackName: currentTrack.name,
        artistName: currentTrack.artistName ?? 'Unknown Artist',
      ),
    );
  }

  void _showMoreOptions(BuildContext context, dynamic currentTrack, AppState appState) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          currentTrack.name,
          style: const TextStyle(fontSize: 16),
        ),
        message: Text(
          currentTrack.artistName ?? 'Unknown Artist',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, currentTrack, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Add to Playlist'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, dynamic currentTrack, AppState appState) {
    final playlists = appState.playlists;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add to Playlist'),
        message: Text('Select a playlist to add "${currentTrack.name}" to:'),
        actions: [
          // Show existing playlists
          ...playlists.map((playlist) => CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _addToExistingPlaylist(context, playlist, currentTrack, appState);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_note_list, color: CupertinoColors.activeBlue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    playlist.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          // Create new playlist option
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _createNewPlaylist(context, currentTrack, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Create New Playlist'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _addToExistingPlaylist(BuildContext context, dynamic playlist, dynamic currentTrack, AppState appState) async {
    try {
      final success = await appState.addToPlaylist(playlist.id, currentTrack.id);
      
      if (context.mounted) {
        if (success) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Success'),
              content: Text('Added "${currentTrack.name}" to "${playlist.name}".'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text('Failed to add "${currentTrack.name}" to "${playlist.name}".'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: ${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _createNewPlaylist(BuildContext context, dynamic currentTrack, AppState appState) {
    final TextEditingController controller = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your new playlist:'),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Playlist name',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _addToNewPlaylist(context, controller.text.trim(), currentTrack, appState);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _addToNewPlaylist(BuildContext context, String playlistName, dynamic currentTrack, AppState appState) async {
    try {
      // Create the playlist
      final success = await appState.createPlaylist(playlistName);
      
      if (success && context.mounted) {
        // Find the newly created playlist
        final newPlaylist = appState.playlists.firstWhere(
          (p) => p.name == playlistName,
          orElse: () => throw Exception('Playlist not found after creation'),
        );
        
        // Add the song to the new playlist
        final addSuccess = await appState.addToPlaylist(newPlaylist.id, currentTrack.id);
        
        if (context.mounted) {
          if (addSuccess) {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Success'),
                content: Text('Created playlist "$playlistName" and added "${currentTrack.name}" to it.'),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Partial Success'),
                content: Text('Created playlist "$playlistName" but failed to add the song. You can add it manually from the playlists screen.'),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } else if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create playlist "$playlistName".'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: ${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

class _LyricsOverlay extends StatefulWidget {
  final String trackName;
  final String artistName;

  const _LyricsOverlay({
    required this.trackName,
    required this.artistName,
  });

  @override
  State<_LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends State<_LyricsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _lyrics = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    _loadLyrics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    // Simulate loading lyrics - in a real app, you'd fetch from an API
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _lyrics = 'Lyrics for "${widget.trackName}" by ${widget.artistName}\n\n'
          'Lyrics are not available for this track.\n\n'
          'This is a placeholder where song lyrics would appear.\n\n'
          'In a production app, you would integrate with a lyrics API service '
          'to fetch and display the actual song lyrics here.';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lyrics',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${widget.trackName} • ${widget.artistName}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _animationController.reverse().then((_) {
                                      Navigator.of(context).pop();
                                    });
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.xmark,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Lyrics content
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CupertinoActivityIndicator(
                                          color: Colors.white,
                                          radius: 16,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Loading lyrics...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      _lyrics,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.6,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
