import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import 'lyrics/lyrics_overlay.dart';
import 'queue/queue_overlay.dart';
import '../widgets/cached_image_widget.dart';
import '../widgets/marquee_text.dart';
import '../shared/detail_track_view.dart';
import '../artists/details/artist_detail.dart';
import '../../../services/lyrics_service.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _favoriteAnimationController;
  late Animation<double> _favoriteScaleAnimation;
  double _dragOffset = 0.0;
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

  // Build a carousel item with position-based scale and opacity
  Widget _buildCarouselItem({
    required AppState appState,
    required dynamic track,
    required double basePosition,
    required double dragOffset,
    required double spacing,
    required double albumArtSize,
    required bool isPlaying,
    VoidCallback? onTap,
    bool isCurrent = false,
  }) {
    // Calculate position with drag offset
    final position = basePosition + dragOffset;

    // Normalize position to get a value from -1 to 1 (center is 0)
    final normalizedPosition = (position / spacing).clamp(-1.5, 1.5);

    // Scale: 1.0 at center, 0.7 at sides
    final scale = 1.0 - (normalizedPosition.abs() * 0.3);

    // Opacity: 1.0 at center, 0.5 at sides
    final opacity = 1.0 - (normalizedPosition.abs() * 0.5);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(position, 0),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: opacity.clamp(0.3, 1.0),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isCurrent && isPlaying ? scale : scale * 0.95,
                curve: Curves.easeOutCubic,
                child: Container(
                  width: albumArtSize,
                  height: albumArtSize,
                  constraints: const BoxConstraints(
                    maxWidth: 350,
                    maxHeight: 350,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withOpacity(isPlaying ? 0.3 : 0.1),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                              spreadRadius: isPlaying ? 5 : 0,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFEC4899,
                              ).withOpacity(isPlaying ? 0.2 : 0.05),
                              blurRadius: 60,
                              offset: const Offset(-10, 30),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        AlbumArtWidget(
                          imageUrl: track.imageUrl != null
                              ? appState.getImageUrl(
                                  track.imageUrl!,
                                  width: 800,
                                  height: 800,
                                )
                              : null,
                          size: albumArtSize,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        // Subtle liquid glass overlay for current playing track
                        if (isCurrent && isPlaying)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    CupertinoColors.white.withOpacity(0.1),
                                    Colors.transparent,
                                    CupertinoColors.white.withOpacity(0.05),
                                  ],
                                ),
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
      ),
    );
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

        // Use the currentTrackStream for reliable real-time updates
        return StreamBuilder<Track?>(
          stream: appState.currentTrackStream,
          builder: (context, currentTrackSnapshot) {
            // Get current track from the stream or fallback to direct access
            final currentTrack =
                currentTrackSnapshot.data ?? audioHandler?.currentTrack;

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
                  // Blurred background with animated gradient
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
                              duration: const Duration(milliseconds: 500),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: isPlaying ? 40 : 25,
                                  sigmaY: isPlaying ? 40 : 25,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(
                                          isPlaying ? 0.3 : 0.5,
                                        ),
                                        Colors.black.withOpacity(
                                          isPlaying ? 0.6 : 0.8,
                                        ),
                                      ],
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
                          // Top bar with liquid glass style
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Liquid glass close button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.white
                                              .withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: CupertinoColors.white
                                                .withOpacity(0.2),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.chevron_down,
                                          color: CupertinoColors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Playback source indicator with liquid glass
                                Consumer<AppState>(
                                  builder: (context, appState, child) {
                                    final isDownloaded = appState
                                        .downloadService
                                        .isTrackDownloaded(currentTrack.id);

                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.white
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: CupertinoColors.white
                                                  .withOpacity(0.2),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Icon(
                                            isDownloaded
                                                ? CupertinoIcons.floppy_disk
                                                : CupertinoIcons
                                                      .antenna_radiowaves_left_right,
                                            color: CupertinoColors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
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

                                // Album Art Carousel with rotary animation
                                Expanded(
                                  flex: 3,
                                  child: StreamBuilder<PlayerState>(
                                    stream: appState.playerStateStream,
                                    builder: (context, snapshot) {
                                      final isPlaying =
                                          snapshot.data?.playing == true;
                                      final queueTracks =
                                          appState.audioHandler?.queueTracks ??
                                          [];
                                      final currentIndex =
                                          appState.audioHandler?.currentIndex ??
                                          0;

                                      // Get previous and next tracks
                                      final prevTrack = currentIndex > 0
                                          ? queueTracks[currentIndex - 1]
                                          : null;
                                      final nextTrack =
                                          currentIndex < queueTracks.length - 1
                                          ? queueTracks[currentIndex + 1]
                                          : null;

                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          final availableSize =
                                              constraints.maxHeight * 0.9;
                                          final screenWidth = MediaQuery.of(
                                            context,
                                          ).size.width;
                                          final albumArtSize =
                                              (availableSize <
                                                  screenWidth * 0.75)
                                              ? availableSize
                                              : screenWidth * 0.75;
                                          // Distance between album art centers
                                          final spacing = screenWidth * 0.85;

                                          return GestureDetector(
                                            onHorizontalDragUpdate: (details) {
                                              setState(() {
                                                _dragOffset += details.delta.dx;
                                                // Limit drag to one album art width
                                                _dragOffset = _dragOffset.clamp(
                                                  nextTrack != null
                                                      ? -spacing
                                                      : 0.0,
                                                  prevTrack != null
                                                      ? spacing
                                                      : 0.0,
                                                );
                                              });
                                            },
                                            onHorizontalDragEnd: (details) {
                                              final velocity =
                                                  details.primaryVelocity ?? 0;
                                              final threshold = spacing * 0.3;

                                              // Swipe left (negative) = next track
                                              if ((velocity < -300 ||
                                                      _dragOffset <
                                                          -threshold) &&
                                                  nextTrack != null) {
                                                appState.skipToNext();
                                                setState(() => _dragOffset = 0);
                                              }
                                              // Swipe right (positive) = previous track
                                              else if ((velocity > 300 ||
                                                      _dragOffset >
                                                          threshold) &&
                                                  prevTrack != null) {
                                                appState.skipToPrevious();
                                                setState(() => _dragOffset = 0);
                                              }
                                              // Snap back with animation
                                              else {
                                                setState(() => _dragOffset = 0);
                                              }
                                            },
                                            child: Stack(
                                              alignment: Alignment.center,
                                              clipBehavior: Clip.none,
                                              children: [
                                                // Previous track album art (left position)
                                                if (prevTrack != null)
                                                  _buildCarouselItem(
                                                    appState: appState,
                                                    track: prevTrack,
                                                    basePosition: -spacing,
                                                    dragOffset: _dragOffset,
                                                    spacing: spacing,
                                                    albumArtSize: albumArtSize,
                                                    isPlaying: false,
                                                    onTap: () => appState
                                                        .skipToPrevious(),
                                                  ),

                                                // Next track album art (right position)
                                                if (nextTrack != null)
                                                  _buildCarouselItem(
                                                    appState: appState,
                                                    track: nextTrack,
                                                    basePosition: spacing,
                                                    dragOffset: _dragOffset,
                                                    spacing: spacing,
                                                    albumArtSize: albumArtSize,
                                                    isPlaying: false,
                                                    onTap: () =>
                                                        appState.skipToNext(),
                                                  ),

                                                // Current track album art (center)
                                                _buildCarouselItem(
                                                  appState: appState,
                                                  track: currentTrack,
                                                  basePosition: 0,
                                                  dragOffset: _dragOffset,
                                                  spacing: spacing,
                                                  albumArtSize: albumArtSize,
                                                  isPlaying: isPlaying,
                                                  onTap: null,
                                                  isCurrent: true,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),

                                // Track info section with liquid glass card
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 36,
                                          child: MarqueeText(
                                            text: currentTrack.name,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w700,
                                              color: CupertinoColors.white,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
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
                                  final position =
                                      snapshot.data ?? Duration.zero;
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
                                        // Liquid glass progress bar
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 5,
                                              sigmaY: 5,
                                            ),
                                            child: Container(
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: CupertinoColors.white
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  return Stack(
                                                    children: [
                                                      Container(
                                                        width:
                                                            constraints
                                                                .maxWidth *
                                                            sliderValue,
                                                        decoration: BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                    0xFF8B5CF6,
                                                                  ),
                                                                  Color(
                                                                    0xFFEC4899,
                                                                  ),
                                                                ],
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Gesture detector for seeking
                                        GestureDetector(
                                          onHorizontalDragUpdate: (details) {
                                            final box =
                                                context.findRenderObject()
                                                    as RenderBox;
                                            final localPosition =
                                                details.localPosition;
                                            final newValue =
                                                (localPosition.dx /
                                                        box.size.width)
                                                    .clamp(0.0, 1.0);
                                            final newPosition = Duration(
                                              milliseconds:
                                                  (newValue *
                                                          duration
                                                              .inMilliseconds)
                                                      .round(),
                                            );
                                            appState.seekTo(newPosition);
                                          },
                                          child: Container(
                                            height: 20,
                                            color: Colors.transparent,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatDuration(position),
                                                style: TextStyle(
                                                  color: CupertinoColors.white
                                                      .withOpacity(0.6),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                _formatDuration(duration),
                                                style: TextStyle(
                                                  color: CupertinoColors.white
                                                      .withOpacity(0.6),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
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

                              const SizedBox(height: 24),

                              // Control buttons with liquid glass
                              StreamBuilder<PlayerState>(
                                stream: appState.playerStateStream,
                                builder: (context, snapshot) {
                                  final isPlaying =
                                      snapshot.data?.playing == true;
                                  final processingState =
                                      snapshot.data?.processingState ??
                                      ProcessingState.idle;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Shuffle button with liquid glass
                                        GestureDetector(
                                          onTap: () {
                                            final audioHandler =
                                                appState.audioHandler;
                                            if (audioHandler?.isShuffled ==
                                                true) {
                                              audioHandler?.unshuffle();
                                            } else {
                                              audioHandler?.shuffle();
                                            }
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 8,
                                                sigmaY: 8,
                                              ),
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color:
                                                      audioHandler
                                                              ?.isShuffled ==
                                                          true
                                                      ? const Color(
                                                          0xFF8B5CF6,
                                                        ).withOpacity(0.3)
                                                      : CupertinoColors.white
                                                            .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        audioHandler
                                                                ?.isShuffled ==
                                                            true
                                                        ? const Color(
                                                            0xFF8B5CF6,
                                                          ).withOpacity(0.5)
                                                        : CupertinoColors.white
                                                              .withOpacity(
                                                                0.15,
                                                              ),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.shuffle,
                                                  color:
                                                      audioHandler
                                                              ?.isShuffled ==
                                                          true
                                                      ? CupertinoColors.white
                                                      : CupertinoColors.white
                                                            .withOpacity(0.6),
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Previous button
                                        GestureDetector(
                                          onTap:
                                              audioHandler?.hasPrevious == true
                                              ? () => appState.skipToPrevious()
                                              : null,
                                          child: Icon(
                                            CupertinoIcons.backward_fill,
                                            size: 36,
                                            color:
                                                audioHandler?.hasPrevious ==
                                                    true
                                                ? CupertinoColors.white
                                                : CupertinoColors.white
                                                      .withOpacity(0.3),
                                          ),
                                        ),
                                        // Play/Pause button with gradient
                                        GestureDetector(
                                          onTap: () => appState.playPause(),
                                          child: Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFF8B5CF6),
                                                  Color(0xFFEC4899),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF8B5CF6,
                                                  ).withOpacity(0.4),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child:
                                                processingState ==
                                                        ProcessingState
                                                            .loading ||
                                                    processingState ==
                                                        ProcessingState
                                                            .buffering
                                                ? const Center(
                                                    child:
                                                        CupertinoActivityIndicator(
                                                          color: CupertinoColors
                                                              .white,
                                                        ),
                                                  )
                                                : Icon(
                                                    isPlaying
                                                        ? CupertinoIcons
                                                              .pause_fill
                                                        : CupertinoIcons
                                                              .play_arrow_solid,
                                                    size: 32,
                                                    color:
                                                        CupertinoColors.white,
                                                  ),
                                          ),
                                        ),
                                        // Next button
                                        GestureDetector(
                                          onTap: audioHandler?.hasNext == true
                                              ? () => appState.skipToNext()
                                              : null,
                                          child: Icon(
                                            CupertinoIcons.forward_fill,
                                            size: 36,
                                            color: audioHandler?.hasNext == true
                                                ? CupertinoColors.white
                                                : CupertinoColors.white
                                                      .withOpacity(0.3),
                                          ),
                                        ),
                                        // Repeat button with liquid glass
                                        GestureDetector(
                                          onTap: () async {
                                            final audioHandler =
                                                appState.audioHandler;
                                            if (audioHandler != null) {
                                              final currentState = audioHandler
                                                  .playbackState
                                                  .value;
                                              final currentMode =
                                                  currentState.repeatMode;

                                              switch (currentMode) {
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
                                          },
                                          child: StreamBuilder<AudioServiceRepeatMode>(
                                            stream: audioHandler?.playbackState
                                                .map(
                                                  (state) => state.repeatMode,
                                                )
                                                .cast<AudioServiceRepeatMode>(),
                                            builder: (context, snapshot) {
                                              final repeatMode =
                                                  snapshot.data ??
                                                  AudioServiceRepeatMode.none;
                                              final isActive =
                                                  repeatMode !=
                                                  AudioServiceRepeatMode.none;

                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(
                                                    sigmaX: 8,
                                                    sigmaY: 8,
                                                  ),
                                                  child: Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: isActive
                                                          ? const Color(
                                                              0xFFEC4899,
                                                            ).withOpacity(0.3)
                                                          : CupertinoColors
                                                                .white
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: isActive
                                                            ? const Color(
                                                                0xFFEC4899,
                                                              ).withOpacity(0.5)
                                                            : CupertinoColors
                                                                  .white
                                                                  .withOpacity(
                                                                    0.15,
                                                                  ),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      repeatMode ==
                                                              AudioServiceRepeatMode
                                                                  .one
                                                          ? CupertinoIcons
                                                                .repeat_1
                                                          : CupertinoIcons
                                                                .repeat,
                                                      color: isActive
                                                          ? CupertinoColors
                                                                .white
                                                          : CupertinoColors
                                                                .white
                                                                .withOpacity(
                                                                  0.6,
                                                                ),
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 20),

                              // Bottom controls row with liquid glass
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 15,
                                      sigmaY: 15,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: CupertinoColors.white
                                              .withOpacity(0.2),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Queue button
                                          GestureDetector(
                                            onTap: () {
                                              showQueueOverlay(context);
                                            },
                                            child: Icon(
                                              CupertinoIcons.list_bullet,
                                              color: CupertinoColors.white
                                                  .withOpacity(0.8),
                                              size: 22,
                                            ),
                                          ),
                                          // Favorite button
                                          GestureDetector(
                                            onTap: () async {
                                              await _favoriteAnimationController
                                                  .forward();
                                              await _favoriteAnimationController
                                                  .reverse();
                                              appState.toggleFavorite(
                                                currentTrack,
                                              );
                                            },
                                            child: AnimatedBuilder(
                                              animation:
                                                  _favoriteScaleAnimation,
                                              builder: (context, child) {
                                                final isFavorite = appState
                                                    .isFavorite(
                                                      currentTrack.id,
                                                    );
                                                return Transform.scale(
                                                  scale: _favoriteScaleAnimation
                                                      .value,
                                                  child: Icon(
                                                    isFavorite
                                                        ? CupertinoIcons
                                                              .heart_fill
                                                        : CupertinoIcons.heart,
                                                    color: isFavorite
                                                        ? const Color(
                                                            0xFFEC4899,
                                                          )
                                                        : CupertinoColors.white
                                                              .withOpacity(0.8),
                                                    size: 22,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          // Lyrics button
                                          GestureDetector(
                                            onTap: _hasLyrics == true
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
                                                  ? CupertinoColors.white
                                                        .withOpacity(0.8)
                                                  : CupertinoColors.white
                                                        .withOpacity(0.3),
                                              size: 22,
                                            ),
                                          ),
                                          // More options button
                                          GestureDetector(
                                            onTap: () => _showMoreOptions(
                                              context,
                                              currentTrack,
                                              appState,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.ellipsis,
                                              color: CupertinoColors.white
                                                  .withOpacity(0.8),
                                              size: 22,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }, // StreamBuilder builder
        ); // StreamBuilder
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
