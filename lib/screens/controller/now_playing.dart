import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
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
                          child: AlbumArtWidget(
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
