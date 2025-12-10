import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../providers/app_state.dart';
import '../models/jellyfin_models.dart';
import '../services/audio/base_audio_handler.dart';
import '../screens/playing/now_playing.dart';
import 'apple_design/apple_theme.dart';

class DynamicIsle extends StatefulWidget {
  const DynamicIsle({super.key});

  @override
  State<DynamicIsle> createState() => _DynamicIsleState();
}

class _DynamicIsleState extends State<DynamicIsle>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() async {
    await _triggerHapticFeedback();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _openNowPlaying(BuildContext context) async {
    await _triggerLongPressHaptic();
    if (!mounted) return;
    Navigator.push(
      this.context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NowPlayingScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Start from bottom
          const end = Offset.zero; // End at current position
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // Haptic feedback methods
  Future<void> _triggerHapticFeedback() async {
    try {
      HapticFeedback.selectionClick();
      // Light vibration for toggle expand/collapse
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      // Silently fail if vibration is not supported
    }
  }

  Future<void> _triggerLongPressHaptic() async {
    try {
      HapticFeedback.mediumImpact();
      // Medium vibration for long press
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      // Silently fail if vibration is not supported
    }
  }

  Future<void> _triggerButtonHaptic() async {
    try {
      HapticFeedback.lightImpact();
      // Very light vibration for button presses
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 30);
      }
    } catch (e) {
      // Silently fail if vibration is not supported
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentTrack = appState.audioHandler?.currentTrack;

        // Check if playing by looking at the audio handler's current state or user intent
        bool isPlaying = false;
        if (appState.audioHandler != null) {
          // Try to get the playing state from different sources
          try {
            final state = appState.audioHandler!.currentState;
            isPlaying = state == AudioPlayerState.playing;
          } catch (e) {
            // Fallback to user intended playing
            try {
              isPlaying = appState.audioHandler!.userIntendedPlaying ?? false;
            } catch (e2) {
              isPlaying = false;
            }
          }
        }

        // Hide when no track is playing
        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                // Remove bouncing/pulsing animation when shrunken
                const scale = 1.0;

                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: _toggleExpanded,
                    onLongPress: () => _openNowPlaying(context),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: _isExpanded ? 350 : 180,
                      height: _isExpanded ? 90 : 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPlaying
                              ? CupertinoColors.systemPurple.withOpacity(0.6)
                              : CupertinoColors.systemGrey4.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                          if (isPlaying)
                            BoxShadow(
                              color: CupertinoColors.systemPurple.withOpacity(
                                0.2,
                              ),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _isExpanded
                            ? _buildExpandedContent(
                                context,
                                appState,
                                currentTrack,
                                isPlaying,
                              )
                            : _buildCompactContent(
                                context,
                                appState,
                                currentTrack,
                                isPlaying,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactContent(
    BuildContext context,
    AppState appState,
    Track currentTrack,
    bool isPlaying,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Album art (circular)
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2C2C2E),
            ),
            child: ClipOval(
              child: currentTrack.imageUrl != null
                  ? Image.network(
                      appState.getImageUrl(
                        currentTrack.imageUrl!,
                        width: 56,
                        height: 56,
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        CupertinoIcons.music_note,
                        color: CupertinoColors.systemGrey,
                        size: 14,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.music_note,
                      color: CupertinoColors.systemGrey,
                      size: 14,
                    ),
            ),
          ),

          const SizedBox(width: 8),

          // Track title (truncated)
          Expanded(
            child: Text(
              currentTrack.name,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Play/pause button
          GestureDetector(
            onTap: () async {
              await _triggerButtonHaptic();
              appState.playPause();
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: CupertinoColors.systemPurple.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                color: CupertinoColors.white,
                size: 12,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Skip button
          GestureDetector(
            onTap: () async {
              await _triggerButtonHaptic();
              appState.skipToNext();
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: CupertinoColors.systemPurple.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.forward_fill,
                color: CupertinoColors.systemPurple,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    AppState appState,
    Track currentTrack,
    bool isPlaying,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Album art
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF2C2C2E),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: currentTrack.imageUrl != null
                  ? Image.network(
                      appState.getImageUrl(
                        currentTrack.imageUrl!,
                        width: 132,
                        height: 132,
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        CupertinoIcons.music_note,
                        color: CupertinoColors.systemGrey,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.music_note,
                      color: CupertinoColors.systemGrey,
                      size: 24,
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Track info and controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Track name
                Text(
                  currentTrack.name,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                // Artist name
                Text(
                  currentTrack.artistName ?? 'Unknown Artist',
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Mini progress bar
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: StreamBuilder<Duration>(
                    stream: appState.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration =
                          appState.audioHandler?.duration ?? Duration.zero;
                      final progress = duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0.0;

                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemPurple,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Control buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button
              GestureDetector(
                onTap: () async {
                  await _triggerButtonHaptic();
                  appState.skipToPrevious();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.backward_fill,
                    color: CupertinoColors.white,
                    size: 16,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Play/pause button
              GestureDetector(
                onTap: () async {
                  await _triggerButtonHaptic();
                  appState.playPause();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.systemPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: CupertinoColors.white,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Next button
              GestureDetector(
                onTap: () async {
                  await _triggerButtonHaptic();
                  appState.skipToNext();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.forward_fill,
                    color: CupertinoColors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
