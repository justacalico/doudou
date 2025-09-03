import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import 'lyrics/lyrics_overlay.dart';
import 'queue/queue_overlay.dart';
import '../../widgets/cached_image_widget.dart';
import 'visualizer/visualizer.dart';
import '../albums/details/album_details.dart';
import '../artists/details/artist_detail.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> with TickerProviderStateMixin {
  late AnimationController _favoriteAnimationController;
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
            child: Column(
              children: [
                // Top bar with chevron down and cast icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            CupertinoIcons.chevron_down,
                            color: Color(0xFFFFFFFF),
                            size: 20,
                          ),
                        ),
                      ),
                      // Now Playing indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Now Playing',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {}, // Cast functionality placeholder
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            CupertinoIcons.antenna_radiowaves_left_right,
                            color: Color(0xFFFFFFFF),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          
                          // Album Art / Visualizer - optimized for vertical view
                          Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: MediaQuery.of(context).size.width * 0.85,
                            constraints: const BoxConstraints(
                              maxWidth: 360,
                              maxHeight: 360,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF000000).withOpacity(0.6),
                                  blurRadius: 60,
                                  offset: const Offset(0, 30),
                                  spreadRadius: -10,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFFFFFFF).withOpacity(0.05),
                                  blurRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showVisualizer = !_showVisualizer;
                                });
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: _showVisualizer
                                    ? EmbeddedVisualizer(
                                        trackName: currentTrack.name,
                                        artistName: currentTrack.artistName,
                                        isPlaying: audioHandler?.isPlaying ?? false,
                                      )
                                    : AlbumArtWidget(
                                        imageUrl: currentTrack.imageUrl != null
                                            ? appState.jellyfinService.getImageUrl(
                                                currentTrack.imageUrl!,
                                                width: 800,
                                                height: 800,
                                              )
                                            : null,
                                        size: MediaQuery.of(context).size.width * 0.85,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Track info with improved typography
                          Column(
                            children: [
                              Text(
                                currentTrack.name,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFFFFF),
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              if (currentTrack.artistName != null)
                                GestureDetector(
                                  onTap: () => _navigateToArtist(context, currentTrack, appState),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: const Color(0xFF1C1C1E).withOpacity(0.6),
                                    ),
                                    child: Text(
                                      currentTrack.artistName!,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFFFFFFFF),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              if (currentTrack.albumName != null) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => _navigateToAlbum(context, currentTrack, appState),
                                  child: Text(
                                    currentTrack.albumName!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: CupertinoColors.systemGrey2.withOpacity(0.8),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Enhanced progress slider
                          StreamBuilder<Duration>(
                            stream: audioHandler?.positionStream ?? Stream.value(Duration.zero),
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration = audioHandler?.duration ?? Duration.zero;
                              
                              // Calculate slider value with bounds checking
                              double sliderValue = 0.0;
                              if (duration.inMilliseconds > 0) {
                                sliderValue = position.inMilliseconds / duration.inMilliseconds;
                                sliderValue = sliderValue.clamp(0.0, 1.0);
                              }
                              
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: const Color(0xFF1C1C1E).withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.all(20),
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
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(position),
                                          style: const TextStyle(
                                            color: Color(0xFFFFFFFF),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: const TextStyle(
                                            color: Color(0xFFFFFFFF),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Enhanced control buttons
                          StreamBuilder(
                            stream: audioHandler?.playerStateStream,
                            builder: (context, snapshot) {
                              final isPlaying = audioHandler?.isPlaying ?? false;
                              final processingState = audioHandler?.playerState.processingState;
                              
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: const Color(0xFF1C1C1E).withOpacity(0.4),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Shuffle button
                                    _buildControlButton(
                                      icon: CupertinoIcons.shuffle,
                                      isActive: audioHandler?.isShuffled == true,
                                      onPressed: () {
                                        final audioHandler = appState.audioHandler;
                                        if (audioHandler?.isShuffled == true) {
                                          audioHandler?.unshuffle();
                                        } else {
                                          audioHandler?.shuffle();
                                        }
                                      },
                                    ),
                                    
                                    // Previous button
                                    _buildControlButton(
                                      icon: CupertinoIcons.backward_fill,
                                      size: 32,
                                      isEnabled: audioHandler?.hasPrevious == true,
                                      onPressed: audioHandler?.hasPrevious == true
                                          ? () => appState.skipToPrevious()
                                          : null,
                                    ),
                                    
                                    // Play/Pause button (larger)
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFFFF),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFFFFFF).withOpacity(0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: processingState == ProcessingState.loading ||
                                              processingState == ProcessingState.buffering
                                          ? const Center(
                                              child: CupertinoActivityIndicator(
                                                color: Color(0xFF000000),
                                                radius: 16,
                                              ),
                                            )
                                          : CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              onPressed: () => appState.playPause(),
                                              child: Icon(
                                                isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                                                size: 36,
                                                color: const Color(0xFF000000),
                                              ),
                                            ),
                                    ),
                                    
                                    // Next button
                                    _buildControlButton(
                                      icon: CupertinoIcons.forward_fill,
                                      size: 32,
                                      isEnabled: audioHandler?.hasNext == true,
                                      onPressed: audioHandler?.hasNext == true
                                          ? () => appState.skipToNext()
                                          : null,
                                    ),
                                    
                                    // Repeat button
                                    StreamBuilder<AudioServiceRepeatMode>(
                                      stream: audioHandler?.playbackState.map((state) => state.repeatMode),
                                      builder: (context, snapshot) {
                                        final repeatMode = snapshot.data ?? AudioServiceRepeatMode.none;
                                        
                                        return _buildControlButton(
                                          icon: repeatMode == AudioServiceRepeatMode.one 
                                              ? CupertinoIcons.repeat_1
                                              : CupertinoIcons.repeat,
                                          isActive: repeatMode != AudioServiceRepeatMode.none,
                                          onPressed: () async {
                                            final audioHandler = appState.audioHandler;
                                            if (audioHandler != null) {
                                              switch (repeatMode) {
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
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Enhanced bottom controls
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFF1C1C1E).withOpacity(0.4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildBottomControlButton(
                                  icon: CupertinoIcons.list_bullet,
                                  onPressed: () => showQueueOverlay(context),
                                ),
                                _buildBottomControlButton(
                                  icon: CupertinoIcons.text_quote,
                                  onPressed: () => _showLyricsOverlay(context, currentTrack),
                                ),
                                _buildBottomControlButton(
                                  icon: currentTrack.isFavorite 
                                      ? CupertinoIcons.heart_fill
                                      : CupertinoIcons.heart,
                                  color: currentTrack.isFavorite 
                                      ? const Color(0xFFFF453A)
                                      : null,
                                  onPressed: () async {
                                    await _favoriteAnimationController.forward();
                                    await _favoriteAnimationController.reverse();
                                    appState.toggleFavorite(currentTrack);
                                  },
                                ),
                                _buildBottomControlButton(
                                  icon: CupertinoIcons.ellipsis,
                                  onPressed: () => _showMoreOptions(context, currentTrack, appState),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
          _buildArtistAlbumText(currentTrack),
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

  String _buildArtistAlbumText(dynamic track) {
    final albumName = track.albumName;
    final artistName = track.artistName;
    
    if (albumName != null && artistName != null) {
      return '$artistName - $albumName';
    } else if (artistName != null) {
      return artistName;
    } else if (albumName != null) {
      return albumName;
    } else {
      return 'Unknown Artist';
    }
  }

  void _navigateToAlbum(BuildContext context, Track track, AppState appState) {
    try {
      debugPrint('Attempting to navigate to album: ${track.albumName} (ID: ${track.albumId})');
      
      if (track.albumId == null) {
        debugPrint('Track albumId is null, cannot navigate');
        _showErrorSnackBar(context, 'Album information not available');
        return;
      }
      
      final album = appState.albums.firstWhere(
        (album) => album.id == track.albumId,
        orElse: () => throw StateError('Album not found'),
      );
      
      debugPrint('Found album: ${album.name}, navigating...');
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => AlbumDetailScreen(album: album),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to album: $e');
      _showErrorSnackBar(context, 'Album not found in library');
    }
  }

  void _navigateToArtist(BuildContext context, Track track, AppState appState) {
    try {
      debugPrint('Attempting to navigate to artist: ${track.artistName}');
      
      if (track.artistName == null) {
        debugPrint('Track artistName is null, cannot navigate');
        _showErrorSnackBar(context, 'Artist information not available');
        return;
      }
      
      final artist = appState.artists.firstWhere(
        (artist) => artist.name == track.artistName,
        orElse: () => throw StateError('Artist not found'),
      );
      
      debugPrint('Found artist: ${artist.name}, navigating...');
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => ArtistDetailScreen(artist: artist),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to artist: $e');
      _showErrorSnackBar(context, 'Artist not found in library');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Navigation Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isActive = false,
    bool isEnabled = true,
    double size = 24,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isEnabled ? onPressed : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive 
              ? const Color(0xFFFF453A).withOpacity(0.2)
              : const Color(0x00000000),
        ),
        child: Icon(
          icon,
          color: isActive 
              ? const Color(0xFFFF453A)
              : isEnabled 
                  ? const Color(0xFFFFFFFF)
                  : CupertinoColors.systemGrey2,
          size: size,
        ),
      ),
    );
  }

  Widget _buildBottomControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2C2C2E).withOpacity(0.6),
        ),
        child: Icon(
          icon,
          color: color ?? const Color(0xFFFFFFFF),
          size: 22,
        ),
      ),
    );
  }
}
