import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:math';
import 'dart:async';
import '../../providers/app_state.dart';
import '../../widgets/music_visualizer.dart';
import '../../widgets/synced_lyrics_overlay.dart';
import '../../widgets/queue_overlay.dart';
import '../../widgets/cached_image_widget.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> with TickerProviderStateMixin {
  late AnimationController _favoriteAnimationController;
  late Animation<double> _favoriteScaleAnimation;
  bool _showVisualizer = false; // Toggle between album art and visualizer
  
  @override
  void initState() {
    super.initState();
    _favoriteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _favoriteScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _favoriteAnimationController,
      curve: Curves.elasticOut,
    ));
  }
  
  @override
  void dispose() {
    _favoriteAnimationController.dispose();
    super.dispose();
  }
  
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
                      
                      // Album Art / Visualizer - responsive size (clickable to toggle)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showVisualizer = !_showVisualizer;
                          });
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
                          child: _showVisualizer
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: EmbeddedVisualizer(
                                    trackName: currentTrack.name,
                                    artistName: currentTrack.artistName,
                                    isPlaying: audioHandler?.isPlaying ?? false,
                                  ),
                                )
                              : AlbumArtWidget(
                                  imageUrl: currentTrack.imageUrl != null
                                      ? appState.jellyfinService.getImageUrl(
                                          currentTrack.imageUrl!,
                                          width: 800,
                                          height: 800,
                                        )
                                      : null,
                                  size: MediaQuery.of(context).size.width * 0.75,
                                  borderRadius: BorderRadius.circular(20),
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
                                  onPressed: () async {
                                    final audioHandler = appState.audioHandler;
                                    if (audioHandler != null) {
                                      // Get current repeat mode
                                      final currentState = audioHandler.playbackState.value;
                                      final currentMode = currentState.repeatMode;
                                      
                                      // Cycle through repeat modes: none -> all -> one -> none
                                      switch (currentMode) {
                                        case AudioServiceRepeatMode.none:
                                          await audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                                          break;
                                        case AudioServiceRepeatMode.all:
                                          await audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
                                          break;
                                        case AudioServiceRepeatMode.one:
                                          await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                                          break;
                                        case AudioServiceRepeatMode.group:
                                          await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                                          break;
                                      }
                                    }
                                  },
                                  child: StreamBuilder<AudioServiceRepeatMode>(
                                    stream: audioHandler?.playbackState.map((state) => state.repeatMode),
                                    builder: (context, snapshot) {
                                      final repeatMode = snapshot.data ?? AudioServiceRepeatMode.none;
                                      
                                      return Icon(
                                        repeatMode == AudioServiceRepeatMode.one 
                                            ? CupertinoIcons.repeat_1
                                            : CupertinoIcons.repeat,
                                        color: repeatMode == AudioServiceRepeatMode.none
                                            ? CupertinoColors.systemGrey2
                                            : const Color(0xFFFF453A),
                                        size: 28,
                                      );
                                    },
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
                                showQueueOverlay(context);
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
                              onPressed: () async {
                                // Trigger animation
                                await _favoriteAnimationController.forward();
                                await _favoriteAnimationController.reverse();
                                
                                // Toggle favorite state
                                appState.toggleFavorite(currentTrack);
                              },
                              child: AnimatedBuilder(
                                animation: _favoriteScaleAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _favoriteScaleAnimation.value,
                                    child: Icon(
                                      currentTrack.isFavorite 
                                          ? CupertinoIcons.heart_fill
                                          : CupertinoIcons.heart,
                                      color: currentTrack.isFavorite 
                                          ? const Color(0xFFFF453A)
                                          : CupertinoColors.systemRed,
                                      size: 24,
                                    ),
                                  );
                                },
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
    showSyncedLyricsOverlay(
      context,
      currentTrack.name,
      currentTrack.artistName ?? 'Unknown Artist',
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

// Embedded visualizer widget for the now playing screen
class EmbeddedVisualizer extends StatefulWidget {
  final String trackName;
  final String? artistName;
  final bool isPlaying;

  const EmbeddedVisualizer({
    super.key,
    required this.trackName,
    this.artistName,
    required this.isPlaying,
  });

  @override
  State<EmbeddedVisualizer> createState() => _EmbeddedVisualizerState();
}

class _EmbeddedVisualizerState extends State<EmbeddedVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Timer _timer;
  List<double> _barHeights = [];
  final int _barCount = 48; // Slightly fewer for smaller space
  final Random _random = Random();
  
  // Color extraction from song info
  List<Color> _extractedColors = [
    const Color(0xFF007AFF), // Default blue
    const Color(0xFF00FF88), // Default green
    const Color(0xFFFF453A), // Default red
    const Color(0xFFFF9F0A), // Default orange
    const Color(0xFFBF5AF2), // Default purple
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize bar heights
    _barHeights = List.generate(_barCount, (index) => 0.1);
    
    // Create animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    // Extract colors from song info
    _extractColorsFromSong();

    // Start the visualizer animation
    _startVisualizerAnimation();
  }

  void _extractColorsFromSong() {
    // Generate colors based on the track name and artist
    final String colorSeed = '${widget.trackName}${widget.artistName ?? ''}';
    final Random colorRandom = Random(colorSeed.hashCode);
    
    // Generate a color palette based on the song
    final baseHue = colorRandom.nextDouble() * 360;
    _extractedColors = [
      HSVColor.fromAHSV(1.0, baseHue, 0.8, 0.9).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 60) % 360, 0.7, 0.8).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 120) % 360, 0.9, 0.7).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 180) % 360, 0.6, 0.9).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 240) % 360, 0.8, 0.8).toColor(),
    ];
    
    if (mounted) {
      setState(() {});
    }
  }

  void _startVisualizerAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (widget.isPlaying && mounted) {
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            // Create wave-like motion for smoother animation
            double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
            double waveOffset = sin(time * 2 + i * 0.2) * 0.3;
            
            // Base intensity with wave motion
            double baseIntensity = 0.4 + _random.nextDouble() * 0.5 + waveOffset;
            
            // Make opposite sides mirror each other for symmetry
            double symmetryFactor = sin((i / _barCount) * 2 * pi) * 0.2;
            
            // Add bass-like emphasis to certain positions
            double bassBoost = sin((i / _barCount) * 4 * pi) * 0.3;
            
            _barHeights[i] = (baseIntensity + symmetryFactor + bassBoost).clamp(0.15, 1.0);
          }
        });
      } else if (mounted) {
        // Gradually reduce bar heights when not playing
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            _barHeights[i] = (_barHeights[i] * 0.92).clamp(0.1, 1.0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000), // Pure black background
      ),
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _extractedColors[0].withOpacity(0.1),
                  const Color(0xFF000000),
                  const Color(0xFF000000),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
          
          // Visualizer
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: EmbeddedVisualizerPainter(
                  barHeights: _barHeights,
                  isPlaying: widget.isPlaying,
                  colors: _extractedColors,
                ),
              ),
            ),
          ),
          
          // Center overlay with song info
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60), // Push content down a bit
                Icon(
                  widget.isPlaying 
                      ? CupertinoIcons.music_note_2
                      : CupertinoIcons.pause_fill,
                  color: _extractedColors[0],
                  size: 32,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _extractedColors[0].withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.isPlaying ? 'Now Playing' : 'Paused',
                    style: TextStyle(
                      color: _extractedColors[0],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tap indicator
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Tap to show album art',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey2.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the embedded visualizer
class EmbeddedVisualizerPainter extends CustomPainter {
  final List<double> barHeights;
  final bool isPlaying;
  final List<Color> colors;

  EmbeddedVisualizerPainter({
    required this.barHeights,
    required this.isPlaying,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final innerRadius = radius * 0.3;
    final barCount = barHeights.length;

    // Draw background glow effect
    if (isPlaying) {
      final glowPaint = Paint()
        ..color = colors[0].withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius + 10, glowPaint);
    }

    // Draw inner black circle for contrast
    final innerCirclePaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerCirclePaint);

    // Draw subtle inner ring
    final innerRingPaint = Paint()
      ..color = isPlaying 
          ? colors[1].withOpacity(0.4)
          : const Color(0xFF8E8E93).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, innerRadius, innerRingPaint);

    // Draw animated bars extending outward
    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi - pi / 2;
      final intensity = barHeights[i];
      final barLength = intensity * 30; // Shorter bars for smaller space
      
      // Calculate positions
      final startRadius = innerRadius + 8;
      final endRadius = startRadius + barLength;
      
      final startX = center.dx + cos(angle) * startRadius;
      final startY = center.dy + sin(angle) * startRadius;
      final endX = center.dx + cos(angle) * endRadius;
      final endY = center.dy + sin(angle) * endRadius;

      // Create dynamic color based on position and extracted colors
      final colorIndex = i % colors.length;
      final baseColor = colors[colorIndex];
      final hsvColor = HSVColor.fromColor(baseColor);
      
      final saturation = isPlaying ? 0.9 : 0.3;
      final brightness = isPlaying ? 0.6 + intensity * 0.4 : 0.3 + intensity * 0.2;
      
      final barColor = HSVColor.fromAHSV(
        1.0, 
        hsvColor.hue, 
        saturation, 
        brightness
      ).toColor();

      // Add glow effect for playing state
      if (isPlaying && intensity > 0.5) {
        final glowPaint = Paint()
          ..color = barColor.withOpacity(0.4)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
      }

      // Draw the main bar
      final barPaint = Paint()
        ..color = barColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), barPaint);
    }

    // Draw center indicator
    if (isPlaying) {
      // Animated center point with glow using extracted colors
      final centerGlowPaint = Paint()
        ..color = colors[0].withOpacity(0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, 6, centerGlowPaint);
      
      final centerPaint = Paint()
        ..color = colors[0]
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 3, centerPaint);
    } else {
      // Simple center point when paused
      final centerPaint = Paint()
        ..color = const Color(0xFF8E8E93).withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 2, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
