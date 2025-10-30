import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import 'lyrics/lyrics_overlay.dart';
import 'queue/queue_overlay.dart';
import '../../widgets/cached_image_widget.dart';
import '../shared/detail_track_view.dart';
import '../artists/details/artist_detail.dart';
import '../../services/lyrics_service.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _favoriteAnimationController;
  late Animation<double> _favoriteScaleAnimation;
  bool? _hasLyrics; // null = unknown, true = available, false = not available
  String? _lastCheckedTrackId; // To avoid repeated checks for the same track

  @override
  void initState() {
    super.initState();
    _favoriteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _favoriteScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _favoriteAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _favoriteAnimationController.dispose();
    super.dispose();
  }

  // Check if lyrics are available for the current track
  void _checkLyricsAvailability(
    String trackName,
    String artistName,
    String trackId,
  ) async {
    // Avoid repeated checks for the same track
    if (_lastCheckedTrackId == trackId && _hasLyrics != null) {
      return;
    }

    _lastCheckedTrackId = trackId;

    try {
      final lyricsResult = await LyricsService.fetchLyrics(
        trackName,
        artistName,
      );
      if (mounted) {
        setState(() {
          _hasLyrics = lyricsResult != null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasLyrics = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;

        if (audioHandler == null) {
          return CupertinoPageScaffold(
            backgroundColor: const Color(0xFF000000),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.music_note,
                    size: 64,
                    color: CupertinoColors.systemGrey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No audio handler available',
                    style: TextStyle(
                      fontSize: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Use both MediaItem stream and direct access for maximum reliability
        return StreamBuilder<MediaItem?>(
          stream: appState.mediaItem,
          builder: (context, mediaItemSnapshot) {
            return StreamBuilder<dynamic>(
              stream: Stream.periodic(const Duration(milliseconds: 500)),
              builder: (context, _) {
                final mediaItem = mediaItemSnapshot.data;
                final directTrack = audioHandler?.currentTrack;
                
                // Prefer direct track access for most reliable updates
                final currentTrack = directTrack ?? 
                    (mediaItem != null ? appState.findTrackById(mediaItem.id) : null);

            // Check lyrics availability when track changes
            if (currentTrack != null && currentTrack.artistName != null) {
              _checkLyricsAvailability(
                currentTrack.name,
                currentTrack.artistName!,
                currentTrack.id,
              );
            }

            if (currentTrack == null) {
              return CupertinoPageScaffold(
                backgroundColor: const Color(0xFF000000),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.music_note,
                        size: 64,
                        color: CupertinoColors.systemGrey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No music playing',
                        style: TextStyle(
                          fontSize: 18,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
          backgroundColor: const Color(0xFF000000),
          body: Stack(
            children: [
              // Blurred background
              if (currentTrack.imageUrl != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          appState.getImageUrl(
                            currentTrack.imageUrl!,
                            width: 800,
                            height: 800,
                          ),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: StreamBuilder<PlayerState>(
                      stream: appState.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing == true;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: isPlaying ? 30 : 20,
                              sigmaY: isPlaying ? 30 : 20,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                  isPlaying ? 0.5 : 0.7,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              // Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Column(
                    children: [
                      // Top bar with chevron down and playback source indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
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
                            // Playback source indicator
                            Consumer<AppState>(
                              builder: (context, appState, child) {
                                final isDownloaded = appState.downloadService
                                    .isTrackDownloaded(currentTrack.id);

                                return Icon(
                                  isDownloaded
                                      ? CupertinoIcons.floppy_disk
                                      : CupertinoIcons
                                            .antenna_radiowaves_left_right,
                                  color: const Color(0xFFFFFFFF),
                                  size: 28,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Flexible content area
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // Album Art - responsive to available space
                            Expanded(
                              flex: 3,
                              child: StreamBuilder<PlayerState>(
                                stream: appState.playerStateStream,
                                builder: (context, snapshot) {
                                  final isPlaying =
                                      snapshot.data?.playing == true;

                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Calculate album art size based on available space
                                      final availableSize =
                                          constraints.maxHeight * 0.9;
                                      final screenWidth = MediaQuery.of(
                                        context,
                                      ).size.width;
                                      final albumArtSize =
                                          (availableSize < screenWidth * 0.8)
                                          ? availableSize
                                          : screenWidth * 0.8;

                                      return Center(
                                        child: AnimatedScale(
                                          scale: isPlaying ? 1.0 : 0.85,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                          child: Container(
                                            width: albumArtSize,
                                            height: albumArtSize,
                                            constraints: const BoxConstraints(
                                              maxWidth: 350,
                                              maxHeight: 350,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF000000,
                                                  ).withOpacity(0.6),
                                                  blurRadius: 30,
                                                  offset: const Offset(0, 15),
                                                ),
                                              ],
                                            ),
                                            child: AlbumArtWidget(
                                              imageUrl:
                                                  currentTrack.imageUrl != null
                                                  ? appState.getImageUrl(
                                                      currentTrack.imageUrl!,
                                                      width: 800,
                                                      height: 800,
                                                    )
                                                  : null,
                                              size: albumArtSize,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            // Track info section - with proper overflow handling
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Track name with flexible sizing
                                    Flexible(
                                      child: Text(
                                        currentTrack.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFFFFFF),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines:
                                            3, // Allow more lines for large fonts
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Artist name with flexible sizing
                                    Flexible(
                                      child: Text(
                                        currentTrack.artistName ??
                                            'Unknown Artist',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines:
                                            2, // Allow more lines for large fonts
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom section - fixed height
                      Column(
                        children: [
                          // Progress slider and time
                          StreamBuilder<Duration>(
                            stream:
                                audioHandler?.positionStream ??
                                Stream.value(Duration.zero),
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration =
                                  audioHandler?.duration ?? Duration.zero;

                              double sliderValue = 0.0;
                              if (duration.inMilliseconds > 0) {
                                sliderValue =
                                    position.inMilliseconds /
                                    duration.inMilliseconds;
                                sliderValue = sliderValue.clamp(0.0, 1.0);
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                ),
                                child: Column(
                                  children: [
                                    CupertinoSlider(
                                      value: sliderValue,
                                      onChanged: (value) {
                                        final newPosition = Duration(
                                          milliseconds:
                                              (value * duration.inMilliseconds)
                                                  .round(),
                                        );
                                        appState.seekTo(newPosition);
                                      },
                                      activeColor: const Color(0xFFFFFFFF),
                                      thumbColor: const Color(0xFFFFFFFF),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color:
                                                  CupertinoColors.systemGrey2,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(duration),
                                            style: const TextStyle(
                                              color:
                                                  CupertinoColors.systemGrey2,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Control buttons
                          StreamBuilder<PlayerState>(
                            stream: appState.playerStateStream,
                            builder: (context, snapshot) {
                              final isPlaying = snapshot.data?.playing == true;
                              final processingState =
                                  snapshot.data?.processingState ??
                                  ProcessingState.idle;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Shuffle button
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        final audioHandler =
                                            appState.audioHandler;
                                        if (audioHandler?.isShuffled == true) {
                                          audioHandler?.unshuffle();
                                        } else {
                                          audioHandler?.shuffle();
                                        }
                                      },
                                      child: Icon(
                                        CupertinoIcons.shuffle,
                                        color: audioHandler?.isShuffled == true
                                            ? const Color(0xFFFFFFFF)
                                            : CupertinoColors.systemGrey2,
                                        size: 24,
                                      ),
                                    ),
                                    // Previous button
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed:
                                          audioHandler?.hasPrevious == true
                                          ? () => appState.skipToPrevious()
                                          : null,
                                      child: Icon(
                                        CupertinoIcons.backward_fill,
                                        size: 32,
                                        color: audioHandler?.hasPrevious == true
                                            ? const Color(0xFFFFFFFF)
                                            : CupertinoColors.systemGrey2,
                                      ),
                                    ),
                                    // Play/Pause button
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFFFFF),
                                        shape: BoxShape.circle,
                                      ),
                                      child:
                                          processingState ==
                                                  ProcessingState.loading ||
                                              processingState ==
                                                  ProcessingState.buffering
                                          ? const Center(
                                              child: CupertinoActivityIndicator(
                                                color: Color(0xFF000000),
                                              ),
                                            )
                                          : CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                if (kDebugMode) {
                                                  print(
                                                    '=== NOW PLAYING PLAY/PAUSE BUTTON TAPPED ===',
                                                  );
                                                  print(
                                                    'isPlaying: $isPlaying',
                                                  );
                                                  print(
                                                    'processingState: $processingState',
                                                  );
                                                  print(
                                                    'audioHandler.userIntendedPlaying: ${audioHandler?.userIntendedPlaying}',
                                                  );
                                                }
                                                appState.playPause();
                                              },
                                              child: Icon(
                                                isPlaying
                                                    ? CupertinoIcons.pause_fill
                                                    : CupertinoIcons
                                                          .play_arrow_solid,
                                                size: 28,
                                                color: const Color(0xFF000000),
                                              ),
                                            ),
                                    ),
                                    // Next button
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: audioHandler?.hasNext == true
                                          ? () => appState.skipToNext()
                                          : null,
                                      child: Icon(
                                        CupertinoIcons.forward_fill,
                                        size: 32,
                                        color: audioHandler?.hasNext == true
                                            ? const Color(0xFFFFFFFF)
                                            : CupertinoColors.systemGrey2,
                                      ),
                                    ),
                                    // Repeat button
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () async {
                                        final audioHandler =
                                            appState.audioHandler;
                                        if (audioHandler != null) {
                                          final currentState =
                                              audioHandler.playbackState.value;
                                          final currentMode =
                                              currentState.repeatMode;

                                          switch (currentMode) {
                                            case AudioServiceRepeatMode.none:
                                              await audioHandler.setRepeatMode(
                                                AudioServiceRepeatMode.all,
                                              );
                                              break;
                                            case AudioServiceRepeatMode.all:
                                              await audioHandler.setRepeatMode(
                                                AudioServiceRepeatMode.one,
                                              );
                                              break;
                                            case AudioServiceRepeatMode.one:
                                              await audioHandler.setRepeatMode(
                                                AudioServiceRepeatMode.none,
                                              );
                                              break;
                                            case AudioServiceRepeatMode.group:
                                              await audioHandler.setRepeatMode(
                                                AudioServiceRepeatMode.none,
                                              );
                                              break;
                                          }
                                        }
                                      },
                                      child:
                                          StreamBuilder<AudioServiceRepeatMode>(
                                            stream: audioHandler?.playbackState
                                                .map(
                                                  (state) => state.repeatMode,
                                                )
                                                .cast<AudioServiceRepeatMode>(),
                                            builder: (context, snapshot) {
                                              final repeatMode =
                                                  snapshot.data ??
                                                  AudioServiceRepeatMode.none;

                                              return Icon(
                                                repeatMode ==
                                                        AudioServiceRepeatMode
                                                            .one
                                                    ? CupertinoIcons.repeat_1
                                                    : CupertinoIcons.repeat,
                                                color:
                                                    repeatMode ==
                                                        AudioServiceRepeatMode
                                                            .none
                                                    ? CupertinoColors
                                                          .systemGrey2
                                                    : const Color(0xFFFFFFFF),
                                                size: 24,
                                              );
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 15),

                          // Bottom controls row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 60),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Queue button
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
                                // Favorite button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () async {
                                    await _favoriteAnimationController
                                        .forward();
                                    await _favoriteAnimationController
                                        .reverse();
                                    appState.toggleFavorite(currentTrack);
                                  },
                                  child: AnimatedBuilder(
                                    animation: _favoriteScaleAnimation,
                                    builder: (context, child) {
                                      final isFavorite = appState.isFavorite(
                                        currentTrack.id,
                                      );
                                      return Transform.scale(
                                        scale: _favoriteScaleAnimation.value,
                                        child: Icon(
                                          isFavorite
                                              ? CupertinoIcons.heart_fill
                                              : CupertinoIcons.heart,
                                          color: isFavorite
                                              ? const Color(0xFFFF453A)
                                              : const Color(0xFFFFFFFF),
                                          size: 24,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Lyrics button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: _hasLyrics == true
                                      ? () {
                                          _showLyricsOverlay(
                                            context,
                                            currentTrack,
                                          );
                                        }
                                      : null,
                                  child: Icon(
                                    CupertinoIcons.text_quote,
                                    color: _hasLyrics == true
                                        ? const Color(0xFFFFFFFF)
                                        : CupertinoColors.systemGrey2,
                                    size: 24,
                                  ),
                                ),
                                // More options button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _showMoreOptions(
                                    context,
                                    currentTrack,
                                    appState,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.ellipsis,
                                    color: Color(0xFFFFFFFF),
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 15),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
              }, // Periodic StreamBuilder builder
            ); // Periodic StreamBuilder  
          }, // MediaItem StreamBuilder builder
        ); // MediaItem StreamBuilder
      }, // Consumer builder
    ); // Consumer
  } // build method

  void _showLyricsOverlay(BuildContext context, dynamic currentTrack) {
    showSyncedLyricsOverlay(
      context,
      currentTrack.name,
      currentTrack.artistName ?? 'Unknown Artist',
    );
  }

  void _showMoreOptions(
    BuildContext context,
    dynamic currentTrack,
    AppState appState,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(currentTrack.name, style: const TextStyle(fontSize: 16)),
        message: Text(
          _buildArtistAlbumText(currentTrack),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          // Go to Album
          if (currentTrack.albumName != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _navigateToAlbum(context, currentTrack, appState);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.music_albums,
                    color: CupertinoColors.activeBlue,
                  ),
                  SizedBox(width: 8),
                  Text('Go to Album'),
                ],
              ),
            ),
          // Go to Artist
          if (currentTrack.artistName != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _navigateToArtist(context, currentTrack, appState);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.person,
                    color: CupertinoColors.activeBlue,
                  ),
                  SizedBox(width: 8),
                  Text('Go to Artist'),
                ],
              ),
            ),
          // Add to Playlist
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showAddToPlaylistDialog(context, currentTrack, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.add_circled,
                  color: CupertinoColors.activeBlue,
                ),
                SizedBox(width: 8),
                Text('Add to Playlist'),
              ],
            ),
          ),
          // Share
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareTrack(context, currentTrack);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Share'),
              ],
            ),
          ),
          // Radio Mode
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.toggleRadioMode();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.infinite,
                  color: appState.radioModeEnabled
                      ? const Color(0xFFFF453A)
                      : CupertinoColors.activeBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  appState.radioModeEnabled
                      ? 'Disable Radio Mode'
                      : 'Enable Radio Mode',
                ),
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

  void _shareTrack(BuildContext context, dynamic currentTrack) {
    final trackInfo =
        '${currentTrack.name} by ${currentTrack.artistName ?? 'Unknown Artist'}';

    // For now, just show the track info in a dialog
    // In a real app, you would use a share plugin like share_plus
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Share Track'),
        content: Text(trackInfo),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    dynamic currentTrack,
    AppState appState,
  ) {
    final playlists = appState.playlists;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add to Playlist'),
        message: Text('Select a playlist to add "${currentTrack.name}" to:'),
        actions: [
          // Show existing playlists
          ...playlists.map(
            (playlist) => CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _addToExistingPlaylist(
                  context,
                  playlist,
                  currentTrack,
                  appState,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.music_note_list,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(playlist.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
          // Create new playlist option
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _createNewPlaylist(context, currentTrack, appState);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.add_circled,
                  color: CupertinoColors.activeBlue,
                ),
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

  void _addToExistingPlaylist(
    BuildContext context,
    dynamic playlist,
    dynamic currentTrack,
    AppState appState,
  ) async {
    try {
      final success = await appState.addToPlaylist(
        playlist.id,
        currentTrack.id,
      );

      if (context.mounted) {
        if (success) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Success'),
              content: Text(
                'Added "${currentTrack.name}" to "${playlist.name}".',
              ),
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
              content: Text(
                'Failed to add "${currentTrack.name}" to "${playlist.name}".',
              ),
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

  void _createNewPlaylist(
    BuildContext context,
    dynamic currentTrack,
    AppState appState,
  ) {
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
                _addToNewPlaylist(
                  context,
                  controller.text.trim(),
                  currentTrack,
                  appState,
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _addToNewPlaylist(
    BuildContext context,
    String playlistName,
    dynamic currentTrack,
    AppState appState,
  ) async {
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
        final addSuccess = await appState.addToPlaylist(
          newPlaylist.id,
          currentTrack.id,
        );

        if (context.mounted) {
          if (addSuccess) {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Success'),
                content: Text(
                  'Created playlist "$playlistName" and added "${currentTrack.name}" to it.',
                ),
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
                content: Text(
                  'Created playlist "$playlistName" but failed to add the song. You can add it manually from the playlists screen.',
                ),
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
      debugPrint(
        'Attempting to navigate to album: ${track.albumName} (ID: ${track.albumId})',
      );

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
        CupertinoPageRoute(builder: (context) => DetailTrackView.album(album)),
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
}
