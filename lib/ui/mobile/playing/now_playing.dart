import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../../models/download_models.dart';
import '../../../services/album_art_color_service.dart';
import '../../../services/audio/unified_audio_handler.dart' show RepeatMode;
import '../../../services/base_service.dart';
import 'lyrics/lyrics_overlay.dart';
import 'queue/queue_overlay.dart';
import '../widgets/cached_image_widget.dart';
import '../widgets/marquee_text.dart';
import 'package:doudou/ui/desktop/pages/details/media_details.dart';
import 'package:doudou/ui/desktop/pages/details/artist_details.dart';
import '../../../services/lyrics_service.dart';
import '../../../utils/display_utils.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _favoriteAnimationController;
  late Animation<double> _favoriteScaleAnimation;
  late AnimationController _skipAnimationController;
  late AnimationController _snapBackController;
  double _dragOffset = 0.0;
  double _snapBackStartOffset = 0.0;
  double _animationStartOffset = 0.0; // Where animation starts from
  double _currentSpacing = 0.0; // Store spacing for button animations
  bool _isAnimatingSkip = false;
  bool _isSnappingBack = false;
  int _skipDirection = 0; // -1 for next, 1 for previous
  bool? _hasLyrics; // null = unknown, true = available, false = not available
  String? _lastCheckedTrackId; // To avoid repeated checks for the same track
  Color _albumGlowColor = const Color(0xFF8B5CF6);
  String? _lastGlowTrackId;

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
    _skipAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _skipAnimationController.addListener(() {
      if (_isAnimatingSkip) {
        setState(() {
          // Animate from 0 to full spacing in the skip direction
        });
      }
    });
    _snapBackController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _snapBackController.addListener(() {
      if (_isSnappingBack) {
        setState(() {
          _dragOffset = _snapBackStartOffset * (1 - _snapBackController.value);
        });
      }
    });
  }

  @override
  void dispose() {
    _favoriteAnimationController.dispose();
    _skipAnimationController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  // Haptic feedback for favorite button
  Future<void> _triggerFavoriteHaptic() async {
    try {
      HapticFeedback.mediumImpact();
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      // Silently fail if vibration is not supported
    }
  }

  // Snap back to center with animation
  void _snapBack() {
    if (_dragOffset == 0) return;
    _isSnappingBack = true;
    _snapBackStartOffset = _dragOffset;
    _snapBackController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0;
          _isSnappingBack = false;
        });
        _snapBackController.reset();
      }
    });
  }

  // Animate skip to next track
  void _animateSkipToNext(AppState appState, double spacing) {
    if (_isAnimatingSkip) return;
    _isAnimatingSkip = true;
    _skipDirection = -1;
    _animationStartOffset = _dragOffset;

    _skipAnimationController.forward(from: 0).then((_) {
      // Change track first, then reset state in next frame to avoid visual jump
      appState.skipToNext();
      // Use a microtask to ensure track change is processed before resetting
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _dragOffset = 0;
            _isAnimatingSkip = false;
            _skipDirection = 0;
            _animationStartOffset = 0;
          });
          _skipAnimationController.reset();
        }
      });
    });
  }

  // Animate skip to previous track
  void _animateSkipToPrevious(AppState appState, double spacing) {
    if (_isAnimatingSkip) return;
    _isAnimatingSkip = true;
    _skipDirection = 1;
    _animationStartOffset = _dragOffset;

    _skipAnimationController.forward(from: 0).then((_) {
      // Change track first, then reset state in next frame to avoid visual jump
      appState.skipToPrevious();
      // Use a microtask to ensure track change is processed before resetting
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _dragOffset = 0;
            _isAnimatingSkip = false;
            _skipDirection = 0;
            _animationStartOffset = 0;
          });
          _skipAnimationController.reset();
        }
      });
    });
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
    required Color glowColor,
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
    final opacity = (1.0 - (normalizedPosition.abs() * 0.5)).clamp(0.3, 1.0);
    final glowHsl = HSLColor.fromColor(glowColor);
    final secondaryGlowColor = glowHsl
        .withHue((glowHsl.hue + 24) % 360)
        .withSaturation((glowHsl.saturation * 0.85).clamp(0.2, 1.0))
        .withLightness((glowHsl.lightness * 0.9).clamp(0.18, 0.75))
        .toColor();

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(position, 0),
          child: GestureDetector(
            onTap: onTap,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: isCurrent && isPlaying ? scale : scale * 0.95,
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
                              color: glowColor.withOpacity(
                                isPlaying ? 0.3 : 0.1,
                              ),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                              spreadRadius: isPlaying ? 5 : 0,
                            ),
                            BoxShadow(
                              color: secondaryGlowColor.withOpacity(
                                isPlaying ? 0.2 : 0.05,
                              ),
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

  Future<void> _updateAlbumGlowColor(AppState appState, Track track) async {
    if (track.imageUrl == null) {
      if (!mounted) return;
      setState(() {
        _albumGlowColor = const Color(0xFF8B5CF6);
      });
      return;
    }

    final resolvedImageUrl = appState.getImageUrl(
      track.imageUrl!,
      width: 800,
      height: 800,
    );
    if (resolvedImageUrl.isEmpty) return;

    final dominantColor = await AlbumArtColorService.getDominantGlowColor(
      resolvedImageUrl,
    );
    if (!mounted || dominantColor == null) return;

    setState(() {
      _albumGlowColor = dominantColor;
    });
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

            if (_lastGlowTrackId != currentTrack.id) {
              _lastGlowTrackId = currentTrack.id;
              _updateAlbumGlowColor(appState, currentTrack);
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
                                          // Distance between album art centers - closer so side albums peek in
                                          final spacing = albumArtSize * 0.85;
                                          // Store spacing for button animations
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (_currentSpacing !=
                                                    spacing) {
                                                  _currentSpacing = spacing;
                                                }
                                              });

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
                                                _animateSkipToNext(
                                                  appState,
                                                  spacing,
                                                );
                                              }
                                              // Swipe right (positive) = previous track
                                              else if ((velocity > 300 ||
                                                      _dragOffset >
                                                          threshold) &&
                                                  prevTrack != null) {
                                                _animateSkipToPrevious(
                                                  appState,
                                                  spacing,
                                                );
                                              }
                                              // Snap back with animation
                                              else {
                                                _snapBack();
                                              }
                                            },
                                            child: AnimatedBuilder(
                                              animation:
                                                  _skipAnimationController,
                                              builder: (context, child) {
                                                // Calculate total offset including skip animation
                                                double totalOffset;
                                                if (_isAnimatingSkip) {
                                                  // Animate from current position to target (spacing in skip direction)
                                                  final targetOffset =
                                                      _skipDirection * spacing;
                                                  final progress = Curves
                                                      .easeOutCubic
                                                      .transform(
                                                        _skipAnimationController
                                                            .value,
                                                      );
                                                  // Lerp from start position to target
                                                  totalOffset =
                                                      _animationStartOffset +
                                                      (targetOffset -
                                                              _animationStartOffset) *
                                                          progress;
                                                } else {
                                                  totalOffset = _dragOffset;
                                                }

                                                return Stack(
                                                  alignment: Alignment.center,
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    // Previous track album art (left position)
                                                    if (prevTrack != null)
                                                      _buildCarouselItem(
                                                        appState: appState,
                                                        track: prevTrack,
                                                        basePosition: -spacing,
                                                        dragOffset: totalOffset,
                                                        spacing: spacing,
                                                        albumArtSize:
                                                            albumArtSize,
                                                        isPlaying: false,
                                                        glowColor:
                                                            _albumGlowColor,
                                                        onTap: () =>
                                                            _animateSkipToPrevious(
                                                              appState,
                                                              spacing,
                                                            ),
                                                      ),

                                                    // Next track album art (right position)
                                                    if (nextTrack != null)
                                                      _buildCarouselItem(
                                                        appState: appState,
                                                        track: nextTrack,
                                                        basePosition: spacing,
                                                        dragOffset: totalOffset,
                                                        spacing: spacing,
                                                        albumArtSize:
                                                            albumArtSize,
                                                        isPlaying: false,
                                                        glowColor:
                                                            _albumGlowColor,
                                                        onTap: () =>
                                                            _animateSkipToNext(
                                                              appState,
                                                              spacing,
                                                            ),
                                                      ),

                                                    // Current track album art (center)
                                                    _buildCarouselItem(
                                                      appState: appState,
                                                      track: currentTrack,
                                                      basePosition: 0,
                                                      dragOffset: totalOffset,
                                                      spacing: spacing,
                                                      albumArtSize:
                                                          albumArtSize,
                                                      isPlaying: isPlaying,
                                                      glowColor:
                                                          _albumGlowColor,
                                                      onTap: null,
                                                      isCurrent: true,
                                                    ),
                                                  ],
                                                );
                                              },
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
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
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
                                            displayArtistName(
                                              currentTrack.artistName,
                                              defaultName: 'Unknown Artist',
                                            ),
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

                                  void seekToPosition(Offset localPosition,
                                      RenderBox box) {
                                    final newValue = (localPosition.dx /
                                            box.size.width)
                                        .clamp(0.0, 1.0);
                                    final newPosition = Duration(
                                      milliseconds: (newValue *
                                              duration.inMilliseconds)
                                          .round(),
                                    );
                                    appState.seekTo(newPosition);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Progress bar: single full-width track, fill left-to-right; large hit area
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (details) {
                                            final box = context.findRenderObject()
                                                as RenderBox;
                                            seekToPosition(
                                                details.localPosition, box);
                                          },
                                          onHorizontalDragUpdate: (details) {
                                            final box = context.findRenderObject()
                                                as RenderBox;
                                            seekToPosition(
                                                details.localPosition, box);
                                          },
                                          child: SizedBox(
                                            height: 44,
                                            child: Center(
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  final barWidth =
                                                      constraints.maxWidth;
                                                  final progress = sliderValue
                                                      .clamp(0.0, 1.0);
                                                  const barHeight = 4.0;
                                                  const thumbRadius = 6.0;
                                                  final thumbLeft =
                                                      (barWidth * progress -
                                                              thumbRadius)
                                                          .clamp(
                                                              0.0,
                                                              barWidth -
                                                                  thumbRadius *
                                                                      2);
                                                  return SizedBox(
                                                    height: 16,
                                                    width: barWidth,
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        // Thin track (blurred)
                                                        Positioned(
                                                          left: 0,
                                                          right: 0,
                                                          top: (16 - barHeight) /
                                                              2,
                                                          height: barHeight,
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(2),
                                                            child: BackdropFilter(
                                                              filter: ImageFilter
                                                                  .blur(
                                                                      sigmaX: 5,
                                                                      sigmaY: 5),
                                                              child: Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: CupertinoColors
                                                                      .white
                                                                      .withOpacity(
                                                                          0.15),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              2),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        // Active portion
                                                        Positioned(
                                                          left: 0,
                                                          top: (16 -
                                                                  barHeight) /
                                                              2,
                                                          width: barWidth *
                                                              progress,
                                                          height: barHeight,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              gradient: const LinearGradient(
                                                                begin: Alignment
                                                                    .centerLeft,
                                                                end: Alignment
                                                                    .centerRight,
                                                                colors: [
                                                                  Color(
                                                                      0xFF8B5CF6),
                                                                  Color(
                                                                      0xFFEC4899),
                                                                ],
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2),
                                                            ),
                                                          ),
                                                        ),
                                                        // Playhead: circle that escapes the box
                                                        Positioned(
                                                          left: thumbLeft,
                                                          top: (16 -
                                                                  thumbRadius *
                                                                      2) /
                                                              2,
                                                          child: Container(
                                                            width: thumbRadius *
                                                                2,
                                                            height: thumbRadius *
                                                                2,
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: Colors
                                                                  .white,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                          0.3),
                                                                  blurRadius: 4,
                                                                  offset: const Offset(
                                                                      0, 1),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
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
                                      horizontal: 36,
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
                                              ? () async {
                                                  final willRestart =
                                                      await audioHandler
                                                          .willBackRestartCurrentTrack();
                                                  if (!mounted) return;
                                                  if (willRestart) {
                                                    await appState
                                                        .skipToPrevious();
                                                    return;
                                                  }
                                                  _animateSkipToPrevious(
                                                    appState,
                                                    _currentSpacing,
                                                  );
                                                }
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
                                                : AnimatedSwitcher(
                                                    duration: const Duration(milliseconds: 200),
                                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                                      return ScaleTransition(
                                                        scale: animation,
                                                        child: FadeTransition(opacity: animation, child: child),
                                                      );
                                                    },
                                                    child: Icon(
                                                      key: ValueKey(isPlaying),
                                                      isPlaying
                                                          ? CupertinoIcons.pause_fill
                                                          : CupertinoIcons.play_arrow_solid,
                                                      size: 32,
                                                      color:
                                                          CupertinoColors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        // Next button
                                        GestureDetector(
                                          onTap: audioHandler?.hasNext == true
                                              ? () => _animateSkipToNext(
                                                  appState,
                                                  _currentSpacing,
                                                )
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
                                              final currentMode =
                                                  audioHandler.repeatMode ??
                                                  RepeatMode.none;

                                              switch (currentMode) {
                                                case RepeatMode.none:
                                                  await audioHandler
                                                      .setRepeatMode(
                                                        RepeatMode.all,
                                                      );
                                                  break;
                                                case RepeatMode.all:
                                                  await audioHandler
                                                      .setRepeatMode(
                                                        RepeatMode.one,
                                                      );
                                                  break;
                                                case RepeatMode.one:
                                                  await audioHandler
                                                      .setRepeatMode(
                                                        RepeatMode.none,
                                                      );
                                                  break;
                                              }
                                            }
                                          },
                                          child: Builder(
                                            builder: (context) {
                                              final repeatMode =
                                                  audioHandler?.repeatMode ??
                                                  RepeatMode.none;
                                              final isActive =
                                                  repeatMode != RepeatMode.none;

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
                                                              RepeatMode.one
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
                                              _triggerFavoriteHaptic();
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
                                          // Lyrics button (only when lyrics available)
                                          if (_hasLyrics == true)
                                            GestureDetector(
                                              onTap: () {
                                                _showLyricsOverlay(
                                                  context,
                                                  currentTrack,
                                                );
                                              },
                                              child: Icon(
                                                CupertinoIcons.mic_fill,
                                                color: CupertinoColors.white
                                                    .withOpacity(0.8),
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
      displayArtistName(
        currentTrack.artistName,
        defaultName: 'Unknown Artist',
      ),
    );
  }

  CupertinoActionSheetAction _buildDownloadAction(
    BuildContext context,
    dynamic currentTrack,
    AppState appState,
  ) {
    final downloadService = appState.downloadService;
    final isDownloaded = downloadService.isTrackDownloaded(currentTrack.id);
    final status = downloadService.getDownloadStatus(currentTrack.id);
    final isDownloading = status == DownloadStatus.downloading;

    String label;
    if (isDownloaded) {
      label = 'Downloaded';
    } else if (isDownloading) {
      label = 'Downloading...';
    } else {
      label = 'Download';
    }

    return CupertinoActionSheetAction(
      onPressed: isDownloaded || isDownloading
          ? () => Navigator.pop(context)
          : () {
              Navigator.pop(context);
              downloadService.downloadTrack(currentTrack as Track);
            },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDownloaded
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.arrow_down_circle,
            color: isDownloaded || isDownloading
                ? CupertinoColors.inactiveGray
                : CupertinoColors.activeBlue,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isDownloaded || isDownloading
                  ? CupertinoColors.inactiveGray
                  : CupertinoColors.activeBlue,
            ),
          ),
        ],
      ),
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
          _buildArtistAlbumText(currentTrack, appState),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          // Go to Album (SoundCloud doesn't support albums; YT Music when track has album info)
          if (appState.mediaServiceManager.currentServerType !=
                  ServerType.soundcloud &&
              currentTrack.albumName != null &&
              (appState.mediaServiceManager.currentServerType !=
                      ServerType.youtubeMusic ||
                  currentTrack.albumId != null ||
                  currentTrack.artistId != null))
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
          // Download (disabled for SoundCloud and YouTube Music)
          if (appState.mediaServiceManager.currentServerType !=
              ServerType.soundcloud &&
              appState.mediaServiceManager.currentServerType !=
                  ServerType.youtubeMusic)
            _buildDownloadAction(context, currentTrack, appState),
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
        '${currentTrack.name} by ${displayArtistName(currentTrack.artistName, defaultName: 'Unknown Artist')}';

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

  String _buildArtistAlbumText(dynamic track, AppState appState) {
    final artistDisplay =
        displayArtistName(track.artistName, defaultName: 'Unknown Artist');
    final isSoundCloud = appState.mediaServiceManager.currentServerType ==
        ServerType.soundcloud;
    final isYouTubeMusic = appState.mediaServiceManager.currentServerType ==
        ServerType.youtubeMusic;
    // SoundCloud/YouTube Music: show artist only when no album
    if (isSoundCloud || isYouTubeMusic) {
      return artistDisplay;
    }
    final albumName = track.albumName;
    if (albumName != null && artistDisplay.isNotEmpty) {
      return '$artistDisplay - $albumName';
    } else if (artistDisplay.isNotEmpty) {
      return artistDisplay;
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

      final isYouTubeMusic = appState.mediaServiceManager.currentServerType ==
          ServerType.youtubeMusic;

      if (isYouTubeMusic) {
        // YouTube Music: build album from track (real or virtual id)
        String? albumId = track.albumId;
        if (albumId == null || albumId.isEmpty) {
          if (track.artistId != null && track.albumName != null && track.albumName!.isNotEmpty) {
            final safeName = track.albumName!.replaceAll(':', '_');
            albumId = '${virtualAlbumIdPrefix}${track.artistId}:$safeName';
          }
        }
        if (albumId == null || albumId.isEmpty) {
          _showErrorSnackBar(context, 'Album information not available');
          return;
        }
        final album = Album(
          id: albumId,
          name: track.albumName ?? 'Unknown Album',
          artistName: track.artistName,
          imageUrl: track.imageUrl,
          year: null,
          isFavorite: false,
        );
        debugPrint('Navigating to YT Music album: ${album.name}');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaDetailsPage.album(album: album),
          ),
        );
        return;
      }

      if (track.albumId == null) {
        debugPrint('Track albumId is null, cannot navigate');
        _showErrorSnackBar(context, 'Album information not available');
        return;
      }

      final album = appState.albums.firstWhere(
        (a) => a.id == track.albumId,
        orElse: () => throw StateError('Album not found'),
      );

      debugPrint('Found album: ${album.name}, navigating...');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaDetailsPage.album(album: album),
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

      if (track.artistName == null || track.artistName!.isEmpty) {
        debugPrint('Track artistName is null, cannot navigate');
        _showErrorSnackBar(context, 'Artist information not available');
        return;
      }

      final isYouTubeMusic = appState.mediaServiceManager.currentServerType ==
          ServerType.youtubeMusic;
      final isSoundCloud = appState.mediaServiceManager.currentServerType ==
          ServerType.soundcloud;

      // YouTube Music / SoundCloud: use track.artistId to build artist when not in library
      if ((isYouTubeMusic || isSoundCloud) && track.artistId != null && track.artistId!.isNotEmpty) {
        final artist = Artist(
          id: track.artistId!,
          name: track.artistName!,
          imageUrl: null,
        );
        debugPrint('Using track artistId for YT Music/SoundCloud: ${artist.name}, navigating...');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ArtistDetailsPage(artist: artist),
          ),
        );
        return;
      }

      // Try library artists (by name)
      final artist = appState.artists.firstWhere(
        (a) => a.name == track.artistName,
        orElse: () => throw StateError('Artist not found'),
      );

      debugPrint('Found artist: ${artist.name}, navigating...');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailsPage(artist: artist),
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
