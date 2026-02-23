import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/services/album_art_color_service.dart';
import 'package:doudou/services/audio/unified_audio_handler.dart' show RepeatMode;
import 'package:doudou/ui/playing/lyrics_overlay.dart';
import 'package:doudou/ui/playing/queue_overlay.dart';
import 'package:doudou/ui/widgets/cached_image_widget.dart';
import 'package:doudou/ui/widgets/marquee_text.dart';
import 'package:doudou/ui/widgets/detail_track_view.dart';
import 'package:doudou/ui/pages/details/artist_detail.dart';
import 'package:doudou/services/lyrics_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/ui/layout/desktop_layout.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';
import 'package:doudou/ui/widgets/universal_image.dart';
import 'package:audio_service/audio_service.dart';

/// Breakpoint above which now-playing uses expanded (desktop) layout.
const double kNowPlayingExpandedBreakpoint = 900.0;

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
  List<Color>? _gradientColors;
  String? _lastOverlayImageUrl;

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
    _snapBackController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
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

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= kNowPlayingExpandedBreakpoint) {
                  return _buildExpandedLayout(
                    context,
                    appState,
                    audioHandler!,
                    currentTrack,
                  );
                }
                return _buildCompactLayout(
                  context,
                  appState,
                  audioHandler!,
                  currentTrack,
                );
              },
            );
          },
        );
      },
    );
  }

  /// Compact (mobile) layout: carousel, progress, controls, bottom bar.
  Widget _buildCompactLayout(
    BuildContext context,
    AppState appState,
    dynamic audioHandler,
    Track currentTrack,
  ) {
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
                                              animation: Listenable.merge([
                                                _skipAnimationController,
                                                _snapBackController,
                                              ]),
                                              builder: (context, child) {
                                                // Calculate total offset: skip animation, snap-back, or drag
                                                double totalOffset;
                                                if (_isAnimatingSkip) {
                                                  final targetOffset =
                                                      _skipDirection * spacing;
                                                  final progress = Curves
                                                      .easeOutCubic
                                                      .transform(
                                                        _skipAnimationController
                                                            .value,
                                                      );
                                                  totalOffset =
                                                      _animationStartOffset +
                                                      (targetOffset -
                                                              _animationStartOffset) *
                                                          progress;
                                                } else if (_isSnappingBack) {
                                                  totalOffset =
                                                      _snapBackStartOffset *
                                                          (1 -
                                                              _snapBackController
                                                                  .value);
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
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(
                                                      sigmaX: 5, sigmaY: 5),
                                                  child: Container(
                                                    height: 8,
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: CupertinoColors
                                                          .white
                                                          .withOpacity(0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: LayoutBuilder(
                                                      builder: (context,
                                                          constraints) {
                                                        return Stack(
                                                          alignment:
                                                              Alignment
                                                                  .centerLeft,
                                                          children: [
                                                            // Filled portion: left to right only (single direction)
                                                            SizedBox(
                                                              width: constraints
                                                                      .maxWidth *
                                                                  sliderValue
                                                                      .clamp(
                                                                          0.0,
                                                                          1.0),
                                                              child: Container(
                                                                decoration: BoxDecoration(
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
                                                                              6),
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
              )
            );
  }

  /// Expanded (desktop) layout: album + controls left, queue/lyrics right.
  Widget _buildExpandedLayout(
    BuildContext context,
    AppState appState,
    dynamic audioHandler,
    Track currentTrack,
  ) {
    final l10n = AppLocalizations.of(context);
    final overlayImageUrl = currentTrack.imageUrl != null
        ? appState.getImageUrl(currentTrack.imageUrl!, width: 800, height: 800)
        : null;
    if (overlayImageUrl != null &&
        overlayImageUrl.isNotEmpty &&
        overlayImageUrl != _lastOverlayImageUrl) {
      _lastOverlayImageUrl = overlayImageUrl;
      AlbumArtColorService.getGradientColors(overlayImageUrl).then((colors) {
        if (mounted && colors != null) {
          setState(() => _gradientColors = colors);
        }
      });
    }
    if (overlayImageUrl == null || overlayImageUrl.isEmpty) {
      if (_lastOverlayImageUrl != null || _gradientColors != null) {
        _lastOverlayImageUrl = null;
        _gradientColors = null;
      }
    }
    final overlayGradientColors = _gradientColors ??
        [
          DesktopTheme.backgroundDeep.withOpacity(0.5),
          DesktopTheme.backgroundDeep.withOpacity(0.85),
          DesktopTheme.backgroundDeep.withOpacity(0.95),
        ];

    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;
        final isMindElectricBackwards = _isMindElectricBackwards(
          currentTrack.name,
          currentTrack.artistName ?? '',
          position,
        );
        Widget content = Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              if (overlayImageUrl != null && overlayImageUrl.isNotEmpty)
                Positioned.fill(
                  child: buildSmartImage(
                    imageUrl: overlayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: () =>
                        Container(color: DesktopTheme.backgroundDeep),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: overlayGradientColors,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(DesktopTheme.spacingMd),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.more_horiz_rounded),
                            onPressed: () => _showMoreOptions(
                              context,
                              currentTrack,
                              appState,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _ExpandedLeftColumn(
                              appState: appState,
                              audioHandler: audioHandler,
                              currentTrack: currentTrack,
                              onShowMoreOptions: () => _showMoreOptions(
                                context,
                                currentTrack,
                                appState,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              margin: const EdgeInsets.only(
                                right: DesktopTheme.spacingLg,
                                bottom: DesktopTheme.spacingLg,
                              ),
                              decoration: BoxDecoration(
                                color: DesktopTheme.backgroundDeep
                                    .withOpacity(0.6),
                                borderRadius: BorderRadius.circular(
                                  DesktopTheme.radiusMd,
                                ),
                                border: Border.all(
                                  color: DesktopTheme.glassBorder,
                                ),
                              ),
                              child: DefaultTabController(
                                length: 2,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        DesktopTheme.spacingMd,
                                      ),
                                      child: TabBar(
                                        labelColor: DesktopTheme.textPrimary,
                                        unselectedLabelColor:
                                            DesktopTheme.textTertiary,
                                        indicatorColor: Theme.of(context)
                                            .colorScheme.primary,
                                        tabs: [
                                          Tab(text: l10n.upNext),
                                          Tab(text: l10n.lyrics),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: DesktopTheme.spacingMd,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '${l10n.playingFrom} ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: DesktopTheme.textTertiary,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              currentTrack.albumName ??
                                                  l10n.unknownAlbum,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: DesktopTheme.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                        height: DesktopTheme.spacingSm,
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          _NowPlayingQueuePanel(
                                            appState: appState,
                                            audioHandler: audioHandler,
                                          ),
                                          _NowPlayingLyricsPanel(
                                            trackName: currentTrack.name,
                                            artistName:
                                                currentTrack.artistName ?? '',
                                            audioHandler: audioHandler,
                                          ),
                                        ],
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
                  ],
                ),
              ),
            ],
          ),
        );
        if (isMindElectricBackwards) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(3.14159),
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }

  bool _isMindElectricBackwards(
      String title, String artist, Duration position) {
    final t = title.toLowerCase();
    final a = artist.toLowerCase();
    final isMindElectric = (t.contains('mind electric') ||
            t.contains('the mind electric')) &&
        (a.contains('miracle musical') ||
            a.contains('tally hall') ||
            a.contains('joe hawley'));
    const forwardTimestamp = Duration(minutes: 2, seconds: 50);
    return isMindElectric && position < forwardTimestamp;
  }

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
              DesktopLayout.showAddToPlaylistDialog(context, currentTrack);
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
    showAppleDialog(
      context: context,
      title: 'Share Track',
      content: Text(
        trackInfo,
        style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    );
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
    showAppleDialog(
      context: context,
      title: 'Navigation Error',
      content: Text(
        message,
        style: TextStyle(color: DesktopTheme.textSecondary, decoration: TextDecoration.none),
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

String _formatDurationForDisplay(Duration duration) {
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Left column for expanded now-playing: album art, info, progress, controls.
class _ExpandedLeftColumn extends StatelessWidget {
  final AppState appState;
  final dynamic audioHandler;
  final Track currentTrack;
  final VoidCallback onShowMoreOptions;

  const _ExpandedLeftColumn({
    required this.appState,
    required this.audioHandler,
    required this.currentTrack,
    required this.onShowMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasAlbum = currentTrack.albumName != null && currentTrack.albumName!.isNotEmpty;
    final hasArtist = currentTrack.artistName != null && currentTrack.artistName!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(DesktopTheme.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: currentTrack.imageUrl != null
                      ? AlbumArtWidget(
                          imageUrl: appState.getImageUrl(
                            currentTrack.imageUrl!,
                            width: 800,
                            height: 800,
                          ),
                          size: 400,
                          borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                        )
                      : Container(
                          color: DesktopTheme.backgroundElevated,
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 100,
                            color: DesktopTheme.textTertiary,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingXl),
          Text(
            currentTrack.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: DesktopTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesktopTheme.spacingSm),
          if (hasAlbum)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                _navigateToAlbumFromExpanded(context, currentTrack, appState);
              },
              child: Text.rich(
                TextSpan(
                  text: '${l10n.fromAlbum} ',
                  style: TextStyle(fontSize: 14, color: DesktopTheme.textTertiary),
                  children: [
                    TextSpan(
                      text: currentTrack.albumName,
                      style: TextStyle(
                        fontSize: 14,
                        color: DesktopTheme.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hasArtist)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                _navigateToArtistFromExpanded(context, currentTrack, appState);
              },
              child: Text.rich(
                TextSpan(
                  text: '${l10n.byArtist} ',
                  style: TextStyle(fontSize: 14, color: DesktopTheme.textTertiary),
                  children: [
                    TextSpan(
                      text: currentTrack.artistName,
                      style: TextStyle(
                        fontSize: 14,
                        color: DesktopTheme.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: DesktopTheme.spacingXl),
          StreamBuilder<Duration>(
            stream: audioHandler.positionStream,
            builder: (context, posSnapshot) {
              final position = posSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration?>(
                stream: audioHandler.durationStream,
                builder: (context, durSnapshot) {
                  final duration = durSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: DesktopTheme.textPrimary,
                          inactiveTrackColor: DesktopTheme.backgroundElevated,
                          thumbColor: DesktopTheme.textPrimary,
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (value) {
                            final newPos = Duration(
                              milliseconds: (value * duration.inMilliseconds).round(),
                            );
                            audioHandler.seek(newPos);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DesktopTheme.spacingMd),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDurationForDisplay(position),
                              style: TextStyle(fontSize: 12, color: DesktopTheme.textSecondary),
                            ),
                            Text(
                              _formatDurationForDisplay(duration),
                              style: TextStyle(fontSize: 12, color: DesktopTheme.textSecondary),
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
          const SizedBox(height: DesktopTheme.spacingLg),
          StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, pbSnapshot) {
              final isPlaying = pbSnapshot.data?.playing ?? false;
              final isShuffled = audioHandler.shuffleEnabled ?? false;
              final repeatMode = audioHandler.repeatMode ?? RepeatMode.none;
              final trackId = currentTrack.id;
              final isFavorite = appState.isFavorite(trackId);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: isShuffled ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () {
                      if (isShuffled) {
                        audioHandler.unshuffle();
                      } else {
                        audioHandler.shuffle();
                      }
                    },
                  ),
                  const SizedBox(width: DesktopTheme.spacingXl),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 32),
                    onPressed: appState.skipToPrevious,
                  ),
                  const SizedBox(width: DesktopTheme.spacingMd),
                  GestureDetector(
                    onTap: () => appState.playPause(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: DesktopTheme.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: DesktopTheme.backgroundDeep,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: DesktopTheme.spacingMd),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 32),
                    onPressed: appState.skipToNext,
                  ),
                  const SizedBox(width: DesktopTheme.spacingXl),
                  IconButton(
                    icon: Icon(
                      repeatMode == RepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: repeatMode != RepeatMode.none ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () {
                      final next = repeatMode == RepeatMode.none
                          ? RepeatMode.all
                          : repeatMode == RepeatMode.all
                              ? RepeatMode.one
                              : RepeatMode.none;
                      audioHandler.setRepeatMode(next);
                    },
                  ),
                  const SizedBox(width: DesktopTheme.spacingXl),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFavorite ? const Color(0xFFEC4899) : null,
                    ),
                    onPressed: () => appState.toggleFavorite(currentTrack),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: DesktopTheme.spacingLg),
        ],
      ),
    );
  }
}

void _navigateToAlbumFromExpanded(BuildContext context, Track track, AppState appState) {
  try {
    if (track.albumId == null) return;
    final album = appState.albums.firstWhere(
      (a) => a.id == track.albumId,
      orElse: () => throw StateError('not found'),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailTrackView.album(album)),
    );
  } catch (_) {}
}

void _navigateToArtistFromExpanded(BuildContext context, Track track, AppState appState) {
  try {
    if (track.artistName == null) return;
    final artist = appState.artists.firstWhere(
      (a) => a.name == track.artistName,
      orElse: () => throw StateError('not found'),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)),
    );
  } catch (_) {}
}

/// Queue list for expanded now-playing panel.
class _NowPlayingQueuePanel extends StatelessWidget {
  final AppState appState;
  final dynamic audioHandler;

  const _NowPlayingQueuePanel({
    required this.appState,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    final queue = appState.queue;
    final currentIndex = audioHandler?.currentIndex ?? 0;

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: DesktopTheme.textTertiary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: DesktopTheme.spacingSm),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final track = queue[index];
        final isCurrent = index == currentIndex;

        return KeyedSubtree(
          key: ValueKey(track.id),
          child: ListTile(
          dense: true,
          leading: SizedBox(
            width: 40,
            height: 40,
            child: track.imageUrl != null
                ? AlbumArtWidget(
                    imageUrl: appState.getImageUrl(track.imageUrl!, width: 80, height: 80),
                    size: 40,
                    borderRadius: BorderRadius.circular(4),
                  )
                : Icon(Icons.music_note_rounded, size: 20, color: DesktopTheme.textTertiary),
          ),
          title: Text(
            track.name,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: isCurrent ? Theme.of(context).colorScheme.primary : DesktopTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artistName ?? '',
            style: TextStyle(fontSize: 12, color: DesktopTheme.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => audioHandler?.skipToQueueItem(index),
        ),
        );
      },
    );
  }
}

/// Lyrics panel for expanded now-playing; loads and shows synced or plain lyrics.
class _NowPlayingLyricsPanel extends StatefulWidget {
  final String trackName;
  final String artistName;
  final dynamic audioHandler;

  const _NowPlayingLyricsPanel({
    required this.trackName,
    required this.artistName,
    required this.audioHandler,
  });

  @override
  State<_NowPlayingLyricsPanel> createState() => _NowPlayingLyricsPanelState();
}

class _NowPlayingLyricsPanelState extends State<_NowPlayingLyricsPanel> {
  LyricsResult? _result;
  bool _loading = true;
  int _currentLineIndex = -1;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _lineKeys = [];
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_NowPlayingLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackName != oldWidget.trackName ||
        widget.artistName != oldWidget.artistName) {
      _load();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _result = null;
      _currentLineIndex = -1;
      _lineKeys.clear();
    });
    try {
      final result = await LyricsService.fetchLyrics(widget.trackName, widget.artistName);
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
          if (result?.syncedLyrics != null) {
            for (int i = 0; i < result!.syncedLyrics!.length; i++) {
              _lineKeys.add(GlobalKey());
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _result = null; });
    }
  }

  void _updateLine(Duration position) {
    if (_result?.syncedLyrics == null) return;
    if ((position - _lastPosition).abs() < const Duration(milliseconds: 50)) return;
    _lastPosition = position;
    final lines = _result!.syncedLyrics!;
    int newIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (position >= lines[i].timestamp) {
        newIndex = i;
      } else {
        break;
      }
    }
    if (newIndex != _currentLineIndex && newIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLineIndex != newIndex) {
          setState(() => _currentLineIndex = newIndex);
          _scrollToLine();
        }
      });
    }
  }

  void _scrollToLine() {
    if (_currentLineIndex < 0 || _currentLineIndex >= _lineKeys.length) return;
    final ctx = _lineKeys[_currentLineIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.4, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: DesktopTheme.spacingMd),
            Text('Loading lyrics...', style: TextStyle(fontSize: 13, color: DesktopTheme.textSecondary)),
          ],
        ),
      );
    }
    if (_result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: DesktopTheme.textTertiary),
            const SizedBox(height: DesktopTheme.spacingMd),
            Text('Lyrics not available', style: TextStyle(fontSize: 14, color: DesktopTheme.textTertiary)),
          ],
        ),
      );
    }
    if (_result!.hasSyncedLyrics && _result!.syncedLyrics != null) {
      return StreamBuilder<Duration>(
        stream: widget.audioHandler?.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          _updateLine(position);
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: DesktopTheme.spacingMd, vertical: DesktopTheme.spacingXl),
            itemCount: _result!.syncedLyrics!.length,
            itemBuilder: (context, index) {
              final line = _result!.syncedLyrics![index];
              final isCurrent = index == _currentLineIndex;
              final isPast = index < _currentLineIndex;
              return Container(
                key: _lineKeys[index],
                margin: EdgeInsets.symmetric(vertical: isCurrent ? 8 : 4),
                padding: EdgeInsets.symmetric(
                  horizontal: DesktopTheme.spacingMd,
                  vertical: isCurrent ? 12 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DesktopTheme.radiusSm),
                  color: isCurrent ? DesktopTheme.accentPrimary.withOpacity(0.15) : Colors.transparent,
                ),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isCurrent ? DesktopTheme.textPrimary : (isPast ? DesktopTheme.textTertiary : DesktopTheme.textSecondary),
                    fontSize: isCurrent ? 15 : 13,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            },
          );
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopTheme.spacingMd),
      child: SelectableText(
        _result!.plainLyrics,
        style: TextStyle(color: DesktopTheme.textSecondary, fontSize: 13, height: 1.8),
        textAlign: TextAlign.center,
      ),
    );
  }
}
